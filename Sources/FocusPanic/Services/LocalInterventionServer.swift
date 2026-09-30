import Foundation
import AppKit

public final class LocalInterventionServer {
    public static let shared = LocalInterventionServer()
    
    private var serverSocket: Int32 = -1
    private var dispatchSource: DispatchSourceRead?
    private let port: UInt16 = 8484
    private var isRunning = false
    private let serverQueue = DispatchQueue(label: "com.focuspanic.localserver", qos: .userInitiated)
    
    private var appIconBase64: String = ""
    
    private init() {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: iconPath)) {
            if data.count < 250_000 {
                self.appIconBase64 = data.base64EncodedString()
            }
        }
    }
    
    public func start(retryCount: Int = 0) {
        guard !isRunning else { return }
        
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.serverSocket >= 0 {
                close(self.serverSocket)
                self.serverSocket = -1
            }
            
            self.serverSocket = socket(AF_INET, SOCK_STREAM, 0)
            guard self.serverSocket >= 0 else {
                print("⚠️ [FocusPanic] Error al crear socket para servidor local")
                return
            }
            
            var yes: Int32 = 1
            setsockopt(self.serverSocket, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = self.port.bigEndian
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")
            
            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(self.serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            guard bindResult >= 0 else {
                print("⚠️ [FocusPanic] No se pudo enlazar al puerto \(self.port) (intento \(retryCount + 1)/3)")
                close(self.serverSocket)
                self.serverSocket = -1
                if retryCount < 3 {
                    self.serverQueue.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                        self?.start(retryCount: retryCount + 1)
                    }
                }
                return
            }
            
            guard listen(self.serverSocket, 30) >= 0 else {
                print("⚠️ [FocusPanic] Error al escuchar en el puerto \(self.port)")
                close(self.serverSocket)
                self.serverSocket = -1
                return
            }
            
            let source = DispatchSource.makeReadSource(fileDescriptor: self.serverSocket, queue: self.serverQueue)
            source.setEventHandler { [weak self] in
                self?.acceptIncomingConnection()
            }
            source.setCancelHandler { [weak self] in
                if let fd = self?.serverSocket, fd >= 0 {
                    close(fd)
                    self?.serverSocket = -1
                }
            }
            
            source.resume()
            self.dispatchSource = source
            self.isRunning = true
            print("🧘 [FocusPanic] Servidor de intervención activo en http://127.0.0.1:\(self.port)")
        }
    }
    
    public func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
        isRunning = false
    }
    
    private let clientProcessingQueue = DispatchQueue(label: "com.hector.FocusPanic.httpClients", qos: .userInteractive, attributes: .concurrent)
    
    private func acceptIncomingConnection() {
        var clientAddr = sockaddr_in()
        var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(self.serverSocket, $0, &clientLen)
            }
        }
        
        guard clientSocket >= 0 else { return }
        
        clientProcessingQueue.async { [weak self] in
            guard let self = self else {
                close(clientSocket)
                return
            }
            
            var buffer = [UInt8](repeating: 0, count: 4096)
            let bytesRead = read(clientSocket, &buffer, buffer.count)
            
            guard bytesRead > 0, let requestStr = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) else {
                close(clientSocket)
                return
            }
            
            // Endpoint para iniciar sesión de enfoque remotamente (desde InnotchBar)
            if requestStr.contains("/api/start-session") {
                var minutes = 25
                var preset = "Pomodoro TDAH"
                if let urlLine = requestStr.components(separatedBy: "\r\n").first {
                    if let queryStart = urlLine.range(of: "?") {
                        let queryPart = String(urlLine[queryStart.upperBound...]).components(separatedBy: " ").first ?? ""
                        let pairs = queryPart.components(separatedBy: "&")
                        for pair in pairs {
                            let kv = pair.components(separatedBy: "=")
                            if kv.count == 2 {
                                let key = kv[0]
                                let val = kv[1].removingPercentEncoding ?? kv[1]
                                if key == "minutes" { minutes = Int(val) ?? 25 }
                                else if key == "preset" { preset = val }
                            }
                        }
                    }
                }
                DispatchQueue.main.async {
                    FocusEngine.shared.startFocusSession(durationMinutes: minutes, presetName: preset)
                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("com.focuspanic.sessionUpdated"),
                        object: nil,
                        userInfo: nil,
                        deliverImmediately: true
                    )
                    let json = "{\"success\":true,\"minutes\":\(minutes),\"preset\":\"\(preset)\"}"
                    let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                    _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                    close(clientSocket)
                }
                return
            }

            // Endpoint para detener sesión de enfoque
            if requestStr.contains("/api/end-session") {
                DispatchQueue.main.async {
                    FocusEngine.shared.endSession(didCompleteNormally: false)
                    DistributedNotificationCenter.default().postNotificationName(
                        NSNotification.Name("com.focuspanic.sessionUpdated"),
                        object: nil,
                        userInfo: nil,
                        deliverImmediately: true
                    )
                    let json = "{\"success\":true,\"message\":\"Session ended\"}"
                    let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                    _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                    close(clientSocket)
                }
                return
            }

            // Endpoint para consultar estado de la sesión
            if requestStr.contains("/api/session-status") {
                DispatchQueue.main.async {
                    let engine = FocusEngine.shared
                    let isActive = engine.sessionStatus == .active
                    let remaining = Int(engine.remainingSeconds)
                    let preset = engine.currentSession?.presetName ?? ""
                    let totalSec = Int(engine.currentSession?.originalDurationSeconds ?? 0)
                    let stats = FocusStatsManager.shared.stats
                    let streak = stats.currentStreakDays
                    let xp = stats.totalXP
                    let json = "{\"isActive\":\(isActive),\"remainingSeconds\":\(remaining),\"presetName\":\"\(preset)\",\"originalDurationSeconds\":\(totalSec),\"streakDays\":\(streak),\"totalXP\":\(xp)}"
                    let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                    _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                    close(clientSocket)
                }
                return
            }

            // 1. Endpoint para cerrar la pestaña activa nativamente en el navegador
            if requestStr.contains("/api/close-tab") || requestStr.contains("/close-tab") {
                self.closeFrontmostBrowserTab()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{\"status\":\"closed\"}"
                _ = response.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                close(clientSocket)
                return
            }
            
            // 2. Endpoint para obtener información del compañero (Email enmascarado y si hay clave)
            if requestStr.contains("/api/partner-info") {
                DispatchQueue.main.async {
                    let email = FocusEngine.shared.settings.officialPartnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasEmail = !email.isEmpty
                    let maskedEmail = self.maskEmail(email)
                    let hasMaster = !FocusEngine.shared.settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    
                    let json = """
                    {"hasPartnerEmail":\(hasEmail),"maskedEmail":"\(maskedEmail)","hasMasterPassword":\(hasMaster)}
                    """
                    let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                    _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                    close(clientSocket)
                }
                return
            }
            
            // 3. Endpoint para solicitar código OTP por correo al compañero
            if requestStr.contains("/api/request-otp") {
                var site = ""
                var minutes = 30
                
                if let urlLine = requestStr.components(separatedBy: "\r\n").first {
                    if let queryStart = urlLine.range(of: "?") {
                        let queryPart = String(urlLine[queryStart.upperBound...]).components(separatedBy: " ").first ?? ""
                        let pairs = queryPart.components(separatedBy: "&")
                        for pair in pairs {
                            let kv = pair.components(separatedBy: "=")
                            if kv.count == 2 {
                                let key = kv[0]
                                let val = kv[1].removingPercentEncoding ?? kv[1]
                                if key == "site" { site = val }
                                else if key == "minutes" { minutes = Int(val) ?? 30 }
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    FocusEngine.shared.generateAndSendPartnerOTP(site: site, minutes: minutes) { result in
                        switch result {
                        case .success:
                            let partnerEmail = FocusEngine.shared.settings.officialPartnerEmail
                            let masked = self.maskEmail(partnerEmail)
                            let json = "{\"success\":true,\"message\":\"Código enviado exitosamente.\",\"maskedEmail\":\"\(masked)\",\"expiresInSeconds\":900}"
                            let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                            _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                            close(clientSocket)
                        case .failure(let error):
                            let escapedError = self.htmlEscape(error.localizedDescription)
                            let json = "{\"success\":false,\"error\":\"\(escapedError)\"}"
                            let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                            _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                            close(clientSocket)
                        }
                    }
                }
                return
            }
            
            // 4. Endpoint para extender límite y conceder bypass temporal con código OTP o Clave Maestra
            if requestStr.contains("/api/extend-limit") {
                var site = ""
                var minutes = 30
                var code = ""
                
                if let urlLine = requestStr.components(separatedBy: "\r\n").first {
                    if let queryStart = urlLine.range(of: "?") {
                        let queryPart = String(urlLine[queryStart.upperBound...]).components(separatedBy: " ").first ?? ""
                        let pairs = queryPart.components(separatedBy: "&")
                        for pair in pairs {
                            let kv = pair.components(separatedBy: "=")
                            if kv.count == 2 {
                                let key = kv[0]
                                let val = kv[1].removingPercentEncoding ?? kv[1]
                                if key == "site" { site = val }
                                else if key == "minutes" { minutes = Int(val) ?? 30 }
                                else if key == "code" { code = val }
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    var authorized = false
                    var grantedMinutes = minutes
                    
                    let (isValid, otpMins) = FocusEngine.shared.verifyAndConsumePartnerOTP(site: site, code: code)
                    if isValid {
                        authorized = true
                        if otpMins > 0 { grantedMinutes = otpMins }
                    } else if FocusEngine.shared.verifyCompanionPassword(code) {
                        authorized = true
                    }
                    
                    if authorized {
                        _ = FocusEngine.shared.grantTemporaryBypass(identifier: site, minutes: grantedMinutes)
                        let json = "{\"success\":true,\"message\":\"Tiempo concedido +\(grantedMinutes) min exitosamente.\",\"minutes\":\(grantedMinutes)}"
                        let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                        _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                        close(clientSocket)
                    } else {
                        let errorMsg = "Código incorrecto o no autorizado. Ingresa el código recibido por correo o la clave de tu compañero."
                        let json = "{\"success\":false,\"error\":\"\(errorMsg)\"}"
                        let resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n\(json)"
                        _ = resp.withCString { ptr in write(clientSocket, ptr, strlen(ptr)) }
                        close(clientSocket)
                    }
                }
                return
            }
            
            // 5. Servir página principal de bloqueo
            var requestedHost = "Sitio Distractor"
            if let firstLine = requestStr.components(separatedBy: "\r\n").first {
                if let range = firstLine.range(of: "site=") {
                    let sub = String(firstLine[range.upperBound...])
                    let siteName = sub.components(separatedBy: " ").first?.components(separatedBy: "&").first ?? ""
                    if !siteName.isEmpty {
                        requestedHost = self.htmlEscape(siteName.removingPercentEncoding ?? siteName)
                    }
                }
            }
            
            let html = self.generateBlockPageHTML(blockedHost: requestedHost)
            let header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\nCache-Control: no-cache, no-store, must-revalidate\r\n\r\n"
            let fullResponse = header + html
            
            if let data = fullResponse.data(using: .utf8) {
                data.withUnsafeBytes { rawBuffer in
                    var totalSent = 0
                    let count = rawBuffer.count
                    while totalSent < count {
                        guard let base = rawBuffer.baseAddress else { break }
                        let sent = write(clientSocket, base + totalSent, count - totalSent)
                        if sent <= 0 { break }
                        totalSent += sent
                    }
                }
            }
            
            close(clientSocket)
        }
    }
    
    private func maskEmail(_ email: String) -> String {
        let parts = email.components(separatedBy: "@")
        guard parts.count == 2, let first = parts.first, let domain = parts.last else { return email }
        if first.count <= 2 {
            return "\(first.prefix(1))***@\(domain)"
        }
        return "\(first.prefix(2))***@\(domain)"
    }
    
    public func closeFrontmostBrowserTab() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let runningApps = NSWorkspace.shared.runningApplications
            let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
            
            if runningBundleIds.contains("com.apple.Safari") {
                let safariScript = "tell application \"Safari\" to if (count of windows) > 0 then close current tab of front window"
                self.executeAppleScript(safariScript)
            }
            if runningBundleIds.contains("com.google.Chrome") {
                let chromeScript = "tell application \"Google Chrome\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(chromeScript)
            }
            if runningBundleIds.contains("com.brave.Browser") {
                let braveScript = "tell application \"Brave Browser\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(braveScript)
            }
            if runningBundleIds.contains("com.microsoft.edgemac") {
                let edgeScript = "tell application \"Microsoft Edge\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(edgeScript)
            }
            if runningBundleIds.contains("company.thebrowser.Browser") {
                let arcScript = "tell application \"Arc\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(arcScript)
            }
            if runningBundleIds.contains("com.operasoftware.Opera") {
                let operaScript = "tell application \"Opera\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(operaScript)
            }
            if runningBundleIds.contains("com.vivaldi.Vivaldi") {
                let vivaldiScript = "tell application \"Vivaldi\" to if (count of windows) > 0 then close active tab of front window"
                self.executeAppleScript(vivaldiScript)
            }
        }
    }
    
    private func executeAppleScript(_ source: String) {
        if let appleScript = NSAppleScript(source: source) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    private func htmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func generateBlockPageHTML(blockedHost: String) -> String {
        let isEnglish = LocalizationService.shared.currentLanguage == .english
        let docLang = isEnglish ? "en" : "es"
        let pageTitle = isEnglish ? "FocusPanic - Access Protected" : "FocusPanic - Acceso Protegido"
        let badgeText = isEnglish ? "ACCESO BLOQUEADO POR FOCUSPANIC" : "ACCESO BLOQUEADO POR FOCUSPANIC"
        let headerTitle = isEnglish ? "Pausa Consciente" : "Pausa Consciente"
        let btnCloseText = isEnglish ? "Cerrar Pestaña y Volver al Enfoque" : "Cerrar Pestaña y Volver al Enfoque"
        let btnPartnerText = isEnglish ? "Desbloquear con Código" : "Desbloquear con Código"
        let footerText = isEnglish
            ? "<strong>FocusPanic</strong> is active on your Mac safeguarding your attention and daily streak."
            : "<strong>FocusPanic</strong> está activo en tu Mac protegiendo tu atención y racha diaria."

        let iconHtml: String
        if !appIconBase64.isEmpty {
            iconHtml = """
            <div class="app-icon-wrapper">
                <img src="data:image/png;base64,\(appIconBase64)" alt="FocusPanic" class="app-icon-img" />
                <div class="icon-glow-ring"></div>
            </div>
            """
        } else {
            iconHtml = """
            <div class="app-icon-wrapper">
                <div class="fallback-icon">
                    <i data-lucide="shield-alert" style="width:36px;height:36px;"></i>
                </div>
                <div class="icon-glow-ring"></div>
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="\(docLang)">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="dark">
            <meta name="theme-color" content="#07090e">
            <title>\(pageTitle)</title>
            <!-- Librería Oficial Lucide Icons -->
            <script src="https://unpkg.com/lucide@latest"></script>
            <style>
                :root {
                    color-scheme: dark !important;
                    --bg-dark: #07090e;
                    --card-bg: rgba(13, 16, 28, 0.92);
                    --card-border: rgba(255, 255, 255, 0.08);
                    --primary-rose: #f43f5e;
                    --primary-indigo: #6366f1;
                    --primary-cyan: #38bdf8;
                    --primary-amber: #f59e0b;
                    --primary-emerald: #10b981;
                    --text-main: #f8fafc;
                    --text-muted: #94a3b8;
                    --text-sub: #64748b;
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                html, body {
                    background-color: var(--bg-dark) !important;
                    color-scheme: dark !important;
                    width: 100%;
                    min-height: 100vh;
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", Roboto, sans-serif;
                    color: var(--text-main);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 24px;
                    overflow-x: hidden;
                    position: relative;
                }
                
                /* Iconos Lucide */
                .lucide, .svg-icon {
                    width: 16px;
                    height: 16px;
                    stroke: currentColor;
                    stroke-width: 2;
                    fill: none;
                    stroke-linecap: round;
                    stroke-linejoin: round;
                    display: inline-block;
                    vertical-align: middle;
                    flex-shrink: 0;
                }
                .lucide.sm, .svg-icon.sm { width: 13px; height: 13px; stroke-width: 2.2; }
                .lucide.lg, .svg-icon.lg { width: 20px; height: 20px; }
                
                /* Fondo Atmosférico */
                .ambient-glow {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    width: 650px;
                    height: 650px;
                    background: radial-gradient(circle, rgba(99, 102, 241, 0.12) 0%, rgba(244, 63, 94, 0.08) 40%, rgba(7, 9, 14, 0) 70%);
                    pointer-events: none;
                    z-index: 0;
                    filter: blur(40px);
                }
                
                .bg-watermark-x {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%) scale(1.05);
                    font-size: 80vh;
                    font-weight: 900;
                    color: rgba(255, 255, 255, 0.015);
                    user-select: none;
                    pointer-events: none;
                    z-index: 0;
                    line-height: 1;
                }

                .card {
                    position: relative;
                    z-index: 10;
                    background: var(--card-bg);
                    backdrop-filter: blur(40px);
                    -webkit-backdrop-filter: blur(40px);
                    border: 1px solid var(--card-border);
                    border-radius: 28px;
                    padding: 36px 32px;
                    max-width: 500px;
                    width: 100%;
                    box-shadow: 0 30px 70px -15px rgba(0, 0, 0, 0.8), 0 0 0 1px rgba(255, 255, 255, 0.05);
                    transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
                }

                .view-section {
                    display: block;
                    animation: fadeInView 0.35s cubic-bezier(0.16, 1, 0.3, 1);
                }
                .view-section.hidden {
                    display: none !important;
                }
                @keyframes fadeInView {
                    from { opacity: 0; transform: translateY(12px) scale(0.98); }
                    to { opacity: 1; transform: translateY(0) scale(1); }
                }

                .app-icon-wrapper {
                    position: relative;
                    width: 72px;
                    height: 72px;
                    margin: 0 auto 14px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .app-icon-img {
                    width: 64px;
                    height: 64px;
                    border-radius: 16px;
                    box-shadow: 0 10px 25px rgba(0, 0, 0, 0.6), 0 0 30px rgba(244, 63, 94, 0.3);
                    position: relative;
                    z-index: 2;
                }
                .fallback-icon {
                    position: relative;
                    z-index: 2;
                    color: #fb7185;
                }
                .icon-glow-ring {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    border-radius: 20px;
                    background: linear-gradient(135deg, rgba(244, 63, 94, 0.4), rgba(99, 102, 241, 0.4));
                    filter: blur(14px);
                    z-index: 1;
                }

                .badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    background: rgba(244, 63, 94, 0.12);
                    color: #fb7185;
                    border: 1px solid rgba(244, 63, 94, 0.28);
                    padding: 5px 12px;
                    border-radius: 999px;
                    font-size: 11px;
                    font-weight: 700;
                    letter-spacing: 0.8px;
                    text-transform: uppercase;
                    margin-bottom: 12px;
                }
                .badge.badge-indigo {
                    background: rgba(99, 102, 241, 0.14);
                    color: #a5b4fc;
                    border-color: rgba(99, 102, 241, 0.35);
                }

                h1 {
                    font-size: 24px;
                    font-weight: 800;
                    letter-spacing: -0.5px;
                    margin-bottom: 8px;
                    color: #ffffff;
                    text-align: center;
                }
                
                .site-pill {
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    color: #fca5a5;
                    font-family: "SF Mono", Menlo, Consolas, monospace;
                    font-size: 13px;
                    font-weight: 700;
                    padding: 5px 14px;
                    border-radius: 10px;
                    margin-bottom: 16px;
                }
                
                .quote-box {
                    background: rgba(255, 255, 255, 0.03);
                    border: 1px solid rgba(255, 255, 255, 0.07);
                    border-radius: 14px;
                    padding: 14px 18px;
                    margin-bottom: 20px;
                    font-style: italic;
                    color: #cbd5e1;
                    font-size: 13px;
                    line-height: 1.5;
                    text-align: center;
                }
                .quote-author {
                    display: block;
                    margin-top: 6px;
                    font-style: normal;
                    font-weight: 700;
                    font-size: 10px;
                    color: #fb7185;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }

                .actions-stack {
                    display: flex;
                    flex-direction: column;
                    gap: 10px;
                    margin-bottom: 16px;
                }

                .btn-primary {
                    width: 100%;
                    background: linear-gradient(135deg, #f43f5e 0%, #e11d48 100%);
                    border: 1px solid rgba(255, 255, 255, 0.15);
                    border-radius: 14px;
                    padding: 13px 20px;
                    color: #ffffff;
                    font-size: 14px;
                    font-weight: 700;
                    cursor: pointer;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    box-shadow: 0 8px 24px -4px rgba(244, 63, 94, 0.4);
                    transition: all 0.2s ease;
                }
                .btn-primary:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 12px 30px -4px rgba(244, 63, 94, 0.6);
                }
                .btn-primary:active { transform: translateY(0); }

                .btn-secondary {
                    width: 100%;
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    border-radius: 14px;
                    padding: 12px 18px;
                    color: #cbd5e1;
                    font-size: 13px;
                    font-weight: 600;
                    cursor: pointer;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    transition: all 0.2s ease;
                }
                .btn-secondary:hover {
                    background: rgba(255, 255, 255, 0.09);
                    border-color: rgba(99, 102, 241, 0.4);
                    color: #ffffff;
                }

                /* VISTA DE DESBLOQUEO */
                .unlock-top-bar {
                    display: flex;
                    align-items: center;
                    justify-content: space-between;
                    margin-bottom: 16px;
                }
                .btn-back {
                    background: transparent;
                    border: none;
                    color: #94a3b8;
                    font-size: 13px;
                    font-weight: 600;
                    cursor: pointer;
                    display: inline-flex;
                    align-items: center;
                    gap: 6px;
                    padding: 6px 10px;
                    border-radius: 8px;
                    transition: color 0.15s ease, background 0.15s ease;
                }
                .btn-back:hover {
                    color: #ffffff;
                    background: rgba(255, 255, 255, 0.06);
                }

                .field-section {
                    margin-bottom: 16px;
                    text-align: left;
                }
                .field-label {
                    display: block;
                    font-size: 11px;
                    font-weight: 700;
                    color: #94a3b8;
                    margin-bottom: 8px;
                    text-transform: uppercase;
                    letter-spacing: 0.6px;
                }

                .chips-grid {
                    display: grid;
                    grid-template-columns: repeat(4, 1fr);
                    gap: 6px;
                }
                .time-chip {
                    background: rgba(255, 255, 255, 0.05);
                    border: 1px solid rgba(255, 255, 255, 0.1);
                    border-radius: 10px;
                    padding: 8px 4px;
                    font-size: 13px;
                    font-weight: 600;
                    color: #e2e8f0;
                    cursor: pointer;
                    text-align: center;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 6px;
                    transition: all 0.15s ease;
                }
                .time-chip:hover {
                    background: rgba(255, 255, 255, 0.09);
                    border-color: rgba(255, 255, 255, 0.2);
                }
                .time-chip.active {
                    background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
                    color: #ffffff;
                    border-color: rgba(99, 102, 241, 0.6);
                    box-shadow: 0 4px 14px rgba(99, 102, 241, 0.35);
                }

                .custom-time-row {
                    display: none;
                    margin-top: 8px;
                }
                .input-field {
                    width: 100%;
                    background: rgba(10, 13, 22, 0.85);
                    border: 1px solid rgba(255, 255, 255, 0.12);
                    border-radius: 12px;
                    padding: 12px 14px;
                    color: #ffffff;
                    font-size: 14px;
                    outline: none;
                    transition: border-color 0.15s ease, box-shadow 0.15s ease;
                }
                .input-field:focus {
                    border-color: #6366f1;
                    box-shadow: 0 0 0 3px rgba(99, 102, 241, 0.25);
                }

                .otp-input-field {
                    letter-spacing: 6px;
                    font-size: 22px;
                    font-weight: 800;
                    text-align: center;
                    font-family: "SF Mono", Menlo, Consolas, monospace;
                }

                .info-banner {
                    background: rgba(99, 102, 241, 0.08);
                    border: 1px solid rgba(99, 102, 241, 0.2);
                    border-radius: 12px;
                    padding: 12px 14px;
                    margin-bottom: 14px;
                    font-size: 12px;
                    color: #cbd5e1;
                    line-height: 1.45;
                }
                .info-banner strong { color: #a5b4fc; }

                .btn-action-indigo {
                    width: 100%;
                    background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
                    border: 1px solid rgba(255, 255, 255, 0.15);
                    border-radius: 14px;
                    padding: 13px 20px;
                    color: #ffffff;
                    font-size: 14px;
                    font-weight: 700;
                    cursor: pointer;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    box-shadow: 0 8px 24px -4px rgba(99, 102, 241, 0.4);
                    transition: all 0.2s ease;
                }
                .btn-action-indigo:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 12px 30px -4px rgba(99, 102, 241, 0.6);
                }
                .btn-action-indigo:active { transform: translateY(0); }
                .btn-action-indigo:disabled {
                    opacity: 0.6;
                    cursor: not-allowed;
                    transform: none;
                }

                .btn-action-emerald {
                    width: 100%;
                    background: linear-gradient(135deg, #10b981 0%, #059669 100%);
                    border: 1px solid rgba(255, 255, 255, 0.15);
                    border-radius: 14px;
                    padding: 13px 20px;
                    color: #ffffff;
                    font-size: 14px;
                    font-weight: 700;
                    cursor: pointer;
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    box-shadow: 0 8px 24px -4px rgba(16, 185, 129, 0.4);
                    transition: all 0.2s ease;
                    margin-top: 10px;
                }
                .btn-action-emerald:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 12px 30px -4px rgba(16, 185, 129, 0.6);
                }
                .btn-action-emerald:active { transform: translateY(0); }
                .btn-action-emerald:disabled {
                    opacity: 0.6;
                    cursor: not-allowed;
                    transform: none;
                }

                .status-box {
                    display: none;
                    font-size: 12px;
                    padding: 10px 14px;
                    border-radius: 10px;
                    margin-bottom: 14px;
                    line-height: 1.4;
                    animation: fadeInView 0.2s ease;
                }
                .status-box.error {
                    background: rgba(239, 68, 68, 0.15);
                    border: 1px solid rgba(239, 68, 68, 0.35);
                    color: #fca5a5;
                }
                .status-box.success {
                    background: rgba(16, 185, 129, 0.15);
                    border: 1px solid rgba(16, 185, 129, 0.35);
                    color: #6ee7b7;
                    font-weight: 600;
                    text-align: center;
                }

                .footer-text {
                    font-size: 11px;
                    color: var(--text-sub);
                    margin-top: 20px;
                    text-align: center;
                }
                .footer-text strong { color: #f43f5e; }
            </style>
        </head>
        <body>
            <div class="ambient-glow"></div>
            <div class="bg-watermark-x">✕</div>
            
            <div class="card">
                <!-- VISTA 1: PAUSA CONSCIENTE (BLOQUEO INICIAL) -->
                <div id="view-blocked" class="view-section">
                    \(iconHtml)
                    <div style="text-align: center;">
                        <div class="badge">
                            <i data-lucide="shield-alert" class="lucide sm"></i>
                            <span>\(badgeText)</span>
                        </div>
                    </div>
                    <h1>\(headerTitle)</h1>
                    <div style="text-align: center;">
                        <div class="site-pill">
                            <i data-lucide="ban" class="lucide sm"></i>
                            <span>\(blockedHost)</span>
                        </div>
                    </div>
                    
                    <div class="quote-box" id="quote-container">
                        "El autocontrol no es privación, es elegir lo que más quieres a largo plazo sobre lo que quieres ahora mismo."
                        <span class="quote-author">Tu Cerebro en Control</span>
                    </div>

                    <div class="actions-stack">
                        <button class="btn-primary" onclick="closeThisTab();">
                            <i data-lucide="check-circle" class="lucide"></i>
                            <span>\(btnCloseText)</span>
                        </button>
                        
                        <button class="btn-secondary" onclick="showUnlockView();">
                            <i data-lucide="key-round" class="lucide"></i>
                            <span>\(btnPartnerText)</span>
                        </button>
                    </div>

                    <div class="footer-text">
                        \(footerText)
                    </div>
                </div>

                <!-- VISTA 2: DESBLOQUEO CON CÓDIGO -->
                <div id="view-unlock" class="view-section hidden">
                    <div class="unlock-top-bar">
                        <button class="btn-back" onclick="showBlockedView();">
                            <i data-lucide="arrow-left" class="lucide sm"></i>
                            <span>Volver a Pausa Consciente</span>
                        </button>
                        <div class="badge badge-indigo">
                            <i data-lucide="lock" class="lucide sm"></i>
                            <span>AUTORIZACIÓN</span>
                        </div>
                    </div>

                    <h1>Desbloqueo con Código</h1>
                    <div style="text-align: center; margin-bottom: 14px;">
                        <div class="site-pill">
                            <i data-lucide="globe" class="lucide sm"></i>
                            <span>\(blockedHost)</span>
                        </div>
                    </div>

                    <!-- Mensajes de Error / Éxito -->
                    <div id="unlock-alert-error" class="status-box error"></div>
                    <div id="unlock-alert-success" class="status-box success"></div>

                    <!-- Selector de Tiempo Solicitado -->
                    <div class="field-section">
                        <label class="field-label">Tiempo Adicional Solicitado:</label>
                        <div class="chips-grid">
                            <div class="time-chip" data-mins="5" onclick="selectTimeChip(5);">+5m</div>
                            <div class="time-chip active" data-mins="15" onclick="selectTimeChip(15);">+15m</div>
                            <div class="time-chip" data-mins="30" onclick="selectTimeChip(30);">+30m</div>
                            <div class="time-chip" data-mins="60" onclick="selectTimeChip(60);">+1h</div>
                        </div>
                        <div class="chips-grid" style="margin-top: 6px; grid-template-columns: 1fr;">
                            <div class="time-chip" data-mins="custom" onclick="selectTimeChip('custom');" style="font-size: 12px;">
                                <i data-lucide="sliders" class="lucide sm"></i>
                                <span>Minutos Personalizados</span>
                            </div>
                        </div>
                        <div class="custom-time-row" id="custom-time-row">
                            <input type="number" id="custom-minutes-input" class="input-field" placeholder="Ingresa minutos (ej. 45)" min="1" max="480" />
                        </div>
                    </div>

                    <!-- Sección de Código -->
                    <div class="info-banner" id="otp-info-banner">
                        Se enviará un código de 6 dígitos al correo de tu compañero: <strong id="partner-email-display">Cargando...</strong>
                    </div>

                    <div style="margin-bottom: 14px;">
                        <button class="btn-action-indigo" id="btn-request-otp" onclick="requestPartnerOTP();">
                            <i data-lucide="send" class="lucide"></i>
                            <span>Enviar Código al Compañero</span>
                        </button>
                    </div>

                    <div class="field-section" style="margin-top: 14px;">
                        <label class="field-label">Código de Desbloqueo:</label>
                        <input type="password" id="otp-code-input" class="input-field otp-input-field" placeholder="••••••" maxlength="64" autocomplete="off" onkeydown="if(event.key==='Enter') submitOTPUnlock();" />
                    </div>

                    <button class="btn-action-emerald" id="btn-submit-otp" onclick="submitOTPUnlock();">
                        <i data-lucide="lock-open" class="lucide"></i>
                        <span>Desbloquear Sitio</span>
                    </button>

                    <div class="footer-text">
                        FocusPanic reactivará la protección automáticamente al expirar el tiempo.
                    </div>
                </div>
            </div>
            
            <script>
                const targetSite = "\(blockedHost)";
                let selectedMinutes = 15;
                let partnerInfo = { hasPartnerEmail: false, maskedEmail: '', hasMasterPassword: false };

                function initLucide() {
                    if (window.lucide && typeof lucide.createIcons === 'function') {
                        lucide.createIcons();
                    }
                }

                document.addEventListener('DOMContentLoaded', () => {
                    initLucide();
                });

                fetch('/api/partner-info')
                    .then(res => res.json())
                    .then(data => {
                        partnerInfo = data;
                        const display = document.getElementById('partner-email-display');
                        if (display) {
                            if (data.hasPartnerEmail) {
                                display.innerText = data.maskedEmail;
                            } else {
                                display.innerText = "(Sin correo configurado)";
                                const banner = document.getElementById('otp-info-banner');
                                if (banner) {
                                    banner.innerHTML = "<strong>No has configurado el correo de tu compañero</strong> en los Ajustes de FocusPanic. Puedes ingresar el código de autorización o configurarlo en la app.";
                                }
                            }
                        }
                    })
                    .catch(() => {});

                function showUnlockView() {
                    document.getElementById('view-blocked').classList.add('hidden');
                    document.getElementById('view-unlock').classList.remove('hidden');
                    clearAlerts();
                    initLucide();
                }

                function showBlockedView() {
                    document.getElementById('view-unlock').classList.add('hidden');
                    document.getElementById('view-blocked').classList.remove('hidden');
                    clearAlerts();
                    initLucide();
                }

                function selectTimeChip(mins) {
                    const chips = document.querySelectorAll('.time-chip');
                    chips.forEach(c => c.classList.remove('active'));
                    
                    const customRow = document.getElementById('custom-time-row');
                    if (mins === 'custom') {
                        selectedMinutes = 'custom';
                        document.querySelector('.time-chip[data-mins="custom"]').classList.add('active');
                        customRow.style.display = 'block';
                        document.getElementById('custom-minutes-input').focus();
                    } else {
                        selectedMinutes = parseInt(mins, 10);
                        document.querySelector(`.time-chip[data-mins="${mins}"]`).classList.add('active');
                        customRow.style.display = 'none';
                    }
                    initLucide();
                }

                function getEffectiveMinutes() {
                    if (selectedMinutes === 'custom') {
                        const val = parseInt(document.getElementById('custom-minutes-input').value, 10);
                        return (val && val > 0) ? val : null;
                    }
                    return selectedMinutes;
                }

                function clearAlerts() {
                    const err = document.getElementById('unlock-alert-error');
                    const succ = document.getElementById('unlock-alert-success');
                    if (err) err.style.display = 'none';
                    if (succ) succ.style.display = 'none';
                }

                function showAlert(msg, isSuccess) {
                    clearAlerts();
                    if (isSuccess) {
                        const succ = document.getElementById('unlock-alert-success');
                        succ.innerHTML = msg;
                        succ.style.display = 'block';
                    } else {
                        const err = document.getElementById('unlock-alert-error');
                        err.innerHTML = msg;
                        err.style.display = 'block';
                    }
                    initLucide();
                }

                function requestPartnerOTP() {
                    const mins = getEffectiveMinutes();
                    if (!mins) {
                        showAlert("Por favor ingresa una cantidad válida de minutos.", false);
                        return;
                    }

                    const btn = document.getElementById('btn-request-otp');
                    btn.innerHTML = `<i data-lucide="loader-2" class="lucide"></i> <span>Enviando correo al compañero...</span>`;
                    btn.disabled = true;
                    initLucide();

                    fetch(`/api/request-otp?site=${encodeURIComponent(targetSite)}&minutes=${mins}`, { method: 'POST' })
                        .then(res => res.json())
                        .then(data => {
                            if (data.success) {
                                showAlert(`Código enviado a <strong>${data.maskedEmail}</strong>. Pídele el código e ingrésalo a continuación:`, true);
                                btn.innerHTML = `<i data-lucide="send" class="lucide"></i> <span>Reenviar Código</span>`;
                                btn.disabled = false;
                                document.getElementById('otp-code-input').focus();
                            } else {
                                showAlert(data.error || "No se pudo enviar el correo.", false);
                                btn.innerHTML = `<i data-lucide="send" class="lucide"></i> <span>Enviar Código al Compañero</span>`;
                                btn.disabled = false;
                            }
                            initLucide();
                        })
                        .catch(() => {
                            showAlert("Error al comunicarse con el motor de FocusPanic.", false);
                            btn.innerHTML = `<i data-lucide="send" class="lucide"></i> <span>Enviar Código al Compañero</span>`;
                            btn.disabled = false;
                            initLucide();
                        });
                }

                function submitOTPUnlock() {
                    const code = document.getElementById('otp-code-input').value.trim();
                    if (!code) {
                        showAlert("Por favor ingresa el código de desbloqueo.", false);
                        return;
                    }

                    const mins = getEffectiveMinutes() || 15;
                    const btn = document.getElementById('btn-submit-otp');
                    btn.innerHTML = `<i data-lucide="loader-2" class="lucide"></i> <span>Verificando código...</span>`;
                    btn.disabled = true;
                    initLucide();

                    fetch(`/api/extend-limit?site=${encodeURIComponent(targetSite)}&minutes=${mins}&code=${encodeURIComponent(code)}`, { method: 'POST' })
                        .then(res => res.json())
                        .then(data => {
                            if (data.success) {
                                showAlert(`<strong>¡Acceso Autorizado!</strong> Tiempo extendido +${data.minutes} min. Redirigiendo...`, true);
                                setTimeout(() => {
                                    if (targetSite && targetSite !== "Sitio Distractor" && targetSite !== "bloqueo-total") {
                                        window.location.replace(`https://${targetSite}`);
                                    } else {
                                        window.location.replace("https://google.com");
                                    }
                                }, 1000);
                            } else {
                                showAlert(data.error || "Código incorrecto o expirado.", false);
                                btn.innerHTML = `<i data-lucide="lock-open" class="lucide"></i> <span>Desbloquear Sitio</span>`;
                                btn.disabled = false;
                                initLucide();
                            }
                        })
                        .catch(() => {
                            showAlert("Error de conexión con el motor de FocusPanic.", false);
                            btn.innerHTML = `<i data-lucide="lock-open" class="lucide"></i> <span>Desbloquear Sitio</span>`;
                            btn.disabled = false;
                            initLucide();
                        });
                }

                function closeThisTab() {
                    const btn = document.querySelector('.btn-primary');
                    if (btn) {
                        btn.innerHTML = `<i data-lucide="loader-2" class="lucide"></i> <span>Cerrando pestaña...</span>`;
                        btn.disabled = true;
                        btn.style.opacity = '0.7';
                        initLucide();
                    }
                    
                    fetch('/api/close-tab', { method: 'POST' })
                        .catch(() => {})
                        .finally(() => {
                            window.close();
                            setTimeout(() => {
                                window.location.replace('about:blank');
                            }, 150);
                        });
                }

                const quotes = [
                    { q: "El autocontrol no es privación, es elegir lo que más quieres a largo plazo sobre lo que quieres ahora mismo.", a: "Tu Cerebro en Control" },
                    { q: "Cada vez que resistes una distracción, estás fortaleciendo tu músculo de atención y disciplina.", a: "Racha & Enfoque" },
                    { q: "Tu atención es tu recurso más valioso. No lo regales por un golpe barato de dopamina.", a: "Productividad Radical" },
                    { q: "Respira hondo durante 10 segundos. Tu futuro yo te agradecerá haber continuado enfocado hoy.", a: "Victoria Personal" }
                ];
                const selected = quotes[Math.floor(Math.random() * quotes.length)];
                const quoteContainer = document.getElementById('quote-container');
                if (quoteContainer) {
                    quoteContainer.innerHTML = `"${selected.q}"<span class="quote-author">${selected.a}</span>`;
                }

                // Iniciar Lucide tras cargar página
                window.addEventListener('load', initLucide);
            </script>
        </body>
        </html>
        """
    }
}
