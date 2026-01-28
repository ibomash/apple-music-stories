import CryptoKit
import Foundation

struct LastFMAPIClient {
    private let configuration: LastFMConfiguration
    private let session: URLSession
    private let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")

    init(configuration: LastFMConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func getToken() async throws -> String {
        let data = try await performRequest(
            parameters: [
                "method": "auth.getToken",
            ],
            sign: false,
            sessionKey: nil
        )
        let response = try decode(LastFMTokenResponse.self, from: data)
        return response.token
    }

    func getSession(token: String) async throws -> LastFMSession {
        let data = try await performRequest(
            parameters: [
                "method": "auth.getSession",
                "token": token,
            ],
            sign: true,
            sessionKey: nil
        )
        let response = try decode(LastFMSessionResponse.self, from: data)
        return LastFMSession(username: response.session.name, key: response.session.key)
    }

    func updateNowPlaying(track: LastFMTrack, sessionKey: String) async throws {
        var parameters: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
        ]
        if let album = track.album, album.isEmpty == false {
            parameters["album"] = album
        }
        if let duration = track.duration, duration > 0 {
            parameters["duration"] = String(Int(duration.rounded()))
        }
        _ = try await performRequest(parameters: parameters, sign: true, sessionKey: sessionKey)
    }

    func scrobble(track: LastFMTrack, startedAt: Date, sessionKey: String) async throws {
        var parameters: [String: String] = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "timestamp": String(Int(startedAt.timeIntervalSince1970)),
        ]
        if let album = track.album, album.isEmpty == false {
            parameters["album"] = album
        }
        if let duration = track.duration, duration > 0 {
            parameters["duration"] = String(Int(duration.rounded()))
        }
        _ = try await performRequest(parameters: parameters, sign: true, sessionKey: sessionKey)
    }

    func scrobbleBatch(_ scrobbles: [LastFMPendingScrobble], sessionKey: String) async throws {
        guard scrobbles.isEmpty == false else {
            return
        }
        var parameters: [String: String] = [
            "method": "track.scrobble",
        ]
        for (index, scrobble) in scrobbles.enumerated() {
            parameters["artist[\(index)]"] = scrobble.track.artist
            parameters["track[\(index)]"] = scrobble.track.title
            parameters["timestamp[\(index)]"] = String(Int(scrobble.startedAt.timeIntervalSince1970))
            if let album = scrobble.track.album, album.isEmpty == false {
                parameters["album[\(index)]"] = album
            }
            if let duration = scrobble.track.duration, duration > 0 {
                parameters["duration[\(index)]"] = String(Int(duration.rounded()))
            }
        }
        _ = try await performRequest(parameters: parameters, sign: true, sessionKey: sessionKey)
    }

    private func performRequest(
        parameters: [String: String],
        sign: Bool,
        sessionKey: String?
    ) async throws -> Data {
        guard let endpoint else {
            throw LastFMAPIError.invalidEndpoint
        }

        var payload = parameters
        payload["api_key"] = configuration.apiKey
        if let sessionKey {
            payload["sk"] = sessionKey
        }
        if sign {
            payload["api_sig"] = LastFMAPISignature.sign(parameters: payload, secret: configuration.apiSecret)
        }
        payload["format"] = "json"

        let body = formEncodedBody(from: payload)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                throw LastFMAPIError.http(statusCode: httpResponse.statusCode)
            }
            if let error = decodeError(from: data) {
                throw error
            }
            return data
        } catch let error as LastFMAPIError {
            throw error
        } catch {
            throw LastFMAPIError.transport(error)
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        if let error = decodeError(from: data) {
            throw error
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw LastFMAPIError.invalidResponse
        }
    }

    private func decodeError(from data: Data) -> LastFMAPIError? {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(LastFMErrorPayload.self, from: data),
              let code = payload.error,
              let message = payload.message
        else {
            return nil
        }
        return LastFMAPIError.api(code: code, message: message)
    }

    private func formEncodedBody(from parameters: [String: String]) -> Data? {
        var components = URLComponents()
        components.queryItems = parameters.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        return components.percentEncodedQuery?.data(using: .utf8)
    }
}

enum LastFMAPIError: LocalizedError {
    case api(code: Int, message: String)
    case http(statusCode: Int)
    case invalidEndpoint
    case invalidResponse
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case let .api(_, message):
            return message
        case let .http(statusCode):
            return "Last.fm HTTP error \(statusCode)."
        case .invalidEndpoint:
            return "Last.fm API endpoint is invalid."
        case .invalidResponse:
            return "Last.fm response was invalid."
        case let .transport(error):
            return error.localizedDescription
        }
    }

    var isAuthError: Bool {
        switch self {
        case let .api(code, _):
            return code == 4 || code == 9 || code == 10
        default:
            return false
        }
    }

    var isRetryable: Bool {
        switch self {
        case let .http(statusCode):
            return statusCode >= 500
        case let .api(code, _):
            return code == 11 || code == 16 || code == 29
        case .transport:
            return true
        default:
            return false
        }
    }
}

struct LastFMAPISignature {
    static func sign(parameters: [String: String], secret: String) -> String {
        let filtered = parameters.filter { key, _ in
            key != "format" && key != "callback"
        }
        let sorted = filtered.sorted { $0.key < $1.key }
        let baseString = sorted.map { $0.key + $0.value }.joined() + secret
        let digest = Insecure.MD5.hash(data: Data(baseString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct LastFMErrorPayload: Decodable {
    let error: Int?
    let message: String?
}

private struct LastFMTokenResponse: Decodable {
    let token: String
}

private struct LastFMSessionResponse: Decodable {
    let session: LastFMSessionPayload
}

private struct LastFMSessionPayload: Decodable {
    let name: String
    let key: String
}
