import AppKit
import Foundation

/// Cliente del helper privilegiado v2. Mientras está instalado, el PIN y la respuesta de seguridad
/// del compañero viven solo como hash en un directorio de root (no en UserDefaults, que cualquier
/// proceso del usuario puede leer o editar) y un LaunchDaemon relanza FocusPanic si lo cierran
/// o lo matan sin que el compañero autorice la salida con su PIN.
public final class GuardService {
    public static let shared = GuardService()

    /// Minutos que el guardián deja la app cerrada tras una salida autorizada con PIN.
    public static let exitPauseMinutes = 60

    public enum SecretCheck: Equatable {
        case ok
        case denied
        case locked(seconds: Int)
        case unavailable
    }

    public struct Status {
        public var version: Int = 0
        public var hasPin = false
        public var hasAnswer = false
        public var isGuardianRunning = false
        public var lastEvent = ""
    }

    private let helperPath = "/usr/local/bin/focuspanic-helper"
    private let lastReportedEventKey = "FocusPanic_LastReportedGuardEvent"
    private var cachedStatus: Status?

    private init() {}

    public var status: Status {
        if let cachedStatus { return cachedStatus }
        return refreshStatus()
    }

    /// Helper v2 instalado: los secretos y la salida de la app pasan por él.
    public var isActive: Bool { status.version >= GuardHelperScript.version }

    /// El PIN del compañero está guardado en el directorio de root.
    public var holdsPin: Bool { isActive && status.hasPin }

    @discardableResult
    public func refreshStatus() -> Status {
        var result = Status()
        if FileManager.default.fileExists(atPath: helperPath) {
            let (code, output) = run(["status"])
            if code == 0 {
                for line in output.split(separator: "\n") {
                    let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                    guard parts.count == 2 else { continue }
                    switch parts[0] {
                    case "version": result.version = Int(parts[1]) ?? 0
                    case "pin": result.hasPin = parts[1] == "1"
                    case "answer": result.hasAnswer = parts[1] == "1"
                    case "guardian": result.isGuardianRunning = parts[1] == "1"
                    case "last_event": result.lastEvent = parts[1]
                    default: break
                    }
                }
            }
        }
        cachedStatus = result
        return result
    }

    /// El helper compara en minúsculas y sin espacios en los extremos, igual que la respuesta de seguridad.
    public static func normalize(_ secret: String) -> String {
        secret.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func verify(_ secret: String, acceptAnswer: Bool) -> SecretCheck {
        guard isActive else { return .unavailable }
        let (code, output) = run(["verify", acceptAnswer ? "any" : "pin"], input: Self.normalize(secret) + "\n")
        return Self.secretCheck(code: code, output: output)
    }

    /// Cambia el PIN y/o la respuesta. `currentSecret` es el PIN o la respuesta vigentes
    /// (se ignora si el helper todavía no tiene secretos).
    public func setSecrets(currentSecret: String, newPin: String?, newAnswer: String?) -> SecretCheck {
        guard isActive else { return .unavailable }
        let input = [currentSecret, newPin ?? "", newAnswer ?? ""].map(Self.normalize).joined(separator: "\n") + "\n"
        let (code, output) = run(["set-secrets"], input: input)
        refreshStatus()
        return Self.secretCheck(code: code, output: output)
    }

    /// Pide al guardián que no relance la app durante `minutes` minutos.
    public func pauseGuardian(pin: String, minutes: Int = GuardService.exitPauseMinutes) -> SecretCheck {
        guard isActive else { return .unavailable }
        let (code, output) = run(["pause", String(minutes)], input: Self.normalize(pin) + "\n")
        return Self.secretCheck(code: code, output: output)
    }

    public func resumeGuardian() {
        guard isActive else { return }
        _ = run(["resume"])
    }

    /// Quita guardián, helper, sudoers y bloqueos. Exige el PIN.
    public func uninstall(pin: String) -> SecretCheck {
        guard isActive else { return .unavailable }
        let (code, output) = run(["uninstall"], input: Self.normalize(pin) + "\n")
        let result = Self.secretCheck(code: code, output: output)
        refreshStatus()
        return result
    }

    /// Copia la app instalada al respaldo de root que usa el guardián si alguien la borra.
    public func syncAppBackup() {
        guard isActive else { return }
        _ = run(["sync-app"])
    }

    /// Borra el PIN y la respuesta guardados pidiendo la contraseña de administrador de macOS
    /// (la única salida si el compañero olvidó ambos; un agente sin esa contraseña no puede hacerlo).
    public func resetSecretsWithAdminPassword() -> Bool {
        let dir = "/Library/Application Support/FocusPanic/guard"
        let cmd = "rm -f '\(dir)/pin.hash' '\(dir)/answer.hash' '\(dir)/failures'"
        let script = "do shell script \"\(cmd)\" with administrator privileges with prompt \"FocusPanic: restablecer el PIN del compañero.\""
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        refreshStatus()
        return error == nil
    }

    /// Si el guardián tuvo que relanzar o restaurar la app desde el último aviso, devuelve qué pasó
    /// para avisar al compañero. Cada evento se reporta una sola vez.
    public func unreportedTamperEvent() -> String? {
        let event = refreshStatus().lastEvent
        guard event.contains("app-relaunched") || event.contains("app-restored") else { return nil }
        guard UserDefaults.standard.string(forKey: lastReportedEventKey) != event else { return nil }
        UserDefaults.standard.set(event, forKey: lastReportedEventKey)
        if event.contains("app-restored") {
            return "FocusPanic fue borrado de Aplicaciones y el guardián lo restauró y lo volvió a abrir."
        }
        return "FocusPanic se cerró sin tu PIN (por ejemplo, matando el proceso) y el guardián lo volvió a abrir."
    }

    public static func message(for check: SecretCheck) -> String {
        switch check {
        case .ok: return ""
        case .denied: return "Clave incorrecta. Pídesela a tu compañero."
        case .locked(let seconds):
            let minutes = max(1, Int((Double(seconds) / 60).rounded(.up)))
            return "Demasiados intentos fallidos. Espera \(minutes) min para volver a intentarlo."
        case .unavailable: return "La protección de FocusPanic no está instalada."
        }
    }

    private static func secretCheck(code: Int32, output: String) -> SecretCheck {
        if code == 0 { return .ok }
        if let line = output.split(separator: "\n").first(where: { $0.hasPrefix("LOCKED") }),
           let seconds = Int(line.split(separator: " ").last ?? "") {
            return .locked(seconds: seconds)
        }
        return output.contains("DENIED") ? .denied : .unavailable
    }

    private func run(_ args: [String], input: String? = nil) -> (Int32, String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath] + args
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe
        let inPipe = Pipe()
        process.standardInput = inPipe
        do {
            try process.run()
            if let input { inPipe.fileHandleForWriting.write(Data(input.utf8)) }
            try? inPipe.fileHandleForWriting.close()
            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (-1, "")
        }
    }
}
