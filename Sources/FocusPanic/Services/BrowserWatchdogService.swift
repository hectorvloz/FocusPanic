import AppKit
import Foundation

public final class BrowserWatchdogService {
    public static let shared = BrowserWatchdogService()
    
    private var timer: Timer?
    private var isRunning = false
    private var blockedDomains: [String] = []
    private var allowedDomains: [String] = []
    private var blockedKeywords: [String] = []
    private var isWhitelistMode = false
    private var isAntiIncognitoEnabled = true
    private var isKeywordBlockerEnabled = true
    
    private var lastInterceptionTime: Date = Date.distantPast
    private var lastIncognitoNotificationTime: Date = Date.distantPast
    
    private init() {}
    
    public func start(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        blockedKeywords: [String] = AppSettings.defaultBlockedKeywords,
        isWhitelistMode: Bool = false,
        isAntiIncognitoEnabled: Bool = true,
        isKeywordBlockerEnabled: Bool = true
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.blockedKeywords = blockedKeywords.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
        self.isAntiIncognitoEnabled = isAntiIncognitoEnabled
        self.isKeywordBlockerEnabled = isKeywordBlockerEnabled
        
        stop()
        isRunning = true
        
        // Interceptación instantánea al iniciar
        checkAndInterceptTabs()
        
        DispatchQueue.main.async {
            // Monitoreo continuo cada 1.0 segundos
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.checkAndInterceptTabs()
            }
        }
    }
    
    public func updateRules(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        blockedKeywords: [String] = [],
        isWhitelistMode: Bool = false,
        isAntiIncognitoEnabled: Bool = true,
        isKeywordBlockerEnabled: Bool = true
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.blockedKeywords = blockedKeywords.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
        self.isAntiIncognitoEnabled = isAntiIncognitoEnabled
        self.isKeywordBlockerEnabled = isKeywordBlockerEnabled
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
            let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
            
            // 1. Escudo Anti-Modo Incógnito / Ventanas Privadas
            if self.isAntiIncognitoEnabled {
                self.enforceAntiIncognito(runningBundleIds: runningBundleIds)
            }
            
            // 2. Monitoreo e Interceptación de Pestañas (Dominios, Lista Blanca y Palabras Clave)
            if runningBundleIds.contains("com.apple.Safari") {
                if self.isWhitelistMode {
                    self.enforceWhitelistInSafari()
                } else {
                    self.enforceRulesInSafari()
                }
            }
            
            if runningBundleIds.contains("com.google.Chrome") {
                self.enforceRulesInChromium(appName: "Google Chrome")
            }
            if runningBundleIds.contains("com.brave.Browser") {
                self.enforceRulesInChromium(appName: "Brave Browser")
            }
            if runningBundleIds.contains("com.microsoft.edgemac") {
                self.enforceRulesInChromium(appName: "Microsoft Edge")
            }
            if runningBundleIds.contains("com.operasoftware.Opera") {
                self.enforceRulesInChromium(appName: "Opera")
            }
            if runningBundleIds.contains("com.vivaldi.Vivaldi") {
                self.enforceRulesInChromium(appName: "Vivaldi")
            }
            if runningBundleIds.contains("company.thebrowser.Arc") {
                self.enforceRulesInChromium(appName: "Arc")
            }
        }
    }
    
    // MARK: - 1. Escudo Anti-Incógnito Multi-Navegador
    
    private func enforceAntiIncognito(runningBundleIds: Set<String>) {
        var closedAny = false
        
        // Safari Private Browsing
        if runningBundleIds.contains("com.apple.Safari") {
            let safariIncogScript = """
            tell application "Safari"
                try
                    set closedCount to 0
                    repeat with w in windows
                        try
                            if («class pmnd» of w) is true then
                                close w
                                set closedCount to closedCount + 1
                            end if
                        end try
                    end repeat
                    return closedCount
                end try
            end tell
            return 0
            """
            if let script = NSAppleScript(source: safariIncogScript) {
                var error: NSDictionary?
                let res = script.executeAndReturnError(&error)
                if (res.int32Value) > 0 { closedAny = true }
            }
        }
        
        // Google Chrome Incognito
        if runningBundleIds.contains("com.google.Chrome") {
            if closeChromiumIncognito(appName: "Google Chrome") { closedAny = true }
        }
        
        // Brave Browser Incognito
        if runningBundleIds.contains("com.brave.Browser") {
            if closeChromiumIncognito(appName: "Brave Browser") { closedAny = true }
        }
        
        // Microsoft Edge InPrivate
        if runningBundleIds.contains("com.microsoft.edgemac") {
            if closeChromiumIncognito(appName: "Microsoft Edge") { closedAny = true }
        }
        
        // Arc Incognito
        if runningBundleIds.contains("company.thebrowser.Arc") {
            if closeChromiumIncognito(appName: "Arc") { closedAny = true }
        }
        
        // Opera Private Window
        if runningBundleIds.contains("com.operasoftware.Opera") {
            if closeChromiumIncognito(appName: "Opera") { closedAny = true }
        }
        
        // Vivaldi Private Window
        if runningBundleIds.contains("com.vivaldi.Vivaldi") {
            if closeChromiumIncognito(appName: "Vivaldi") { closedAny = true }
        }
        
        if closedAny {
            notifyIncognitoBlocked()
        }
    }
    
    private func closeChromiumIncognito(appName: String) -> Bool {
        let scriptSource = """
        tell application "\(appName)"
            try
                set incogWindows to (every window whose mode is "incognito")
                set c to count of incogWindows
                if c > 0 then
                    repeat with w in incogWindows
                        close w
                    end repeat
                    return c
                end if
            end try
        end tell
        return 0
        """
        if let script = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            let res = script.executeAndReturnError(&error)
            return (res.int32Value) > 0
        }
        return false
    }
    
    private func notifyIncognitoBlocked() {
        FocusStatsManager.shared.recordInterception(
            source: "Modo Incógnito",
            category: "incognito",
            detail: "Ventana privada cerrada"
        )
        
        if Date().timeIntervalSince(lastIncognitoNotificationTime) > 3.0 {
            lastIncognitoNotificationTime = Date()
            NotificationService.shared.sendNotification(
                title: "🕵️‍♂️ Modo Incógnito Bloqueado",
                body: "FocusPanic cerró la ventana privada para mantener el compromiso de transparencia y enfoque.",
                sound: "Basso"
            )
        }
    }
    
    // MARK: - 2. Reglas en Safari (Dominios + Palabras Clave)
    
    private func enforceRulesInSafari() {
        var allAllowed = Set(self.allowedDomains.map { sanitizeForAppleScript($0.replacingOccurrences(of: "www.", with: "").lowercased()) })
        allAllowed.formUnion(AppSettings.systemEssentialDomains.map { sanitizeForAppleScript($0) })
        
        let allowedListFormatted = allAllowed.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
        
        var exactDomainsToBlock: Set<String> = []
        for domain in self.blockedDomains {
            let clean = domain.replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !clean.isEmpty && !clean.hasPrefix("#") else { continue }
            if !allAllowed.contains(clean) {
                exactDomainsToBlock.insert(sanitizeForAppleScript(clean))
            }
        }
        
        let domainListFormatted = exactDomainsToBlock.map { "\"\($0)\"" }.joined(separator: ", ")
        
        // Formatear palabras clave prohibidas
        let keywordsFormatted = self.isKeywordBlockerEnabled
            ? self.blockedKeywords.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
            : ""
        
        let safariScript = """
        set allowedList to {\(allowedListFormatted)}
        set blockedList to {\(domainListFormatted)}
        set keywordsList to {\(keywordsFormatted)}
        set blockedFound to ""
        
        tell application "Safari"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set currentURL to URL of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "about:" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" then
                            
                            -- 1. Verificar Lista Blanca
                            set isAllowed to false
                            repeat with allowed in allowedList
                                if currentURL contains allowed then
                                    set isAllowed to true
                                    exit repeat
                                end if
                            end repeat
                            
                            if isAllowed is false then
                                -- 2. Verificar Dominios Bloqueados
                                repeat with blocked in blockedList
                                    if currentURL contains blocked then
                                        set URL of t to ("http://127.0.0.1:8484/?site=" & blocked)
                                        set blockedFound to blocked
                                        exit repeat
                                    end if
                                end repeat
                                
                                -- 3. Verificar Palabras Clave Prohibidas (Búsquedas & URLs)
                                if blockedFound is "" and (count of keywordsList) > 0 then
                                    repeat with kw in keywordsList
                                        if currentURL contains kw then
                                            set URL of t to ("http://127.0.0.1:8484/?site=Termino+Prohibido:+" & kw)
                                            set blockedFound to ("Búsqueda: " & kw)
                                            exit repeat
                                        end if
                                    end repeat
                                end if
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
    
    // MARK: - 3. Reglas en Navegadores Chromium (Chrome, Brave, Edge)
    
    private func enforceRulesInChromium(appName: String) {
        var allAllowed = Set(self.allowedDomains.map { sanitizeForAppleScript($0.replacingOccurrences(of: "www.", with: "").lowercased()) })
        allAllowed.formUnion(AppSettings.systemEssentialDomains.map { sanitizeForAppleScript($0) })
        let allowedListFormatted = allAllowed.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
        
        var exactDomainsToBlock: Set<String> = []
        for domain in self.blockedDomains {
            let clean = domain.replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !clean.isEmpty && !clean.hasPrefix("#") else { continue }
            if !allAllowed.contains(clean) {
                exactDomainsToBlock.insert(sanitizeForAppleScript(clean))
            }
        }
        let domainListFormatted = exactDomainsToBlock.map { "\"\($0)\"" }.joined(separator: ", ")
        
        let keywordsFormatted = self.isKeywordBlockerEnabled
            ? self.blockedKeywords.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
            : ""
        
        let chromiumScript = """
        set allowedList to {\(allowedListFormatted)}
        set blockedList to {\(domainListFormatted)}
        set keywordsList to {\(keywordsFormatted)}
        set blockedFound to ""
        
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in tabs of w
                        set currentURL to URL of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "chrome://" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" then
                            set isAllowed to false
                            repeat with allowed in allowedList
                                if currentURL contains allowed then
                                    set isAllowed to true
                                    exit repeat
                                end if
                            end repeat
                            
                            if isAllowed is false then
                                repeat with blocked in blockedList
                                    if currentURL contains blocked then
                                        set URL of t to ("http://127.0.0.1:8484/?site=" & blocked)
                                        set blockedFound to blocked
                                        exit repeat
                                    end if
                                end repeat
                                
                                if blockedFound is "" and (count of keywordsList) > 0 then
                                    repeat with kw in keywordsList
                                        if currentURL contains kw then
                                            set URL of t to ("http://127.0.0.1:8484/?site=Termino+Prohibido:+" & kw)
                                            set blockedFound to ("Búsqueda: " & kw)
                                            exit repeat
                                        end if
                                    end repeat
                                end if
                            end if
                        end if
                    end repeat
                end repeat
            end try
        end tell
        return blockedFound
        """
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: chromiumScript) {
            let result = script.executeAndReturnError(&error)
            let blockedDomain = result.stringValue ?? ""
            if !blockedDomain.isEmpty {
                notifyInterception(domain: blockedDomain, isWhitelist: false)
            }
        }
    }
    
    // MARK: - 4. Modo Bloqueo Total (Solo Lista Blanca en Safari)
    
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
    
    private func sanitizeForAppleScript(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
    }
    
    private func notifyInterception(domain: String, isWhitelist: Bool) {
        let isKeyword = domain.lowercased().contains("búsqueda") || domain.lowercased().contains("término") || domain.lowercased().contains("termino")
        FocusStatsManager.shared.recordInterception(
            source: domain,
            category: isKeyword ? "keyword" : "web",
            detail: domain
        )
        
        if Date().timeIntervalSince(lastInterceptionTime) > 3.0 {
            lastInterceptionTime = Date()
            let title = isWhitelist ? "🛡️ Sitio No Permitido (Modo Total)" : "🛡️ Distracción / Búsqueda Interceptada"
            let body = isWhitelist
                ? "FocusPanic cerró el acceso. '\(domain)' no está en tu Lista Blanca."
                : "FocusPanic detuvo el acceso a '\(domain)' para proteger tu enfoque."
            
            NotificationService.shared.sendNotification(
                title: title,
                body: body,
                sound: "Basso"
            )
        }
    }
}
