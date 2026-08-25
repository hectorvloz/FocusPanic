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
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: iconPath)) {
            self.appIconBase64 = data.base64EncodedString()
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        
        serverQueue.async { [weak self] in
            guard let self = self else { return }
            
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
                print("⚠️ [FocusPanic] No se pudo enlazar al puerto \(self.port)")
                close(self.serverSocket)
                self.serverSocket = -1
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
    
    private func acceptIncomingConnection() {
        var clientAddr = sockaddr_in()
        var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(self.serverSocket, $0, &clientLen)
            }
        }
        
        guard clientSocket >= 0 else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
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
            
            // Endpoint para cerrar la pestaña activa nativamente en el navegador
            if requestStr.contains("/api/close-tab") || requestStr.contains("/close-tab") {
                self.closeFrontmostBrowserTab()
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=UTF-8\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n{\"status\":\"closed\"}"
                _ = response.withCString { ptr in
                    write(clientSocket, ptr, strlen(ptr))
                }
                close(clientSocket)
                return
            }
            
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
            
            _ = fullResponse.withCString { ptr in
                write(clientSocket, ptr, strlen(ptr))
            }
            
            close(clientSocket)
        }
    }
    
    /// Cierra de forma nativa la pestaña activa en cualquier navegador soportado
    public func closeFrontmostBrowserTab() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let runningApps = NSWorkspace.shared.runningApplications
            let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
            
            // Probar en orden según el navegador que esté abierto
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
                <div class="fallback-icon">🛡️</div>
                <div class="icon-glow-ring"></div>
            </div>
            """
        }

        return """
        <!DOCTYPE html>
        <html lang="es">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta name="color-scheme" content="dark">
            <meta name="theme-color" content="#07090E">
            <title>🛡️ FocusPanic - Acceso Bloqueado</title>
            <style>
                :root {
                    color-scheme: dark !important;
                    --bg-gradient: radial-gradient(circle at 50% 30%, #1e0b23 0%, #0d0e1c 55%, #05060c 100%);
                    --card-bg: rgba(15, 17, 28, 0.92);
                    --card-border: rgba(244, 63, 94, 0.35);
                    --primary: #f43f5e;
                    --purple: #a855f7;
                    --cyan: #38bdf8;
                }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                html {
                    background-color: #07090E !important;
                    color-scheme: dark !important;
                    width: 100%;
                    height: 100%;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", Roboto, sans-serif;
                    background: var(--bg-gradient) !important;
                    background-color: #07090E !important;
                    color-scheme: dark !important;
                    color: #f8fafc !important;
                    min-height: 100vh;
                    width: 100vw;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    padding: 24px;
                    overflow: hidden;
                    position: relative;
                }
                
                /* GIGANTIC GLOWING WATERMARK X IN BACKGROUND */
                .bg-watermark-x {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%) scale(1.1);
                    font-size: 85vh;
                    font-weight: 900;
                    line-height: 0.8;
                    color: rgba(244, 63, 94, 0.08);
                    text-shadow: 0 0 140px rgba(244, 63, 94, 0.3), 0 0 50px rgba(168, 85, 247, 0.25);
                    pointer-events: none;
                    z-index: 0;
                    user-select: none;
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    animation: watermarkPulse 6s ease-in-out infinite;
                }
                @keyframes watermarkPulse {
                    0%, 100% { opacity: 0.7; transform: translate(-50%, -50%) scale(1.05); }
                    50% { opacity: 1; transform: translate(-50%, -50%) scale(1.12); }
                }

                .card {
                    position: relative;
                    z-index: 1;
                    background: var(--card-bg);
                    backdrop-filter: blur(36px);
                    -webkit-backdrop-filter: blur(36px);
                    border: 1px solid var(--card-border);
                    border-radius: 32px;
                    padding: 40px 38px;
                    max-width: 560px;
                    width: 100%;
                    text-align: center;
                    box-shadow: 0 35px 80px -15px rgba(0, 0, 0, 0.8), 0 0 50px -10px rgba(244, 63, 94, 0.2);
                    animation: popIn 0.45s cubic-bezier(0.16, 1, 0.3, 1);
                }
                @keyframes popIn {
                    from { opacity: 0; transform: scale(0.92) translateY(24px); }
                    to { opacity: 1; transform: scale(1) translateY(0); }
                }

                .app-icon-wrapper {
                    position: relative;
                    width: 86px;
                    height: 86px;
                    margin: 0 auto 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .app-icon-img {
                    width: 78px;
                    height: 78px;
                    border-radius: 18px;
                    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6), 0 0 30px rgba(244, 63, 94, 0.4);
                    position: relative;
                    z-index: 2;
                }
                .fallback-icon {
                    font-size: 44px;
                    position: relative;
                    z-index: 2;
                }
                .icon-glow-ring {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    border-radius: 22px;
                    background: linear-gradient(135deg, rgba(244, 63, 94, 0.6), rgba(168, 85, 247, 0.4));
                    filter: blur(14px);
                    z-index: 1;
                    animation: glowPulse 3s infinite ease-in-out;
                }
                @keyframes glowPulse {
                    0%, 100% { transform: scale(0.95); opacity: 0.6; }
                    50% { transform: scale(1.15); opacity: 0.9; }
                }

                .badge {
                    display: inline-flex;
                    align-items: center;
                    gap: 8px;
                    background: rgba(244, 63, 94, 0.15);
                    color: #fb7185;
                    border: 1px solid rgba(244, 63, 94, 0.35);
                    padding: 5px 14px;
                    border-radius: 999px;
                    font-size: 11px;
                    font-weight: 800;
                    letter-spacing: 1px;
                    text-transform: uppercase;
                    margin-bottom: 14px;
                }
                h1 {
                    font-size: 28px;
                    font-weight: 800;
                    letter-spacing: -0.5px;
                    margin-bottom: 8px;
                    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }
                .site-pill {
                    display: inline-block;
                    background: rgba(244, 63, 94, 0.15);
                    border: 1px solid rgba(244, 63, 94, 0.4);
                    color: #fda4af;
                    font-family: "SF Mono", Menlo, monospace;
                    font-size: 15px;
                    font-weight: 700;
                    padding: 6px 18px;
                    border-radius: 8px;
                    margin-bottom: 14px;
                }
                
                .quote-box {
                    background: linear-gradient(135deg, rgba(244, 63, 94, 0.12), rgba(168, 85, 247, 0.12));
                    border: 1px solid rgba(244, 63, 94, 0.25);
                    border-radius: 14px;
                    padding: 14px 18px;
                    margin-bottom: 18px;
                    font-style: italic;
                    color: #e2e8f0;
                    font-size: 14px;
                    line-height: 1.45;
                }
                .quote-author {
                    display: block;
                    margin-top: 6px;
                    font-style: normal;
                    font-weight: 700;
                    font-size: 11px;
                    color: #fb7185;
                    text-transform: uppercase;
                    letter-spacing: 0.5px;
                }

                .breathing-box {
                    position: relative;
                    width: 90px;
                    height: 90px;
                    margin: 0 auto 16px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .breathing-orb {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    border-radius: 50%;
                    background: radial-gradient(circle, rgba(168, 85, 247, 0.45) 0%, rgba(244, 63, 94, 0.15) 70%);
                    border: 2px solid rgba(168, 85, 247, 0.5);
                    animation: orbBreath 6s infinite ease-in-out;
                }
                .breathing-title {
                    position: relative;
                    font-size: 11px;
                    font-weight: 800;
                    letter-spacing: 1.5px;
                    color: #e2e8f0;
                    text-transform: uppercase;
                }
                @keyframes orbBreath {
                    0%, 100% { transform: scale(0.75); opacity: 0.5; }
                    50% { transform: scale(1.12); opacity: 1; box-shadow: 0 0 35px rgba(168, 85, 247, 0.6); }
                }

                .btn-close-tab {
                    display: inline-block;
                    background: linear-gradient(135deg, #f43f5e 0%, #e11d48 100%);
                    color: #ffffff;
                    text-decoration: none;
                    font-weight: 700;
                    font-size: 14px;
                    padding: 11px 26px;
                    border-radius: 12px;
                    border: none;
                    cursor: pointer;
                    box-shadow: 0 4px 15px rgba(244, 63, 94, 0.4);
                    transition: transform 0.15s ease, box-shadow 0.15s ease;
                    margin-bottom: 14px;
                }
                .btn-close-tab:hover {
                    transform: scale(1.03);
                    box-shadow: 0 6px 20px rgba(244, 63, 94, 0.6);
                }

                .footer-text {
                    font-size: 12px;
                    color: #64748b;
                    letter-spacing: 0.3px;
                }
                .footer-text strong {
                    color: #f43f5e;
                }
            </style>
        </head>
        <body>
            <div class="bg-watermark-x">✕</div>
            <div class="card">
                \(iconHtml)
                <div class="badge">🛡️ ACCESO BLOQUEADO POR FOCUSPANIC</div>
                <h1>Pausa Consciente</h1>
                <div class="site-pill">⛔ \(blockedHost)</div>
                
                <div class="quote-box">
                    "El autocontrol no es privación, es elegir lo que más quieres a largo plazo sobre lo que quieres ahora mismo."
                    <span class="quote-author">🧠 Tu Cerebro en Control</span>
                </div>

                <div class="breathing-box">
                    <div class="breathing-orb"></div>
                    <span class="breathing-title">Respira</span>
                </div>

                <button class="btn-close-tab" onclick="closeThisTab();">
                    ✓ Cerrar Pestaña y Volver al Enfoque
                </button>

                <div class="footer-text">
                    <strong>FocusPanic</strong> está activo en tu Mac protegiendo tu atención y racha diaria.
                </div>
            </div>
            
            <script>
                function closeThisTab() {
                    const btn = document.querySelector('.btn-close-tab');
                    if (btn) {
                        btn.innerText = "⏳ Cerrando pestaña...";
                        btn.disabled = true;
                        btn.style.opacity = '0.7';
                    }
                    
                    // 1. Invocar el endpoint nativo de FocusPanic para cerrar la pestaña en el sistema
                    fetch('/api/close-tab', { method: 'POST' })
                        .catch(() => {})
                        .finally(() => {
                            window.close();
                            // Fallback de seguridad: si el navegador impide window.close, ir a pantalla limpia
                            setTimeout(() => {
                                window.location.replace('about:blank');
                            }, 150);
                        });
                }

                // Frases motivacionales rotativas
                const quotes = [
                    { q: "El autocontrol no es privación, es elegir lo que más quieres a largo plazo sobre lo que quieres ahora mismo.", a: "🧠 Tu Cerebro en Control" },
                    { q: "Cada vez que resistes una distracción, estás fortaleciendo tu músculo de atención y disciplina.", a: "🔥 Racha & Enfoque" },
                    { q: "Tu atención es tu recurso más valioso. No lo regales por un golpe barato de dopamina.", a: "⚡ Productividad Radical" },
                    { q: "Respira hondo durante 10 segundos. Tu futuro yo te agradecerá haber continuado enfocado hoy.", a: "🌱 Victoria Personal" }
                ];
                const selected = quotes[Math.floor(Math.random() * quotes.length)];
                document.querySelector('.quote-box').innerHTML = `"${selected.q}"<span class="quote-author">${selected.a}</span>`;
            </script>
        </body>
        </html>
        """
    }
}
