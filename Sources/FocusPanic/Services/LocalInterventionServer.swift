import Foundation
import Network

public final class LocalInterventionServer {
    public static let shared = LocalInterventionServer()
    
    private var listener: NWListener?
    private let port: UInt16 = 8484
    private var isRunning = false
    
    private var appIconBase64: String = ""
    
    private init() {
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: iconPath)) {
            self.appIconBase64 = data.base64EncodedString()
        }
    }
    
    public func start() {
        guard !isRunning else { return }
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            self.listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    self.isRunning = true
                    print("🧘 [FocusPanic] Servidor de intervención activo y seguro en http://127.0.0.1:\(self.port)")
                case .failed(let error):
                    print("⚠️ [FocusPanic] Servidor de intervención error: \(error)")
                    self.isRunning = false
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("⚠️ No se pudo iniciar el servidor local: \(error)")
        }
    }
    
    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
    }
    
    private func htmlEscape(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self = self else { return }
            
            var requestedHost = "Sitio Distractor"
            if let data = data, let requestStr = String(data: data, encoding: .utf8) {
                if let firstLine = requestStr.components(separatedBy: "\r\n").first {
                    if let range = firstLine.range(of: "site=") {
                        let sub = String(firstLine[range.upperBound...])
                        let siteName = sub.components(separatedBy: " ").first?.components(separatedBy: "&").first ?? ""
                        if !siteName.isEmpty {
                            requestedHost = self.htmlEscape(siteName.removingPercentEncoding ?? siteName)
                        }
                    }
                }
                
                if requestedHost == "Sitio Distractor" {
                    let lines = requestStr.components(separatedBy: "\r\n")
                    for line in lines {
                        if line.lowercased().hasPrefix("host:") {
                            let host = line.replacingOccurrences(of: "Host: ", with: "")
                                .replacingOccurrences(of: "host: ", with: "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .components(separatedBy: ":").first ?? ""
                            if !host.isEmpty && host != "127.0.0.1" && host != "localhost" {
                                requestedHost = self.htmlEscape(host)
                            }
                            break
                        }
                    }
                }
            }
            
            let html = self.generateBlockPageHTML(blockedHost: requestedHost)
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\nCache-Control: no-cache, no-store, must-revalidate\r\n\r\n\(html)"
            
            if let responseData = response.data(using: .utf8) {
                connection.send(content: responseData, completion: .contentProcessed({ _ in
                    connection.cancel()
                }))
            }
        }
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
                    padding: 44px 40px;
                    max-width: 560px;
                    width: 100%;
                    text-align: center;
                    box-shadow: 0 35px 80px -15px rgba(0, 0, 0, 0.8), 0 0 50px -10px rgba(244, 63, 94, 0.2);
                    animation: popIn 0.5s cubic-bezier(0.16, 1, 0.3, 1);
                }
                @keyframes popIn {
                    from { opacity: 0; transform: scale(0.92) translateY(24px); }
                    to { opacity: 1; transform: scale(1) translateY(0); }
                }

                .app-icon-wrapper {
                    position: relative;
                    width: 90px;
                    height: 90px;
                    margin: 0 auto 20px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                .app-icon-img {
                    width: 82px;
                    height: 82px;
                    border-radius: 20px;
                    box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6), 0 0 30px rgba(244, 63, 94, 0.4);
                    position: relative;
                    z-index: 2;
                }
                .fallback-icon {
                    font-size: 48px;
                    position: relative;
                    z-index: 2;
                }
                .icon-glow-ring {
                    position: absolute;
                    width: 100%;
                    height: 100%;
                    border-radius: 24px;
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
                    padding: 6px 16px;
                    border-radius: 999px;
                    font-size: 11px;
                    font-weight: 800;
                    letter-spacing: 1px;
                    text-transform: uppercase;
                    margin-bottom: 18px;
                }
                h1 {
                    font-size: 30px;
                    font-weight: 800;
                    letter-spacing: -0.5px;
                    margin-bottom: 8px;
                    background: linear-gradient(135deg, #ffffff 0%, #cbd5e1 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                }
                .site-pill {
                    display: inline-block;
                    background: rgba(244, 63, 94, 0.12);
                    border: 1px solid rgba(244, 63, 94, 0.35);
                    color: #fda4af;
                    font-family: "SF Mono", Menlo, monospace;
                    font-size: 15px;
                    font-weight: 700;
                    padding: 5px 16px;
                    border-radius: 8px;
                    margin-bottom: 16px;
                }
                p.lead {
                    color: #94a3b8;
                    font-size: 15px;
                    line-height: 1.5;
                    margin-bottom: 24px;
                }
                .breathing-box {
                    position: relative;
                    width: 110px;
                    height: 110px;
                    margin: 0 auto 24px;
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
                    font-size: 12px;
                    font-weight: 800;
                    letter-spacing: 1.5px;
                    color: #e2e8f0;
                    text-transform: uppercase;
                }
                @keyframes orbBreath {
                    0%, 100% { transform: scale(0.7); opacity: 0.5; }
                    50% { transform: scale(1.15); opacity: 1; box-shadow: 0 0 40px rgba(168, 85, 247, 0.6); }
                }
                .rule-box {
                    background: rgba(0, 0, 0, 0.35);
                    border-left: 4px solid var(--primary);
                    padding: 14px 18px;
                    border-radius: 0 12px 12px 0;
                    text-align: left;
                    font-size: 13.5px;
                    line-height: 1.5;
                    color: #cbd5e1;
                    margin-bottom: 20px;
                }
                .rule-box strong {
                    color: #ffffff;
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
                <div class="badge">⛔ ACCESO INTERCEPTADO</div>
                <h1>Pausa Consciente</h1>
                <div class="site-pill">\(blockedHost)</div>
                
                <p class="lead">
                    Tu cerebro buscaba dopamina rápida por impulso.<br>
                    FocusPanic detuvo este acceso para proteger tu meta y tu atención.
                </p>

                <div class="breathing-box">
                    <div class="breathing-orb"></div>
                    <span class="breathing-title">Respira</span>
                </div>

                <div class="rule-box">
                    <strong>Regla de los 30 segundos:</strong><br>
                    Haz una respiración profunda, cierra esta pestaña y pregúntate:<br>
                    <em>"¿Qué tarea importante me propuse terminar hoy?"</em>
                </div>

                <div class="footer-text">
                    <strong>FocusPanic</strong> está activo en tu Mac. El acceso se restaurará al completar tu sesión de enfoque.
                </div>
            </div>
        </body>
        </html>
        """
    }
}
