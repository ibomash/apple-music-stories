import Foundation

struct LastFMConfiguration: Hashable {
    let apiKey: String
    let apiSecret: String
    let callbackScheme: String

    static func load(bundle: Bundle = .main) -> LastFMConfiguration? {
        guard let apiKey = bundle.object(forInfoDictionaryKey: "LastfmApiKey") as? String,
              let apiSecret = bundle.object(forInfoDictionaryKey: "LastfmApiSecret") as? String,
              let callbackScheme = bundle.object(forInfoDictionaryKey: "LastfmCallbackScheme") as? String
        else {
            return nil
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScheme = callbackScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedKey.isEmpty == false,
              trimmedSecret.isEmpty == false,
              trimmedScheme.isEmpty == false
        else {
            return nil
        }

        return LastFMConfiguration(apiKey: trimmedKey, apiSecret: trimmedSecret, callbackScheme: trimmedScheme)
    }

    var callbackURL: URL? {
        URL(string: "\(callbackScheme)://auth")
    }
}
