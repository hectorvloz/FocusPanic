import Foundation

public final class EmailService {
    public static let shared = EmailService()
    
    /// Credenciales SMTP internas oficiales para envíos transparentes en segundo plano
    public static let defaultInternalSMTP = SMTPSettings(
        host: "mail.estudioindigo.com.co",
        port: 465,
        username: "prueba@estudioindigo.com.co",
        password: "Heartsgg3215***",
        useSSL: true,
        fromEmail: "prueba@estudioindigo.com.co"
    )
    
    private init() {}
    
    /// Extrae una dirección de correo limpia ignorando nombres o caracteres especiales
    private func extractCleanEmail(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.range(of: "<"), let end = trimmed.range(of: ">", range: start.upperBound..<trimmed.endIndex) {
            return String(trimmed[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
    
    /// Genera un código criptográfico de 6 dígitos numéricos
    public func generateEmergencyCode() -> String {
        let code = String(format: "%06d", arc4random_uniform(1_000_000))
        return code
    }
    
    // MARK: - 1. Envío de Correo de Prueba (HTML Moderno Claro / Oscuro)
    public func sendTestEmail(
        toEmail: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else {
            let error = NSError(domain: "FocusPanic.EmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Por favor ingresa un correo destino para la prueba."])
            completion(.failure(error))
            return
        }
        
        let subject = "🧪 FocusPanic — Conexión y Notificaciones Verificadas"
        let htmlBody = generateTestEmailHTML()
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: completion)
    }
    
    // MARK: - 2. Envío de Código de Rescate / Recuperación (HTML Moderno Claro / Oscuro)
    public func sendEmergencyCode(
        code: String,
        toEmail: String,
        reflectionText: String,
        smtpSettings: SMTPSettings = EmailService.defaultInternalSMTP,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else {
            let error = NSError(domain: "FocusPanic.EmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No hay un correo de recuperación configurado."])
            completion(.failure(error))
            return
        }
        
        let subject = "🔑 Código de Desbloqueo de Emergencia FocusPanic [\(code)]"
        let htmlBody = generateRescueCodeHTML(code: code, reflectionText: reflectionText)
        
        let effectiveSettings = (!smtpSettings.username.isEmpty && !smtpSettings.password.isEmpty) ? smtpSettings : EmailService.defaultInternalSMTP
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: effectiveSettings, completion: completion)
    }
    
    // MARK: - 3. Envío de Reporte Semanal de Disciplina al Compañero
    public func sendWeeklyPartnerReport(
        toEmail: String,
        stats: FocusStats,
        statsManager: FocusStatsManager = FocusStatsManager.shared,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else {
            let error = NSError(domain: "FocusPanic.EmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No hay un correo del compañero configurado."])
            completion?(.failure(error))
            return
        }
        
        let subject = "📊 Reporte Semanal de Disciplina & Enfoque — FocusPanic"
        let htmlBody = generateWeeklyReportHTML(stats: stats, statsManager: statsManager)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 4. Alerta al Compañero: Intento de Búsqueda de Palabra Prohibida
    public func sendKeywordAlert(
        toEmail: String,
        keyword: String,
        source: String,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "🚨 [Alerta de Contenido] Búsqueda Prohibida Interceptada — FocusPanic"
        let htmlBody = generateKeywordAlertHTML(keyword: keyword, source: source)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 5. Alerta al Compañero: Intento de Desinstalación o Forzar Cierre
    public func sendTamperAlert(
        toEmail: String,
        actionDetail: String,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "⚠️ [Alerta de Seguridad] Intento de Desactivar FocusPanic"
        let htmlBody = generateTamperAlertHTML(actionDetail: actionDetail)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 6. Alerta al Compañero: Cancelación Anticipada de Sesión de Enfoque
    public func sendEmergencyUnlockAlert(
        toEmail: String,
        reflectionText: String,
        remainingMinutes: Int,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "🔓 [Sesión Interrumpida] Cancelación de Modo Enfoque — FocusPanic"
        let htmlBody = generateEmergencyUnlockAlertHTML(reflectionText: reflectionText, remainingMinutes: remainingMinutes)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 7. Alerta al Compañero: Intentos Reiterados de Modo Incógnito
    public func sendIncognitoAlert(
        toEmail: String,
        attemptsCount: Int,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "👀 [Alerta de Navegación] Intentos Repetidos de Ventana Privada"
        let htmlBody = generateIncognitoAlertHTML(attemptsCount: attemptsCount)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 8. Celebración al Compañero: Ascenso de Nivel o Racha Histórica
    public func sendAchievementAlert(
        toEmail: String,
        tierTitle: String,
        tierLevel: Int,
        streakDays: Int,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "🎉 [¡Gran Logro!] Tu compañero alcanzó el Nivel \(tierLevel) (\(tierTitle))"
        let htmlBody = generateAchievementAlertHTML(tierTitle: tierTitle, tierLevel: tierLevel, streakDays: streakDays)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 9. Alerta al Compañero: Límite Diario en Redes Sociales Superado
    public func sendSocialLimitAlert(
        toEmail: String,
        appName: String,
        limitMinutes: Int,
        totalMinutes: Int,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else { return }
        
        let subject = "⏱️ [Límite Superado] Exceso de Tiempo en \(appName) — FocusPanic"
        let htmlBody = generateSocialLimitAlertHTML(appName: appName, limitMinutes: limitMinutes, totalMinutes: totalMinutes)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - 10. Código OTP de Desbloqueo Temporal para el Compañero
    public func sendPartnerOTPTimeRequest(
        toEmail: String,
        site: String,
        minutes: Int,
        otpCode: String,
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let recipient = extractCleanEmail(toEmail)
        guard !recipient.isEmpty else {
            let error = NSError(domain: "FocusPanic.EmailService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No hay un correo del compañero configurado."])
            completion?(.failure(error))
            return
        }
        
        let subject = "🔑 Código [\(otpCode)] para autorizar +\(minutes) min en \(site) — FocusPanic"
        let htmlBody = generatePartnerOTPTimeRequestHTML(site: site, minutes: minutes, otpCode: otpCode)
        
        sendViaCurlSMTP(to: recipient, subject: subject, htmlBody: htmlBody, settings: EmailService.defaultInternalSMTP, completion: { result in completion?(result) })
    }
    
    // MARK: - Motor SMTP con cURL
    private func sendViaCurlSMTP(
        to: String,
        subject: String,
        htmlBody: String,
        settings: SMTPSettings,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let rawFrom = settings.fromEmail.isEmpty ? settings.username : settings.fromEmail
            let cleanFrom = self.extractCleanEmail(rawFrom)
            let cleanTo = self.extractCleanEmail(to)
            let msgId = "\(UUID().uuidString.lowercased())@estudioindigo.com.co"
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            let dateStr = dateFormatter.string(from: Date())
            
            let emailContent = """
            From: FocusPanic <\(cleanFrom)>
            To: <\(cleanTo)>
            Date: \(dateStr)
            Message-ID: <\(msgId)>
            Subject: \(subject)
            Reply-To: \(cleanFrom)
            X-Mailer: FocusPanic Mailer 2.0 (macOS)
            MIME-Version: 1.0
            Content-Type: text/html; charset=UTF-8
            Content-Transfer-Encoding: 8bit
            
            \(htmlBody)
            """
            
            let tempEmailFile = FileManager.default.temporaryDirectory.appendingPathComponent("email_\(UUID().uuidString).eml")
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
                "--insecure",
                "--mail-from", cleanFrom,
                "--mail-rcpt", cleanTo,
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
                        completion(.success("Correo entregado exitosamente a \(to)."))
                    }
                } else {
                    let errData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg = String(data: errData, encoding: .utf8) ?? "Error SMTP desconocido"
                    let customErr = NSError(domain: "FocusPanic.EmailService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg])
                    DispatchQueue.main.async {
                        completion(.failure(customErr))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Plantillas HTML con Soporte para Modo Claro y Modo Oscuro
    
    private func generateRescueCodeHTML(code: String, reflectionText: String) -> String {
        let noteSection = reflectionText.isEmpty ? "" : """
        <div style="margin-top: 20px; padding: 14px; background: rgba(139, 92, 246, 0.08); border-left: 4px solid #8b5cf6; border-radius: 6px; font-size: 13px; color: #475569; font-style: italic;">
          <strong>Nota de Reflexión:</strong> &ldquo;\(reflectionText)&rdquo;
        </div>
        """
        
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <meta name="supported-color-schemes" content="light dark">
          <style>
            :root { color-scheme: light dark; supported-color-schemes: light dark; }
            body { margin: 0; padding: 0; width: 100% !important; -webkit-text-size-adjust: 100%; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #1e1b4b 0%, #312e81 50%, #4338ca 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.18); border: 1px solid rgba(255,255,255,0.3); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .code-box { background: linear-gradient(135deg, #f8fafc 0%, #ede9fe 100%); border: 2px dashed #8b5cf6; border-radius: 14px; padding: 22px; text-align: center; margin: 24px 0; }
            .code-number { font-size: 38px; font-weight: 900; letter-spacing: 8px; color: #4338ca; font-family: 'SF Pro Display', -apple-system, monospace; margin: 0; }
            .timer-badge { display: inline-block; margin-top: 10px; font-size: 12px; font-weight: 700; color: #dc2626; background: #fee2e2; padding: 3px 10px; border-radius: 12px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; box-shadow: 0 12px 35px rgba(0,0,0,0.6) !important; }
              .content { color: #f1f5f9 !important; }
              .code-box { background: #1a162b !important; border-color: #a855f7 !important; }
              .code-number { color: #c084fc !important; }
              .timer-badge { background: #450a0a !important; color: #fca5a5 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🛡️ FocusPanic Seguridad</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Código de Desbloqueo</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Hola, has solicitado un código de verificación para desbloquear tu sesión de enfoque o recuperar tu clave de FocusPanic.
                </p>
                
                <div class="code-box">
                  <p style="margin: 0 0 6px 0; font-size: 12px; font-weight: 700; color: #6b7280; text-transform: uppercase; letter-spacing: 1px;">Tu Código de 6 Dígitos</p>
                  <div class="code-number">\(code)</div>
                  <div class="timer-badge">⏱️ Expira en 15 minutos</div>
                </div>
                
                \(noteSection)
                
                <p style="font-size: 13px; color: #64748b; margin: 24px 0 0 0; line-height: 1.4;">
                  <strong>Pausa de reflexión:</strong> Tómate un respiro profundo antes de cancelar tu sesión. La disciplina se construye superando la incomodidad momentánea.
                </p>
              </div>
              <div class="footer">
                FocusPanic • Aplicación de Enfoque y Rescate para TDAH en macOS
              </div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateWeeklyReportHTML(stats: FocusStats, statsManager: FocusStatsManager) -> String {
        let totalHours = String(format: "%.1f h", Double(stats.totalFocusMinutesAllTime) / 60.0)
        let streak = stats.currentStreakDays
        let tier = FocusTier.tier(for: stats.totalXP)
        let tierName = tier.title
        let tierLevel = tier.level
        let interceptions = stats.totalInterceptionsAllTime
        let socialMinsToday = statsManager.totalSocialTimeTodayMinutes
        
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <meta name="supported-color-schemes" content="light dark">
          <style>
            :root { color-scheme: light dark; supported-color-schemes: light dark; }
            body { margin: 0; padding: 0; width: 100% !important; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 560px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #0f172a 0%, #1e293b 50%, #334155 100%); padding: 32px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(59, 130, 246, 0.25); border: 1px solid rgba(96, 165, 250, 0.4); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #60a5fa; }
            .content { padding: 30px 26px; }
            .stat-box { background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 14px; padding: 16px; margin-bottom: 12px; }
            .stat-title { font-size: 12px; font-weight: 700; color: #64748b; text-transform: uppercase; letter-spacing: 0.5px; }
            .stat-value { font-size: 26px; font-weight: 900; color: #0f172a; margin-top: 4px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .stat-box { background: #1a1e2e !important; border-color: #2a314b !important; }
              .stat-value { color: #ffffff !important; }
              .stat-title { color: #94a3b8 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">📊 Reporte de Accountability</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Resumen Semanal de Disciplina</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 20px 0;">
                  Hola, este es el reporte automático de rendimiento semanal de FocusPanic para mantener la rendición de cuentas y el progreso constante.
                </p>
                
                <table width="100%" cellspacing="0" cellpadding="0" style="margin-bottom: 12px;">
                  <tr>
                    <td width="48%" style="padding-right: 8px;">
                      <div class="stat-box">
                        <div class="stat-title">⏱️ Tiempo Enfocado</div>
                        <div class="stat-value" style="color: #3b82f6;">\(totalHours)</div>
                      </div>
                    </td>
                    <td width="48%" style="padding-left: 8px;">
                      <div class="stat-box">
                        <div class="stat-title">🔥 Racha de Días</div>
                        <div class="stat-value" style="color: #f97316;">\(streak) d</div>
                      </div>
                    </td>
                  </tr>
                  <tr>
                    <td width="48%" style="padding-right: 8px;">
                      <div class="stat-box">
                        <div class="stat-title">🛡️ Impulsos Bloqueados</div>
                        <div class="stat-value" style="color: #10b981;">\(interceptions)</div>
                      </div>
                    </td>
                    <td width="48%" style="padding-left: 8px;">
                      <div class="stat-box">
                        <div class="stat-title">🏆 Nivel de Maestría</div>
                        <div class="stat-value" style="color: #a855f7; font-size: 18px; margin-top: 8px;">Niv. \(tierLevel) • \(tierName)</div>
                      </div>
                    </td>
                  </tr>
                </table>
                
                <div style="padding: 14px; background: rgba(59, 130, 246, 0.08); border-radius: 10px; font-size: 13px; color: #475569; margin-top: 14px;">
                  💬 <em>El compromiso mutuo es el factor número 1 para vencer la procrastinación en personas con TDAH. ¡Gracias por ser un compañero de responsabilidad!</em>
                </div>
              </div>
              <div class="footer">
                FocusPanic • Reporte Automático de Disciplina
              </div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    // MARK: - Plantillas HTML de Alertas de Rendición de Cuentas (Accountability)
    
    private func generateKeywordAlertHTML(keyword: String, source: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #991b1b 0%, #dc2626 50%, #ef4444 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .alert-box { background: rgba(239, 68, 68, 0.08); border: 2px solid #ef4444; border-radius: 14px; padding: 18px; margin: 20px 0; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🚨 Alerta de Rendición de Cuentas</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Búsqueda Prohibida Detectada</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Hola, tu compañero intentó realizar una búsqueda con un término prohibido que fue interceptado y bloqueado por FocusPanic.
                </p>
                <div class="alert-box">
                  <div style="font-size: 12px; font-weight: 700; color: #dc2626; text-transform: uppercase; margin-bottom: 4px;">🚫 Palabra Clave Intentada</div>
                  <div style="font-size: 22px; font-weight: 900; color: #b91c1c; font-family: monospace;">&ldquo;\(keyword)&rdquo;</div>
                  <div style="margin-top: 12px; font-size: 13px; color: #64748b;">
                    <strong>Aplicación:</strong> \(source) • <strong>Hora:</strong> \(Date().formatted(date: .omitted, time: .shortened))
                  </div>
                </div>
                <p style="font-size: 13px; color: #64748b; line-height: 1.5;">
                  💬 <strong>Consejo de apoyo:</strong> La rendición de cuentas compasiva funciona mejor que el juicio. Un simple mensaje como <em>&ldquo;¿Todo bien? Recuerda tu meta de hoy&rdquo;</em> puede ayudarlo a recuperar el enfoque.
                </p>
              </div>
              <div class="footer">FocusPanic • Sistema de Apoyo y Rendición de Cuentas</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateTamperAlertHTML(actionDetail: String) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #7c2d12 0%, #ea580c 50%, #f97316 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">⚠️ Alerta de Seguridad</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Intento de Desactivar FocusPanic</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Se ha registrado un intento de manipulación o cierre forzado de la aplicación en el Mac de tu compañero.
                </p>
                <div style="background: rgba(249, 115, 22, 0.1); border: 1px solid #f97316; border-radius: 12px; padding: 16px; margin: 20px 0;">
                  <strong style="color: #ea580c; display: block; margin-bottom: 4px;">🛡️ Acción Detectada</strong>
                  <span style="font-size: 14px; font-weight: 600; color: #1e293b;">\(actionDetail)</span>
                  <div style="margin-top: 8px; font-size: 12px; color: #64748b;">Fecha y Hora: \(Date().formatted(date: .abbreviated, time: .standard))</div>
                </div>
              </div>
              <div class="footer">FocusPanic • Sistema de Autoprotección</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateEmergencyUnlockAlertHTML(reflectionText: String, remainingMinutes: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #1e1b4b 0%, #4338ca 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🔓 Sesión Interrumpida</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Cancelación de Modo Enfoque</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Tu compañero utilizó el mecanismo de fricción consciente para cancelar su sesión de enfoque antes del tiempo programado.
                </p>
                <div style="background: rgba(99, 102, 241, 0.08); border-left: 4px solid #6366f1; border-radius: 8px; padding: 16px; margin: 20px 0;">
                  <div style="font-size: 12px; font-weight: 700; color: #4338ca; text-transform: uppercase; margin-bottom: 4px;">⏱️ Tiempo Restante al Cancelar: \(remainingMinutes) min</div>
                  <div style="font-size: 14px; font-style: italic; color: #334155; margin-top: 8px;">&ldquo;\(reflectionText)&rdquo;</div>
                </div>
              </div>
              <div class="footer">FocusPanic • Modo Enfoque con Fricción Consciente</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateIncognitoAlertHTML(attemptsCount: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #312e81 0%, #4c1d95 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">👀 Alerta de Comportamiento</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Intentos de Navegación Privada</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Se han interceptado y cerrado <strong>\(attemptsCount) ventanas de modo incógnito / privado</strong> consecutivas en los navegadores web de tu compañero.
                </p>
                <div style="background: rgba(139, 92, 246, 0.1); border: 1px solid #8b5cf6; border-radius: 12px; padding: 16px; margin: 20px 0;">
                  <strong style="color: #7c3aed; display: block; margin-bottom: 4px;">🕵️ Escudo Anti-Incógnito Activo</strong>
                  <span style="font-size: 13px; color: #64748b;">Todas las ventanas privadas fueron cerradas automáticamente.</span>
                </div>
              </div>
              <div class="footer">FocusPanic • Escudo Anti-Incógnito</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateAchievementAlertHTML(tierTitle: String, tierLevel: Int, streakDays: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #78350f 0%, #d97706 50%, #f59e0b 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🎉 ¡Gran Logro Desbloqueado!</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Nuevo Rango de Disciplina</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  ¡Buenas noticias! Tu compañero acaba de subir de nivel en FocusPanic gracias a su constancia y sesiones completadas.
                </p>
                <div style="background: rgba(245, 158, 11, 0.1); border: 2px solid #f59e0b; border-radius: 14px; padding: 20px; text-align: center; margin: 20px 0;">
                  <div style="font-size: 13px; font-weight: 700; color: #d97706; text-transform: uppercase;">Rango Actual</div>
                  <div style="font-size: 24px; font-weight: 900; color: #b45309; margin-top: 4px;">Nivel \(tierLevel) • \(tierTitle)</div>
                  <div style="font-size: 14px; font-weight: 700; color: #ea580c; margin-top: 8px;">🔥 Racha de \(streakDays) Días Consecutivos</div>
                </div>
                <p style="font-size: 13px; color: #64748b;">
                  💬 <strong>Acción sugerida:</strong> Envíale un mensaje de felicitación. El refuerzo positivo social consolida los circuitos de disciplina en el cerebro con TDAH.
                </p>
              </div>
              <div class="footer">FocusPanic • Gamificación de la Disciplina</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateSocialLimitAlertHTML(appName: String, limitMinutes: Int, totalMinutes: Int) -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <style>
            :root { color-scheme: light dark; }
            body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #1e3a8a 0%, #2563eb 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">⏱️ Límite Superado</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Exceso de Tiempo en Redes</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  Tu compañero superó el límite diario de tiempo asignado para <strong>\(appName)</strong>.
                </p>
                <div style="background: rgba(37, 99, 235, 0.08); border-left: 4px solid #2563eb; border-radius: 8px; padding: 16px; margin: 20px 0;">
                  <div><strong>Límite configurado:</strong> \(limitMinutes) min/día</div>
                  <div style="color: #dc2626; font-weight: 700; margin-top: 4px;"><strong>Tiempo consumido hoy:</strong> \(totalMinutes) min</div>
                </div>
              </div>
              <div class="footer">FocusPanic • Bienestar Digital y Límites de Apps</div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generateTestEmailHTML() -> String {
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <meta name="supported-color-schemes" content="light dark">
          <style>
            :root { color-scheme: light dark; supported-color-schemes: light dark; }
            body { margin: 0; padding: 0; width: 100% !important; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f1f5f9; color: #1e293b; }
            .wrapper { width: 100%; background-color: #f1f5f9; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #ffffff; border-radius: 18px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 12px 30px rgba(0,0,0,0.06); }
            .header { background: linear-gradient(135deg, #065f46 0%, #047857 50%, #059669 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
            .badge { display: inline-block; padding: 5px 14px; background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.35); border-radius: 20px; font-size: 11px; font-weight: 800; letter-spacing: 1.5px; text-transform: uppercase; color: #ffffff; }
            .content { padding: 30px 26px; }
            .footer { background: #f8fafc; border-top: 1px solid #e2e8f0; padding: 18px; text-align: center; font-size: 12px; color: #94a3b8; }
            
            @media (prefers-color-scheme: dark) {
              body, .wrapper { background-color: #090a10 !important; color: #f1f5f9 !important; }
              .card { background-color: #141724 !important; border-color: #24293e !important; }
              .content { color: #f1f5f9 !important; }
              .footer { background: #0f111a !important; border-color: #24293e !important; color: #64748b !important; }
            }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🧪 Verificación Exitosa</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff;">Servicio de Correo Activo</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.5; margin: 0 0 16px 0;">
                  ¡Excelente! Este correo confirma que las notificaciones de FocusPanic, códigos OTP y reportes de progreso están conectados y listos para su uso.
                </p>
                <div style="background: rgba(16, 185, 129, 0.1); border: 1px solid #10b981; border-radius: 12px; padding: 16px; margin: 20px 0;">
                  <strong style="color: #10b981; display: block; margin-bottom: 4px;">✅ Conexión SMTP Cifrada</strong>
                  <span style="font-size: 13px; color: #64748b;">Tu canal de comunicación seguro está listo para entregas instantáneas.</span>
                </div>
              </div>
              <div class="footer">
                FocusPanic • Aplicación de Enfoque y Rescate para TDAH en macOS
              </div>
            </div>
          </div>
        </body>
        </html>
        """
    }
    
    private func generatePartnerOTPTimeRequestHTML(site: String, minutes: Int, otpCode: String) -> String {
        let spacedCode = otpCode.map { String($0) }.joined(separator: " ")
        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <meta name="color-scheme" content="light dark">
          <meta name="supported-color-schemes" content="light dark">
          <style>
            :root { color-scheme: light dark; supported-color-schemes: light dark; }
            body { margin: 0; padding: 0; width: 100% !important; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif; background-color: #0c0e17; color: #f1f5f9; }
            .wrapper { width: 100%; background-color: #0c0e17; padding: 36px 12px; }
            .card { max-width: 520px; margin: 0 auto; background-color: #141726; border-radius: 20px; border: 1px solid rgba(255, 255, 255, 0.1); overflow: hidden; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.7); }
            .header { background: radial-gradient(circle at 50% 0%, #312e81 0%, #1e1b4b 100%); padding: 32px 24px; text-align: center; border-bottom: 1px solid rgba(255,255,255,0.08); }
            .badge { display: inline-flex; align-items: center; gap: 6px; padding: 5px 14px; background: rgba(99, 102, 241, 0.2); border: 1px solid rgba(99, 102, 241, 0.4); border-radius: 999px; font-size: 11px; font-weight: 800; letter-spacing: 1.2px; text-transform: uppercase; color: #a5b4fc; }
            .content { padding: 32px 28px; }
            .info-box { background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.08); border-radius: 14px; padding: 18px; margin: 20px 0; }
            .info-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; font-size: 14px; }
            .info-label { color: #94a3b8; }
            .info-val { font-weight: 700; color: #ffffff; }
            .otp-container { text-align: center; margin: 26px 0 20px; padding: 22px; background: linear-gradient(135deg, rgba(99, 102, 241, 0.15) 0%, rgba(168, 85, 247, 0.15) 100%); border: 1px solid rgba(99, 102, 241, 0.35); border-radius: 16px; }
            .otp-code { font-family: "SF Mono", Menlo, Consolas, monospace; font-size: 36px; font-weight: 900; letter-spacing: 8px; color: #ffffff; text-shadow: 0 0 20px rgba(99, 102, 241, 0.6); margin: 6px 0; }
            .otp-caption { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: #cbd5e1; font-weight: 600; }
            .footer { background: #0f111c; border-top: 1px solid rgba(255, 255, 255, 0.06); padding: 18px; text-align: center; font-size: 12px; color: #64748b; }
            .notice-text { font-size: 13px; color: #94a3b8; line-height: 1.5; margin-top: 14px; text-align: center; }
          </style>
        </head>
        <body>
          <div class="wrapper">
            <div class="card">
              <div class="header">
                <div class="badge">🔑 Solicitud de Tiempo Extra</div>
                <h1 style="margin: 14px 0 0 0; font-size: 22px; font-weight: 800; color: #ffffff; letter-spacing: -0.5px;">Autorización de Compañero</h1>
              </div>
              <div class="content">
                <p style="font-size: 15px; line-height: 1.6; margin: 0 0 16px 0; color: #e2e8f0; text-align: center;">
                  Tu compañero está solicitando una excepción temporal de navegación en FocusPanic.
                </p>
                
                <div class="info-box">
                  <div class="info-row">
                    <span class="info-label">Sitio Solicitado:</span>
                    <span class="info-val" style="color: #f43f5e;">⛔ \(site)</span>
                  </div>
                  <div class="info-row" style="border-top: 1px solid rgba(255,255,255,0.06); margin-top: 6px; padding-top: 10px;">
                    <span class="info-label">Tiempo Adicional:</span>
                    <span class="info-val" style="color: #38bdf8;">+\(minutes) minutos</span>
                  </div>
                </div>

                <div class="otp-container">
                  <div class="otp-caption">Código de Autorización (Uso Único)</div>
                  <div class="otp-code">\(spacedCode)</div>
                  <div style="font-size: 12px; color: #a5b4fc; margin-top: 4px;">⏱️ Válido durante los próximos 15 minutos</div>
                </div>

                <p class="notice-text">
                  Si consideras oportuno otorgarle este tiempo, <strong>compártele el código</strong> para desbloquear la sesión. Si prefieres que mantenga su enfoque, no hagas nada.
                </p>
              </div>
              <div class="footer">
                FocusPanic • Protección de Enfoque y Responsabilidad Compartida
              </div>
            </div>
          </div>
        </body>
        </html>
        """
    }
}

