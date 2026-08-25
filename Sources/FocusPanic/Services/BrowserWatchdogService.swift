import AppKit
import Foundation

public final class BrowserWatchdogService {
    public static let shared = BrowserWatchdogService()
    
    private var timer: Timer?
    private var isRunning = false
    private var blockedDomains: [String] = []
    private var allowedDomains: [String] = []
    private var isWhitelistMode = false
    private var lastInterceptionTime: Date = Date.distantPast
    
    private init() {}
    
    public func start(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        isWhitelistMode: Bool = false
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
        
        stop()
        isRunning = true
        
        // Interceptación instantánea al iniciar
        checkAndInterceptTabs()
        
        DispatchQueue.main.async {
            // Revisar cada 1 segundo para respuesta inmediata
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkAndInterceptTabs()
            }
        }
    }
    
    public func updateRules(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        isWhitelistMode: Bool = false
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    public func checkAndInterceptTabs() {
        guard isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let runningApps = NSWorkspace.shared.runningApplications
            let isSafariRunning = runningApps.contains { $0.bundleIdentifier == "com.apple.Safari" }
            
            guard isSafariRunning else { return }
            
            if self.isWhitelistMode {
                self.enforceWhitelistInSafari()
            } else {
                self.enforceBlacklistInSafari()
            }
        }
    }
    
    // MARK: - Modo Lista Negra (Bloqueo Selectivo)
    private func enforceBlacklistInSafari() {
        guard !blockedDomains.isEmpty else { return }
        
        // 1. Dominios permitidos explícitos (la lista blanca siempre tiene prioridad)
        var allAllowed = Set(self.allowedDomains.map { $0.replacingOccurrences(of: "www.", with: "").lowercased() })
        allAllowed.formUnion(AppSettings.systemEssentialDomains)
        
        let allowedListFormatted = allAllowed
            .filter { !$0.isEmpty }
            .map { "\"\($0)\"" }
            .joined(separator: ", ")
        
        // 2. Dominios a bloquear
        var exactDomainsToBlock: Set<String> = []
        for domain in self.blockedDomains {
            let clean = domain.replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !clean.isEmpty && !clean.hasPrefix("#") else { continue }
            
            // Si el dominio completo está en la lista blanca, no bloquearlo
            if !allAllowed.contains(clean) {
                exactDomainsToBlock.insert(clean)
            }
        }
        
        let domainListFormatted = exactDomainsToBlock
            .map { "\"\($0)\"" }
            .joined(separator: ", ")
        
        let safariScript = """
        set allowedList to {\(allowedListFormatted)}
        set blockedList to {\(domainListFormatted)}
        set blockedFound to ""
        
        tell application "Safari"
            try
                repeat with w in windows
                repeat with t in tabs of w
                    set currentURL to URL of t
                    if currentURL is not missing value and currentURL is not "" and currentURL does not start with "about:" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" then
                        -- Verificar primero si es un subdominio o sitio en Lista Blanca
                        set isAllowed to false
                        repeat with allowed in allowedList
                            if currentURL contains allowed then
                                set isAllowed to true
                                exit repeat
                            end if
                        end repeat
                        
                        -- Solo si NO está en Lista Blanca, verificar bloqueo
                        if isAllowed is false then
                            repeat with blocked in blockedList
                                if currentURL contains blocked then
                                    set URL of t to ("http://127.0.0.1:8484/?site=" & blocked)
                                    set blockedFound to blocked
                                    exit repeat
                                end if
                            end repeat
                        end if
                    end if
                end repeat
            end repeat
        end try
    end tell
    return blockedFound
    """
    
    var error: NSDictionary?
    if let script = NSAppleScript(source: safariScript) {
        let result = script.executeAndReturnError(&error)
        let blockedDomain = result.stringValue ?? ""
        if !blockedDomain.isEmpty {
            notifyInterception(domain: blockedDomain, isWhitelist: false)
        }
    }
}

private func sanitizeForAppleScript(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\r", with: "")
        .replacingOccurrences(of: "\n", with: "")
}

// MARK: - Modo Bloqueo Total (Solo Lista Blanca)
private func enforceWhitelistInSafari() {
    var allAllowed = Set(self.allowedDomains.map { sanitizeForAppleScript($0.replacingOccurrences(of: "www.", with: "")) })
    allAllowed.formUnion(AppSettings.systemEssentialDomains.map { sanitizeForAppleScript($0) })
    
    let allowedListFormatted = allAllowed
        .filter { !$0.isEmpty }
        .map { "\"\($0)\"" }
        .joined(separator: ", ")
        
        let safariScript = """
        set allowedList to {\(allowedListFormatted)}
        set blockedFound to ""
        
        tell application "Safari"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set currentURL to URL of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "about:" and currentURL does not start with "file:" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" and currentURL does not start with "http://localhost" and currentURL does not start with "http://127.0.0.1" then
                            set isAllowed to false
                            repeat with allowed in allowedList
                                if currentURL contains allowed then
                                    set isAllowed to true
                                    exit repeat
                                end if
                            end repeat
                            
                            if isAllowed is false then
                                set blockedFound to currentURL
                                set URL of t to "http://127.0.0.1:8484/?site=bloqueo-total"
                            end if
                        end if
                    end repeat
                end repeat
            end try
        end tell
        return blockedFound
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: safariScript) {
            let result = script.executeAndReturnError(&error)
            let rawUrl = result.stringValue ?? ""
            if !rawUrl.isEmpty {
                let domain = URL(string: rawUrl)?.host ?? rawUrl
                notifyInterception(domain: domain, isWhitelist: true)
            }
        }
    }
    
    private func notifyInterception(domain: String, isWhitelist: Bool) {
        if Date().timeIntervalSince(lastInterceptionTime) > 3.0 {
            lastInterceptionTime = Date()
            let title = isWhitelist ? "🛡️ Sitio No Permitido (Modo Total)" : "🛡️ Distracción Bloqueada"
            let body = isWhitelist
                ? "FocusPanic cerró el acceso. '\(domain)' no está en tu Lista Blanca."
                : "FocusPanic cerró el acceso a '\(domain)'."
            
            NotificationService.shared.sendNotification(
                title: title,
                body: body,
                sound: "Basso"
            )
        }
    }
}
