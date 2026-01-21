import Foundation

enum DiagnosticSeverity: String, Hashable {
    case error
    case warning
}

struct ValidationDiagnostic: Identifiable, Hashable {
    let id: UUID
    let severity: DiagnosticSeverity
    let code: String
    let message: String
    let location: String?

    init(severity: DiagnosticSeverity, code: String, message: String, location: String? = nil) {
        id = UUID()
        self.severity = severity
        self.code = code
        self.message = message
        self.location = location
    }
}

extension ValidationDiagnostic {
    static func error(code: String, message: String, location: String? = nil) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .error, code: code, message: message, location: location)
    }

    static func warning(code: String, message: String, location: String? = nil) -> ValidationDiagnostic {
        ValidationDiagnostic(severity: .warning, code: code, message: message, location: location)
    }
}
