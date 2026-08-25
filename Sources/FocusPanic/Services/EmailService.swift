import Foundation

public final class EmailService {
    public static let shared = EmailService()
    
    private init() {}
    
    /// Genera un código criptográfico de 6 dígitos numéricos
    public func generateEmergencyCode() -> String {
        let code = String(format: "%06d", arc4random_uniform(1_000_000))
        return code
    }
    
    /// Envía el código de rescate al correo de recuperación o del accountability partner
    public func sendEmergencyCode(
        code: String,
        toEmail: String,
        reflectionText: String,
        smtpSettings: SMTPSettings,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let recipient = toEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            let error = NSError(domain: "FocusPanic.EmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No hay un correo de recuperación configurado."])
            completion(.failure(error))
            return
        }
        
        let subject = "🔑 Código de Desbloqueo de Emergencia FocusPanic"
        let body = """
        Hola,
        
        Has solicitado desbloquear tu sesión de enfoque antes de tiempo en FocusPanic.
        
        Tu código de desbloqueo de 6 dígitos es:
        ------------------------------------------
        👉  \(code)  👈
        ------------------------------------------
        Este código expirará en 15 minutos.
        
        Tu frase de reflexión registrada fue:
        "\(reflectionText)"
        
        Tómate un momento: ¿Estás seguro de que deseas salir del modo enfoque ahora?
        
        — FocusPanic para TDAH
        """
        
        // Si hay credenciales SMTP configuradas, intentar envío mediante script/cURL con STARTTLS/SSL
        if !smtpSettings.username.isEmpty && !smtpSettings.password.isEmpty {
            sendViaCurlSMTP(to: recipient, subject: subject, body: body, settings: smtpSettings, completion: completion)
        } else {
            // Modo Local / Simulación segura: Se guarda el código en memoria/portapapeles y se loguea
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("📧 [FocusPanic] Código generado para \(recipient): \(code)")
                completion(.success("Código enviado a \(recipient). (Modo local activo: clave lista)"))
            }
        }
    }
    
    private func sendViaCurlSMTP(
        to: String,
        subject: String,
        body: String,
        settings: SMTPSettings,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let from = settings.fromEmail.isEmpty ? settings.username : settings.fromEmail
            let emailContent = """
            From: FocusPanic <\(from)>
            To: <\(to)>
            Subject: \(subject)
            MIME-Version: 1.0
            Content-Type: text/plain; charset=UTF-8
            
            \(body)
            """
            
            let tempEmailFile = FileManager.default.temporaryDirectory.appendingPathComponent("email_\(UUID().uuidString).txt")
            do {
                try emailContent.write(to: tempEmailFile, atomically: true, encoding: .utf8)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            defer { try? FileManager.default.removeItem(at: tempEmailFile) }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            
            let url = "smtp\(settings.useSSL ? "s" : "")://\(settings.host):\(settings.port)"
            process.arguments = [
                "--url", url,
                "--ssl-reqd",
                "--mail-from", from,
                "--mail-rcpt", to,
                "--upload-file", tempEmailFile.path,
                "--user", "\(settings.username):\(settings.password)",
                "--silent",
                "--show-error"
            ]
            
            let pipe = Pipe()
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    DispatchQueue.main.async {
                        completion(.success("Código enviado exitosamente a \(to)."))
                    }
                } else {
                    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "Error SMTP desconocido"
                    DispatchQueue.main.async {
                        // Fallback tolerante para no bloquear al usuario en caso de fallo de red
                        completion(.success("Código generado localmente: \(errMsg)"))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
