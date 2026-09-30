import AppKit
import ApplicationServices
import Foundation

public final class WhatsAppStatusWatcherService {
    public static let shared = WhatsAppStatusWatcherService()
    
    private var timer: Timer?
    private var isRunning = false
    private var isStatusEnabled = true
    private var isChannelsEnabled = true
    private var lastInterceptionTime: Date = Date.distantPast
    private let watcherQueue = DispatchQueue(label: "com.hector.FocusPanic.whatsAppWatcher", qos: .userInteractive)
    private var isChecking = false
    
    private init() {}
    
    public func start(isStatusEnabled: Bool = true, isChannelsEnabled: Bool = true) {
        self.isStatusEnabled = isStatusEnabled
        self.isChannelsEnabled = isChannelsEnabled
        stop()
        
        guard isStatusEnabled || isChannelsEnabled else { return }
        isRunning = true
        
        DispatchQueue.main.async {
            let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
                self?.checkWhatsAppActivity()
            }
            RunLoop.main.add(t, forMode: .common)
            self.timer = t
        }
    }
    
    public func updateState(isStatusEnabled: Bool, isChannelsEnabled: Bool) {
        self.isStatusEnabled = isStatusEnabled
        self.isChannelsEnabled = isChannelsEnabled
        if !isStatusEnabled && !isChannelsEnabled {
            stop()
        } else if !isRunning {
            start(isStatusEnabled: isStatusEnabled, isChannelsEnabled: isChannelsEnabled)
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isChecking = false
    }
    
    private func checkWhatsAppActivity() {
        guard isRunning && (isStatusEnabled || isChannelsEnabled) else { return }
        
        watcherQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Candado de exclusión mutua para evitar apilamiento de hilos
            if self.isChecking { return }
            self.isChecking = true
            defer { self.isChecking = false }
            
            // 1. Buscar WhatsApp entre las aplicaciones activas
            guard let app = NSWorkspace.shared.runningApplications.first(where: {
                let bundle = $0.bundleIdentifier?.lowercased() ?? ""
                let name = $0.localizedName?.lowercased() ?? ""
                return bundle == "net.whatsapp.whatsapp" || bundle.contains("whatsapp") || name.contains("whatsapp")
            }) else { return }
            
            let pid = app.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var windowsValue: AnyObject?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windows = windowsValue as? [AXUIElement], !windows.isEmpty else {
                return
            }
            
            for window in windows {
                let texts = self.extractAccessibilityTexts(window, maxDepth: 7)
                let combinedText = texts.joined(separator: " ").lowercased()
                
                // 1. Si el usuario está en el diálogo modal de REENVIAR mensaje, ignorar para permitir reenviar libremente
                let isForwarding = combinedText.contains("reenviar") ||
                                   combinedText.contains("forward") ||
                                   combinedText.contains("reenviar mensaje") ||
                                   combinedText.contains("forward message") ||
                                   combinedText.contains("reenviar a") ||
                                   combinedText.contains("forward to") ||
                                   combinedText.contains("selecciona un chat") ||
                                   combinedText.contains("contactos frecuentes") ||
                                   combinedText.contains("frequent contacts") ||
                                   combinedText.contains("chats recientes") ||
                                   combinedText.contains("recent chats") ||
                                   combinedText.contains("compartir con") ||
                                   combinedText.contains("share with")
                
                if isForwarding {
                    continue
                }
                
                // 2. Detección directa y universal de Estados / Historias
                let isViewingEstados = combinedText.contains("añadir estado") ||
                                       combinedText.contains("haz clic para ver su estado") ||
                                       combinedText.contains("viewed updates") ||
                                       combinedText.contains("actualizaciones vistas") ||
                                       combinedText.contains("estados recientes") ||
                                       combinedText.contains("recent updates") ||
                                       combinedText.contains("estados silenciados") ||
                                       combinedText.contains("muted updates") ||
                                       (combinedText.contains("estados") && !combinedText.contains("escribe un mensaje") && !combinedText.contains("tipo de mensaje") && !combinedText.contains("buscar en el chat"))
                
                // 3. Detección directa de Canales
                let isViewingCanales = combinedText.contains("find channels") ||
                                       combinedText.contains("buscar canales") ||
                                       combinedText.contains("seguir canal") ||
                                       combinedText.contains("channels to follow") ||
                                       combinedText.contains("canales seguidos") ||
                                       combinedText.contains("directorio de canales")
                
                if self.isChannelsEnabled && isViewingCanales && !isViewingEstados {
                    DispatchQueue.main.async {
                        self.triggerIntervention(mode: .channels, appElement: appElement)
                    }
                    return
                }
                
                if self.isStatusEnabled && (isViewingEstados || isViewingCanales) {
                    DispatchQueue.main.async {
                        self.triggerIntervention(mode: .status, appElement: appElement)
                    }
                    return
                }
            }
        }
    }
    
    private func extractAccessibilityTexts(_ element: AXUIElement, maxDepth: Int, currentDepth: Int = 0) -> [String] {
        guard currentDepth < maxDepth else { return [] }
        var list: [String] = []
        
        var role: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? ""
        
        var desc: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc)
        
        var title: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        
        var val: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &val)
        
        let textPart = "\(title ?? "" as AnyObject) \(desc ?? "" as AnyObject) \(val ?? "" as AnyObject)"
            .replacingOccurrences(of: "\u{200E}", with: "") // Limpiar caracteres invisibles de WhatsApp
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !textPart.isEmpty && textPart != "missing value" {
            list.append("[\(roleStr)] \(textPart)")
        }
        
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let childList = children as? [AXUIElement] {
            // Limitar a máximo 25 hijos por nodo para evitar listas infinitas
            for child in childList.prefix(25) {
                list.append(contentsOf: extractAccessibilityTexts(child, maxDepth: maxDepth, currentDepth: currentDepth + 1))
            }
        }
        return list
    }
    
    @MainActor
    private func triggerIntervention(mode: WhatsAppBlockMode, appElement: AXUIElement) {
        // 1. Forzar regreso inmediato a Chats en WhatsApp usando la barra de menú nativa
        returnToChats(appElement: appElement)
        
        guard Date().timeIntervalSince(lastInterceptionTime) > 1.5 else { return }
        lastInterceptionTime = Date()
        
        // 2. Mostrar popup nativo HUD centrado en pantalla
        WhatsAppStatusInterventionWindow.shared.show(mode: mode)
        
        // 3. Registrar en las estadísticas de FocusPanic
        let sourceName = (mode == .status) ? "WhatsApp Estados" : "WhatsApp Canales"
        let detailName = (mode == .status) ? "Visualización de historias/estados bloqueada" : "Directorio de canales bloqueado"
        FocusStatsManager.shared.recordInterception(
            source: sourceName,
            category: "social",
            detail: detailName
        )
    }
    
    /// Regresa la interfaz de WhatsApp a los chats seguros de inmediato ejecutando el menú nativo
    public func returnToChats(appElement: AXUIElement? = nil) {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            // Obtener el appElement de WhatsApp si no fue provisto
            let targetApp: AXUIElement
            if let element = appElement {
                targetApp = element
            } else {
                guard let app = NSWorkspace.shared.runningApplications.first(where: {
                    let bundle = $0.bundleIdentifier?.lowercased() ?? ""
                    let name = $0.localizedName?.lowercased() ?? ""
                    return bundle == "net.whatsapp.whatsapp" || bundle.contains("whatsapp") || name.contains("whatsapp")
                }) else { return }
                targetApp = AXUIElementCreateApplication(app.processIdentifier)
            }
            
            // 1. Activar el ítem de menú nativo "Visualización -> Chats" (infalible en macOS)
            var menuBarValue: AnyObject?
            if AXUIElementCopyAttributeValue(targetApp, kAXMenuBarAttribute as CFString, &menuBarValue) == .success,
               let menuBar = menuBarValue {
                _ = self.triggerChatsMenuItem(menuBar as! AXUIElement)
            }
            
            // 2. Enviar tecla Escape para cerrar historias en pantalla completa si están abiertas
            let script = """
            tell application "System Events"
                if exists (process "WhatsApp") then
                    tell process "WhatsApp"
                        try
                            key code 53 -- Escape
                        end try
                    end tell
                end if
            end tell
            """
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
        }
    }
    
    private func triggerChatsMenuItem(_ element: AXUIElement) -> Bool {
        var title: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        let t = ((title as? String) ?? "")
            .replacingOccurrences(of: "\u{200E}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if t == "chats" || t == "conversaciones" {
            let res = AXUIElementPerformAction(element, kAXPressAction as CFString)
            if res == .success {
                return true
            }
        }
        
        var children: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
           let list = children as? [AXUIElement] {
            for c in list {
                if triggerChatsMenuItem(c) { return true }
            }
        }
        return false
    }
    
    /// Envía la tecla Escape a WhatsApp para cerrar automáticamente el visor de historias
    public func sendEscapeToWhatsApp() {
        returnToChats()
    }
}
