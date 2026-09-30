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
    private var isAdultShieldEnabled = false
    
    private var lastInterceptionTime: Date = Date.distantPast
    private var lastIncognitoNotificationTime: Date = Date.distantPast
    private var lastDuckDuckGoAlertTime: Date = Date.distantPast
    
    // Cola de control y candado de exclusión mutua
    private let watchdogQueue = DispatchQueue(label: "com.hector.FocusPanic.browserWatchdog", qos: .userInitiated)
    private var isChecking = false
    
    // Alertas al Compañero de Responsabilidad
    private var lastKeywordAlertTime: [String: Date] = [:]
    private var incognitoAttemptsInWindow: Int = 0
    private var lastIncognitoWindowReset: Date = Date()
    private var lastIncognitoPartnerAlertTime: Date = Date.distantPast
    
    private init() {}
    
    public func start(
        blockedDomains: [String] = [],
        allowedDomains: [String] = [],
        blockedKeywords: [String] = AppSettings.defaultBlockedKeywords,
        isWhitelistMode: Bool = false,
        isAntiIncognitoEnabled: Bool = true,
        isKeywordBlockerEnabled: Bool = true,
        isAdultShieldEnabled: Bool = false
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.blockedKeywords = blockedKeywords.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
        self.isAntiIncognitoEnabled = isAntiIncognitoEnabled
        self.isKeywordBlockerEnabled = isKeywordBlockerEnabled
        self.isAdultShieldEnabled = isAdultShieldEnabled
        
        stop()
        isRunning = true
        
        // Interceptación instantánea al iniciar
        checkAndInterceptTabs()
        
        DispatchQueue.main.async {
            // Monitoreo continuo ultra-responsivo cada 0.85 segundos
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { [weak self] _ in
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
        isKeywordBlockerEnabled: Bool = true,
        isAdultShieldEnabled: Bool = false
    ) {
        self.blockedDomains = blockedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.allowedDomains = allowedDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.blockedKeywords = blockedKeywords.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        self.isWhitelistMode = isWhitelistMode
        self.isAntiIncognitoEnabled = isAntiIncognitoEnabled
        self.isKeywordBlockerEnabled = isKeywordBlockerEnabled
        self.isAdultShieldEnabled = isAdultShieldEnabled
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isChecking = false
    }
    
    public func checkAndInterceptTabs() {
        guard isRunning else { return }
        
        watchdogQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Candado de exclusión mutua para evitar apilamiento de tareas
            if self.isChecking { return }
            self.isChecking = true
            defer { self.isChecking = false }
            
            let runningApps = NSWorkspace.shared.runningApplications
            let runningBundleIds = Set(runningApps.compactMap { $0.bundleIdentifier })
            
            // 0. Bloqueo Forzoso del Navegador DuckDuckGo (cuando el Escudo está activo)
            if self.isAdultShieldEnabled || self.isWhitelistMode {
                self.enforceDuckDuckGoBrowserBlock(runningApps: runningApps)
            }
            
            // 1. Escudo Anti-Modo Incógnito / Ventanas Privadas
            if self.isAntiIncognitoEnabled {
                self.enforceAntiIncognito(runningBundleIds: runningBundleIds)
            }
            
            // 2. Verificación de Integridad de DNS Cloudflare Families y Archivo /etc/hosts (Auto-reparación y Alerta)
            self.checkDnsIntegrity()
            self.checkHostsFileIntegrity()
            
            // 3. Monitoreo e Interceptación de Pestañas Multi-Navegador
            let browserConfigs: [(bundleId: String, appName: String, isSafariLike: Bool)] = [
                ("com.apple.Safari", "Safari", true),
                ("com.apple.SafariTechnologyPreview", "Safari Technology Preview", true),
                ("com.google.Chrome", "Google Chrome", false),
                ("com.google.Chrome.canary", "Google Chrome Canary", false),
                ("com.brave.Browser", "Brave Browser", false),
                ("com.brave.Browser.beta", "Brave Browser Beta", false),
                ("com.brave.Browser.nightly", "Brave Browser Nightly", false),
                ("com.microsoft.edgemac", "Microsoft Edge", false),
                ("com.microsoft.edgemac.Dev", "Microsoft Edge Dev", false),
                ("com.microsoft.edgemac.Beta", "Microsoft Edge Beta", false),
                ("com.microsoft.edgemac.Canary", "Microsoft Edge Canary", false),
                ("com.operasoftware.Opera", "Opera", false),
                ("com.operasoftware.OperaGX", "Opera GX", false),
                ("com.vivaldi.Vivaldi", "Vivaldi", false),
                ("company.thebrowser.Arc", "Arc", false),
                ("org.chromium.Chromium", "Chromium", false),
                ("com.kagi.kagimacOS", "Orion", true)
            ]
            
            for config in browserConfigs {
                if runningBundleIds.contains(config.bundleId) {
                    if config.isSafariLike {
                        if self.isWhitelistMode {
                            self.enforceWhitelistInSafari(appName: config.appName)
                        } else {
                            self.enforceRulesInSafari(appName: config.appName)
                        }
                    } else {
                        if self.isWhitelistMode {
                            self.enforceWhitelistInChromium(appName: config.appName)
                        } else {
                            self.enforceRulesInChromium(appName: config.appName)
                        }
                    }
                }
            }
            
            // 3. Vigilante Nativo de WebViews y Navegadores Integrados (Claude, Electron, PWAs)
            self.inspectNativeWebAreas(runningApps: runningApps)
            
            // 4. Rastreo Pasivo 24/7 de Tiempo y Visitas en Redes Sociales
            self.trackActiveSocialUsage(runningBundleIds: runningBundleIds)
        }
    }
    
    // MARK: - 1. Escudo Anti-Incógnito Multi-Navegador
    
    private func enforceAntiIncognito(runningBundleIds: Set<String>) {
        var closedAny = false
        
        // Safari Private Browsing
        if runningBundleIds.contains("com.apple.Safari") || runningBundleIds.contains("com.apple.SafariTechnologyPreview") {
            let safariName = runningBundleIds.contains("com.apple.SafariTechnologyPreview") ? "Safari Technology Preview" : "Safari"
            let safariIncogScript = """
            tell application "\(safariName)"
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
        
        // Chromium Browsers Incognito (SOLO si la aplicación está actualmente en ejecución)
        let chromiumConfigs: [(bundleId: String, appName: String)] = [
            ("com.google.Chrome", "Google Chrome"),
            ("com.google.Chrome.canary", "Google Chrome Canary"),
            ("com.brave.Browser", "Brave Browser"),
            ("com.brave.Browser.beta", "Brave Browser Beta"),
            ("com.microsoft.edgemac", "Microsoft Edge"),
            ("com.microsoft.edgemac.Dev", "Microsoft Edge Dev"),
            ("company.thebrowser.Arc", "Arc"),
            ("com.operasoftware.Opera", "Opera"),
            ("com.operasoftware.OperaGX", "Opera GX"),
            ("com.vivaldi.Vivaldi", "Vivaldi"),
            ("org.chromium.Chromium", "Chromium")
        ]
        for config in chromiumConfigs where runningBundleIds.contains(config.bundleId) {
            if closeChromiumIncognito(appName: config.appName) { closedAny = true }
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
        
        // Control de intentos continuos de navegación privada
        if Date().timeIntervalSince(lastIncognitoWindowReset) > 300.0 {
            incognitoAttemptsInWindow = 0
            lastIncognitoWindowReset = Date()
        }
        incognitoAttemptsInWindow += 1
        
        if incognitoAttemptsInWindow >= 3 && Date().timeIntervalSince(lastIncognitoPartnerAlertTime) > 300.0 {
            lastIncognitoPartnerAlertTime = Date()
            let count = incognitoAttemptsInWindow
            DispatchQueue.main.async {
                let partner = FocusEngine.shared.settings.officialPartnerEmail
                if FocusEngine.shared.settings.isPartnerAlertIncognitoEnabled && !partner.isEmpty {
                    EmailService.shared.sendIncognitoAlert(toEmail: partner, attemptsCount: count)
                }
            }
        }
        
        if Date().timeIntervalSince(lastIncognitoNotificationTime) > 3.0 {
            lastIncognitoNotificationTime = Date()
            NotificationService.shared.sendNotification(
                title: "🕵️‍♂️ Modo Incógnito Bloqueado",
                body: "FocusPanic cerró la ventana privada para mantener el compromiso de transparencia y enfoque.",
                sound: "Basso"
            )
        }
    }
    
    private func enforceDuckDuckGoBrowserBlock(runningApps: [NSRunningApplication]) {
        for app in runningApps {
            guard app.activationPolicy == .regular else { continue }
            let bId = app.bundleIdentifier?.lowercased() ?? ""
            let lName = app.localizedName?.lowercased() ?? ""
            let execName = app.executableURL?.lastPathComponent.lowercased() ?? ""
            
            if bId == "com.duckduckgo.macos.browser" ||
               bId == "com.duckduckgo.mobile.ios" ||
               bId.contains("duckduckgo.macos.browser") ||
               lName == "duckduckgo" ||
               lName.contains("duckduckgo privacy browser") ||
               execName == "duckduckgo" {
                
                app.forceTerminate()
                
                let now = Date()
                if now.timeIntervalSince(self.lastDuckDuckGoAlertTime) > 3.0 {
                    self.lastDuckDuckGoAlertTime = now
                    DispatchQueue.main.async {
                        SoundService.shared.play("Basso")
                        NotificationService.shared.sendNotification(
                            title: "🛑 Navegador DuckDuckGo Bloqueado",
                            body: "El navegador DuckDuckGo está bloqueado por el Escudo para prevenir navegación no moderada.",
                            sound: "Basso"
                        )
                        FocusStatsManager.shared.recordInterception(
                            source: "DuckDuckGo Browser",
                            category: "browser",
                            detail: "Navegador DuckDuckGo cerrado"
                        )
                    }
                }
            }
        }
    }
    
    private func buildAllowedSet() -> Set<String> {
        var allAllowed = Set<String>()
        for domain in self.allowedDomains {
            let clean = sanitizeForAppleScript(domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
            guard !clean.isEmpty else { continue }
            allAllowed.insert(clean)
            let withoutWww = clean.replacingOccurrences(of: "www.", with: "")
            allAllowed.insert(withoutWww)
            allAllowed.insert("www." + withoutWww)
            
            let hostOnly = withoutWww.components(separatedBy: "/").first ?? withoutWww
            allAllowed.insert(hostOnly)
            allAllowed.insert("www." + hostOnly)
        }
        for essential in AppSettings.systemEssentialDomains {
            let clean = sanitizeForAppleScript(essential.lowercased())
            allAllowed.insert(clean)
            let withoutWww = clean.replacingOccurrences(of: "www.", with: "")
            allAllowed.insert(withoutWww)
            allAllowed.insert("www." + withoutWww)
        }
        return allAllowed
    }
    
    // MARK: - 2. Reglas en Navegadores Safari / WebKit
    
    private func enforceRulesInSafari(appName: String = "Safari") {
        let allAllowed = buildAllowedSet()
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
        
        let isAnyKeywordsActive = self.isKeywordBlockerEnabled || self.isAdultShieldEnabled
        let keywordsFormatted = isAnyKeywordsActive
            ? self.blockedKeywords.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
            : ""
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let safariScript = """
        on checkDomainMatch(targetURL, domainItem)
            if targetURL contains "accounts.youtube.com" or targetURL contains "accounts.google.com" then
                return false
            end if
            if domainItem is "terabox" or domainItem contains "terabox" or domainItem is "1024tera" or domainItem is "4funbox" or domainItem is "mirrobox" or domainItem is "nephobox" or domainItem is "freeterabox" or domainItem is "tibibox" or domainItem is "redlib" or domainItem is "libreddit" or domainItem is "teddit" or domainItem is "nitter" or domainItem is "proxitok" or domainItem is "invidious" or domainItem is "piped" or domainItem does not contain "." then
                if targetURL contains ("://" & domainItem & ".") or targetURL contains ("." & domainItem & ".") or targetURL contains ("/" & domainItem & ".") or targetURL contains ("://" & domainItem & "/") or targetURL contains ("." & domainItem & "/") or targetURL contains domainItem then
                    return true
                end if
            end if
            if targetURL contains ("://" & domainItem & "/") or targetURL contains ("://" & domainItem & "?") or targetURL contains ("://" & domainItem & "#") or targetURL ends with ("://" & domainItem) or targetURL contains ("." & domainItem & "/") or targetURL contains ("." & domainItem & "?") or targetURL contains ("." & domainItem & "#") or targetURL ends with ("." & domainItem) or targetURL contains ("//" & domainItem & "/") or targetURL is equal to domainItem or targetURL contains ("://" & domainItem & ".") or targetURL contains ("." & domainItem & ".") then
                return true
            end if
            return false
        end checkDomainMatch

        on checkTeraBoxMatch(targetURL, targetTitle)
            set combined to (targetURL as text) & " " & (targetTitle as text)
            if combined contains "terabox" or combined contains "teraboz" or combined contains "teraboc" or combined contains "teraz" or combined contains "terboz" or combined contains "terbox" or combined contains "teravox" or combined contains "terrabox" or combined contains "terraboz" or combined contains "terraboc" or combined contains "1024tera" or combined contains "freeterabox" or combined contains "terashare" or combined contains "terafileshare" or combined contains "teradownload" or combined contains "teraboxdl" or combined contains "teradl" or combined contains "tibibox" or combined contains "4funbox" or combined contains "mirrobox" or combined contains "nephobox" or combined contains "teraboxapp" or combined contains "teraboxlink" or combined contains "momerybox" or combined contains "boxtera" or combined contains "flowvideoplayer" or combined contains "tera box" or combined contains "tera boz" or combined contains "tera boc" or combined contains "tera z" then
                return true
            end if
            return false
        end checkTeraBoxMatch

        on checkKeywordMatch(targetURL, targetTitle, kw)
            set combined to (targetTitle as text) & " " & (targetURL as text)
            set prevDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to {" ", "+", "%20", "-", "_", "/", "?", "=", "&", ".", ",", ":", ";", "(", ")", "[", "]", "'", "\\"", "!", "@", "#", "$", "%", "^", "*", "~", "`", "<", ">", "|", "\\\\"}
            set textParts to text items of combined
            set AppleScript's text item delimiters to " "
            set normalized to " " & (textParts as text) & " "
            set AppleScript's text item delimiters to prevDelims
            if normalized contains (" " & kw & " ") then
                return true
            end if
            return false
        end checkKeywordMatch

        on encodeForURL(txt)
            set prevDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to " "
            set txtList to text items of txt
            set AppleScript's text item delimiters to "%20"
            set res to txtList as text
            set AppleScript's text item delimiters to prevDelims
            return res
        end encodeForURL

        set allowedList to {\(allowedListFormatted)}
        set blockedList to {\(domainListFormatted)}
        set keywordsList to {\(keywordsFormatted)}
        set blockedFound to ""
        
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in (tabs of w as list)
                        set currentURL to URL of t
                        set currentTitle to name of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "about:" and currentURL does not start with "favorites://" and currentURL does not start with "topsites://" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" and currentURL does not start with "http://127.0.0.1" and currentURL does not start with "http://localhost" then
                            
                            -- 0. VERIFICACIÓN ULTRA-ESTRICTA DE TERABOX (URL, Título y Texto de la Página / Buscador)
                            if \(isTeraBoxStrict ? "true" : "false") then
                                if my checkTeraBoxMatch(currentURL, currentTitle) then
                                    set blockedFound to "TeraBox Detectado"
                                    set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blockedFound)))
                                else
                                    set pageText to ""
                                    try
                                        set pageText to text of t
                                    end try
                                    if pageText is not "" and (pageText contains "terabox" or pageText contains "teraboz" or pageText contains "teraboc" or pageText contains "1024tera" or pageText contains "freeterabox" or pageText contains "terashare" or pageText contains "teraboxdl" or pageText contains "terabox.com") then
                                        set blockedFound to "TeraBox en Resultados"
                                        set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blockedFound)))
                                    end if
                                end if
                            end if
                            
                            -- 1. VERIFICACIÓN DE PALABRAS PROHIBIDAS (Tokenizado de palabras completas)
                            if blockedFound is "" and (count of keywordsList) > 0 then
                                repeat with kw in keywordsList
                                    if my checkKeywordMatch(currentURL, currentTitle, kw) then
                                        set blockedFound to ("Búsqueda: " & kw)
                                        set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blockedFound)))
                                        exit repeat
                                    end if
                                end repeat
                            end if
                            
                            -- 2. VERIFICACIÓN DE DOMINIOS BLOQUEADOS Y LISTA BLANCA
                            if blockedFound is "" then
                                set isAllowed to false
                                repeat with allowed in allowedList
                                    if my checkDomainMatch(currentURL, allowed) then
                                        set isAllowed to true
                                        exit repeat
                                    end if
                                end repeat
                                
                                if isAllowed is false then
                                    repeat with blocked in blockedList
                                        if my checkDomainMatch(currentURL, blocked) then
                                            set blockedFound to blocked
                                            set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blocked)))
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
                notifyInterception(domain: blockedDomain, sourceApp: "Safari", isWhitelist: false)
            }
        }
    }
    
    // MARK: - 3. Reglas en Navegadores Chromium (Chrome, Brave, Edge, Arc, Opera, Vivaldi)
    
    private func enforceRulesInChromium(appName: String) {
        let allAllowed = buildAllowedSet()
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
        
        let isAnyKeywordsActive = self.isKeywordBlockerEnabled || self.isAdultShieldEnabled
        let keywordsFormatted = isAnyKeywordsActive
            ? self.blockedKeywords.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
            : ""
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let chromiumScript = """
        on checkDomainMatch(targetURL, domainItem)
            if targetURL contains "accounts.youtube.com" or targetURL contains "accounts.google.com" then
                return false
            end if
            if domainItem is "terabox" or domainItem contains "terabox" or domainItem is "1024tera" or domainItem is "4funbox" or domainItem is "mirrobox" or domainItem is "nephobox" or domainItem is "freeterabox" or domainItem is "tibibox" or domainItem is "redlib" or domainItem is "libreddit" or domainItem is "teddit" or domainItem is "nitter" or domainItem is "proxitok" or domainItem is "invidious" or domainItem is "piped" or domainItem does not contain "." then
                if targetURL contains ("://" & domainItem & ".") or targetURL contains ("." & domainItem & ".") or targetURL contains ("/" & domainItem & ".") or targetURL contains ("://" & domainItem & "/") or targetURL contains ("." & domainItem & "/") or targetURL contains domainItem then
                    return true
                end if
            end if
            if targetURL contains ("://" & domainItem & "/") or targetURL contains ("://" & domainItem & "?") or targetURL contains ("://" & domainItem & "#") or targetURL ends with ("://" & domainItem) or targetURL contains ("." & domainItem & "/") or targetURL contains ("." & domainItem & "?") or targetURL contains ("." & domainItem & "#") or targetURL ends with ("." & domainItem) or targetURL contains ("//" & domainItem & "/") or targetURL is equal to domainItem or targetURL contains ("://" & domainItem & ".") or targetURL contains ("." & domainItem & ".") then
                return true
            end if
            return false
        end checkDomainMatch

        on checkTeraBoxMatch(targetURL, targetTitle)
            set combined to (targetURL as text) & " " & (targetTitle as text)
            if combined contains "terabox" or combined contains "teraboz" or combined contains "teraboc" or combined contains "teraz" or combined contains "terboz" or combined contains "terbox" or combined contains "teravox" or combined contains "terrabox" or combined contains "terraboz" or combined contains "terraboc" or combined contains "1024tera" or combined contains "freeterabox" or combined contains "terashare" or combined contains "terafileshare" or combined contains "teradownload" or combined contains "teraboxdl" or combined contains "teradl" or combined contains "tibibox" or combined contains "4funbox" or combined contains "mirrobox" or combined contains "nephobox" or combined contains "teraboxapp" or combined contains "teraboxlink" or combined contains "momerybox" or combined contains "boxtera" or combined contains "flowvideoplayer" or combined contains "tera box" or combined contains "tera boz" or combined contains "tera boc" or combined contains "tera z" then
                return true
            end if
            return false
        end checkTeraBoxMatch

        on checkKeywordMatch(targetURL, targetTitle, kw)
            set combined to (targetTitle as text) & " " & (targetURL as text)
            set prevDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to {" ", "+", "%20", "-", "_", "/", "?", "=", "&", ".", ",", ":", ";", "(", ")", "[", "]", "'", "\\"", "!", "@", "#", "$", "%", "^", "*", "~", "`", "<", ">", "|", "\\\\"}
            set textParts to text items of combined
            set AppleScript's text item delimiters to " "
            set normalized to " " & (textParts as text) & " "
            set AppleScript's text item delimiters to prevDelims
            if normalized contains (" " & kw & " ") then
                return true
            end if
            return false
        end checkKeywordMatch

        on encodeForURL(txt)
            set prevDelims to AppleScript's text item delimiters
            set AppleScript's text item delimiters to " "
            set txtList to text items of txt
            set AppleScript's text item delimiters to "%20"
            set res to txtList as text
            set AppleScript's text item delimiters to prevDelims
            return res
        end encodeForURL

        set allowedList to {\(allowedListFormatted)}
        set blockedList to {\(domainListFormatted)}
        set keywordsList to {\(keywordsFormatted)}
        set blockedFound to ""
        
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in (tabs of w as list)
                        set currentURL to URL of t
                        set currentTitle to title of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "chrome://" and currentURL does not start with "edge://" and currentURL does not start with "brave://" and currentURL does not start with "file://" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" and currentURL does not start with "http://127.0.0.1" and currentURL does not start with "http://localhost" then
                            
                            -- 0. VERIFICACIÓN ULTRA-ESTRICTA DE TERABOX (URL y Título del Buscador / Página)
                            if \(isTeraBoxStrict ? "true" : "false") then
                                if my checkTeraBoxMatch(currentURL, currentTitle) then
                                    set blockedFound to "TeraBox Detectado"
                                    set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blockedFound)))
                                end if
                            end if
                            
                            -- 1. VERIFICACIÓN DE PALABRAS PROHIBIDAS (Tokenizado de palabras completas)
                            if blockedFound is "" and (count of keywordsList) > 0 then
                                repeat with kw in keywordsList
                                    if my checkKeywordMatch(currentURL, currentTitle, kw) then
                                        set blockedFound to ("Búsqueda: " & kw)
                                        set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blockedFound)))
                                        exit repeat
                                    end if
                                end repeat
                            end if
                            
                            -- 2. VERIFICACIÓN DE DOMINIOS BLOQUEADOS Y LISTA BLANCA
                            if blockedFound is "" then
                                set isAllowed to false
                                repeat with allowed in allowedList
                                    if my checkDomainMatch(currentURL, allowed) then
                                        set isAllowed to true
                                        exit repeat
                                    end if
                                end repeat
                                
                                if isAllowed is false then
                                    repeat with blocked in blockedList
                                        if my checkDomainMatch(currentURL, blocked) then
                                            set blockedFound to blocked
                                            set URL of t to ("http://127.0.0.1:8484/?site=" & (my encodeForURL(blocked)))
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
                notifyInterception(domain: blockedDomain, sourceApp: appName, isWhitelist: false)
            }
        }
    }
    
    // MARK: - 4. Modo Bloqueo Total (Solo Lista Blanca)
    
    private func enforceWhitelistInSafari(appName: String = "Safari") {
        let allAllowed = buildAllowedSet()
        let allowedListFormatted = allAllowed.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let safariScript = """
        on checkDomainMatch(targetURL, domainItem)
            if targetURL contains ("://" & domainItem & "/") or targetURL contains ("://" & domainItem & "?") or targetURL contains ("://" & domainItem & "#") or targetURL ends with ("://" & domainItem) or targetURL contains ("." & domainItem & "/") or targetURL contains ("." & domainItem & "?") or targetURL contains ("." & domainItem & "#") or targetURL ends with ("." & domainItem) or targetURL contains ("//" & domainItem & "/") or targetURL is equal to domainItem then
                return true
            end if
            return false
        end checkDomainMatch

        on checkTeraBoxMatch(targetURL, targetTitle)
            set combined to (targetURL as text) & " " & (targetTitle as text)
            if combined contains "terabox" or combined contains "teraboz" or combined contains "teraboc" or combined contains "teraz" or combined contains "terboz" or combined contains "terbox" or combined contains "teravox" or combined contains "terrabox" or combined contains "terraboz" or combined contains "terraboc" or combined contains "1024tera" or combined contains "freeterabox" or combined contains "terashare" or combined contains "terafileshare" or combined contains "teradownload" or combined contains "teraboxdl" or combined contains "teradl" or combined contains "tibibox" or combined contains "4funbox" or combined contains "mirrobox" or combined contains "nephobox" or combined contains "teraboxapp" or combined contains "teraboxlink" or combined contains "momerybox" or combined contains "boxtera" or combined contains "flowvideoplayer" or combined contains "tera box" or combined contains "tera boz" or combined contains "tera boc" or combined contains "tera z" then
                return true
            end if
            return false
        end checkTeraBoxMatch

        set allowedList to {\(allowedListFormatted)}
        set blockedFound to ""
        
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in (tabs of w as list)
                        set currentURL to URL of t
                        set currentTitle to name of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "about:" and currentURL does not start with "favorites://" and currentURL does not start with "topsites://" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" and currentURL does not start with "http://127.0.0.1" and currentURL does not start with "http://localhost" then
                            
                            -- 0. VERIFICACIÓN ULTRA-ESTRICTA DE TERABOX INCLUSO EN LISTA BLANCA
                            if \(isTeraBoxStrict ? "true" : "false") then
                                if my checkTeraBoxMatch(currentURL, currentTitle) then
                                    set blockedFound to "TeraBox Detectado"
                                    set URL of t to "http://127.0.0.1:8484/?site=TeraBox%20Detectado"
                                else
                                    set pageText to ""
                                    try
                                        set pageText to text of t
                                    end try
                                    if pageText is not "" and (pageText contains "terabox" or pageText contains "teraboz" or pageText contains "teraboc" or pageText contains "1024tera" or pageText contains "freeterabox" or pageText contains "terashare" or pageText contains "teraboxdl" or pageText contains "terabox.com") then
                                        set blockedFound to "TeraBox en Resultados"
                                        set URL of t to "http://127.0.0.1:8484/?site=TeraBox%20en%20Resultados"
                                    end if
                                end if
                            end if
                            
                            if blockedFound is "" then
                                set isAllowed to false
                                repeat with allowed in allowedList
                                    if my checkDomainMatch(currentURL, allowed) then
                                        set isAllowed to true
                                        exit repeat
                                    end if
                                end repeat
                                
                                if isAllowed is false then
                                    set blockedFound to currentURL
                                    set URL of t to "http://127.0.0.1:8484/?site=bloqueo-total"
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
            let rawUrl = result.stringValue ?? ""
            if !rawUrl.isEmpty {
                let domain = URL(string: rawUrl)?.host ?? rawUrl
                notifyInterception(domain: domain, sourceApp: "Safari", isWhitelist: true)
            }
        }
    }
    
    private func enforceWhitelistInChromium(appName: String) {
        let allAllowed = buildAllowedSet()
        let allowedListFormatted = allAllowed.filter { !$0.isEmpty }.map { "\"\($0)\"" }.joined(separator: ", ")
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let chromiumScript = """
        on checkDomainMatch(targetURL, domainItem)
            if targetURL contains ("://" & domainItem & "/") or targetURL contains ("://" & domainItem & "?") or targetURL contains ("://" & domainItem & "#") or targetURL ends with ("://" & domainItem) or targetURL contains ("." & domainItem & "/") or targetURL contains ("." & domainItem & "?") or targetURL contains ("." & domainItem & "#") or targetURL ends with ("." & domainItem) or targetURL contains ("//" & domainItem & "/") or targetURL is equal to domainItem then
                return true
            end if
            return false
        end checkDomainMatch

        on checkTeraBoxMatch(targetURL, targetTitle)
            set combined to (targetURL as text) & " " & (targetTitle as text)
            if combined contains "terabox" or combined contains "teraboz" or combined contains "teraboc" or combined contains "teraz" or combined contains "terboz" or combined contains "terbox" or combined contains "teravox" or combined contains "terrabox" or combined contains "terraboz" or combined contains "terraboc" or combined contains "1024tera" or combined contains "freeterabox" or combined contains "terashare" or combined contains "terafileshare" or combined contains "teradownload" or combined contains "teraboxdl" or combined contains "teradl" or combined contains "tibibox" or combined contains "4funbox" or combined contains "mirrobox" or combined contains "nephobox" or combined contains "teraboxapp" or combined contains "teraboxlink" or combined contains "momerybox" or combined contains "boxtera" or combined contains "flowvideoplayer" or combined contains "tera box" or combined contains "tera boz" or combined contains "tera boc" or combined contains "tera z" then
                return true
            end if
            return false
        end checkTeraBoxMatch

        set allowedList to {\(allowedListFormatted)}
        set blockedFound to ""
        
        tell application "\(appName)"
            try
                repeat with w in windows
                    repeat with t in (tabs of w as list)
                        set currentURL to URL of t
                        set currentTitle to title of t
                        if currentURL is not missing value and currentURL is not "" and currentURL does not start with "chrome://" and currentURL does not start with "edge://" and currentURL does not start with "brave://" and currentURL does not start with "file://" and currentURL does not contain "127.0.0.1:8484" and currentURL does not contain "localhost:8484" and currentURL does not start with "http://127.0.0.1" and currentURL does not start with "http://localhost" then
                            
                            -- 0. VERIFICACIÓN ULTRA-ESTRICTA DE TERABOX INCLUSO EN LISTA BLANCA
                            if \(isTeraBoxStrict ? "true" : "false") then
                                if my checkTeraBoxMatch(currentURL, currentTitle) then
                                    set blockedFound to "TeraBox Detectado"
                                    set URL of t to "http://127.0.0.1:8484/?site=TeraBox%20Detectado"
                                end if
                            end if
                            
                            if blockedFound is "" then
                                set isAllowed to false
                                repeat with allowed in allowedList
                                    if my checkDomainMatch(currentURL, allowed) then
                                        set isAllowed to true
                                        exit repeat
                                    end if
                                end repeat
                                
                                if isAllowed is false then
                                    set blockedFound to currentURL
                                    set URL of t to "http://127.0.0.1:8484/?site=bloqueo-total"
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
            let rawUrl = result.stringValue ?? ""
            if !rawUrl.isEmpty {
                let domain = URL(string: rawUrl)?.host ?? rawUrl
                notifyInterception(domain: domain, sourceApp: appName, isWhitelist: true)
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
    
    private func notifyInterception(domain: String, sourceApp: String = "Navegador Web", isWhitelist: Bool) {
        let isKeyword = domain.lowercased().contains("búsqueda") || domain.lowercased().contains("término") || domain.lowercased().contains("termino") || domain.lowercased().contains("busqueda")
        FocusStatsManager.shared.recordInterception(
            source: sourceApp,
            category: isKeyword ? "keyword" : "web",
            detail: domain
        )
        
        // Alerta inmediata al compañero si se intentó buscar una palabra prohibida o acceder a un sitio para adultos / prohibido
        let isAdultSite = AdultBlockListProvider.adultDomains.contains(where: { domain.lowercased().contains($0) })
        if isKeyword || isAdultSite {
            let itemBlocked = isKeyword
                ? domain.replacingOccurrences(of: "Búsqueda: ", with: "").replacingOccurrences(of: "busqueda: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                : domain
            let lastAlert = lastKeywordAlertTime[itemBlocked] ?? Date.distantPast
            if Date().timeIntervalSince(lastAlert) > 60.0 {
                lastKeywordAlertTime[itemBlocked] = Date()
                DispatchQueue.main.async {
                    let partner = FocusEngine.shared.settings.officialPartnerEmail
                    if FocusEngine.shared.settings.isPartnerAlertKeywordsEnabled && !partner.isEmpty {
                        EmailService.shared.sendKeywordAlert(toEmail: partner, keyword: itemBlocked, source: sourceApp)
                    }
                }
            }
        }
        
        if Date().timeIntervalSince(lastInterceptionTime) > 3.0 {
            lastInterceptionTime = Date()
            let title = isWhitelist ? "🛡️ Sitio No Permitido (Modo Total)" : "🛡️ Distracción / Búsqueda Interceptada"
            let body = isWhitelist
                ? "FocusPanic cerró el acceso en \(sourceApp). '\(domain)' no está en tu Lista Blanca."
                : "FocusPanic detuvo el acceso a '\(domain)' en \(sourceApp) para proteger tu enfoque."
            
            NotificationService.shared.sendNotification(
                title: title,
                body: body,
                sound: "Basso"
            )
        }
    }
    
    // MARK: - 3. Inspección Nativa Ultrarrápida de WebViews (Claude, ChatGPT, Safari Web Apps, Electron)
    
    private func inspectNativeWebAreas(runningApps: [NSRunningApplication]) {
        guard self.isKeywordBlockerEnabled || !self.blockedDomains.isEmpty || self.isAdultShieldEnabled else { return }
        
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let targetBundleIds: Set<String> = [
            "com.anthropic.claudefordesktop",
            "com.openai.chat",
            "com.google.GeminiMacOS",
            "com.microsoft.VSCode"
        ]
        
        for app in runningApps {
            guard let bundleId = app.bundleIdentifier else { continue }
            
            // 1. Manejo dinámico para Safari Web Apps (PWAs en el Dock de macOS)
            if bundleId.hasPrefix("com.apple.Safari.WebApp") {
                inspectSafariWebApp(app: app)
                continue
            }
            
            // 2. Apps objetivo con WebViews libres o incrustados
            guard targetBundleIds.contains(bundleId) else { continue }
            
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var windowsVal: AnyObject?
            guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsVal) == .success,
                  let windows = windowsVal as? [AXUIElement] else { continue }
            
            for window in windows {
                inspectElementHierarchy(window, app: app, depth: 0)
            }
        }
        
        // 3. Inspección del navegador frontal si TeraBox estricto está activo y se muestran resultados
        if isTeraBoxStrict, let frontApp = NSWorkspace.shared.frontmostApplication,
           let fId = frontApp.bundleIdentifier,
           !fId.hasPrefix("com.apple.Safari.WebApp"),
           (fId.contains("Chrome") || fId.contains("brave") || fId.contains("Arc") || fId.contains("edge") || fId.contains("Opera") || fId.contains("Vivaldi")) {
            let axApp = AXUIElementCreateApplication(frontApp.processIdentifier)
            var windowVal: AnyObject?
            if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowVal) == .success,
               let window = windowVal {
                var foundCount = 0
                scanElementsForTeraBox(window as! AXUIElement, depth: 0, count: &foundCount)
                if foundCount > 0 {
                    handleNativeWebAreaInterception(app: frontApp, reason: "TeraBox en Resultados", url: frontApp.localizedName ?? "Navegador")
                }
            }
        }
    }
    
    private func inspectSafariWebApp(app: NSRunningApplication) {
        let isTeraBoxStrict = self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") })
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsVal: AnyObject?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsVal) == .success,
              let windows = windowsVal as? [AXUIElement] else { return }
        
        for window in windows {
            var titleVal: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleVal)
            let windowTitle = (titleVal as? String) ?? ""
            
            // 1. Verificación ultra-estricta de TeraBox en el título de la ventana
            if isTeraBoxStrict && AdultBlockListProvider.containsTeraBoxSignature(windowTitle) {
                handleNativeWebAreaInterception(app: app, reason: "TeraBox Detectado", url: windowTitle)
                return
            }
            
            // 2. Verificación de palabras clave prohibidas en el título
            if (self.isKeywordBlockerEnabled || self.isAdultShieldEnabled) && !self.blockedKeywords.isEmpty {
                for kw in self.blockedKeywords {
                    let cleanKw = kw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard cleanKw.count >= 2 else { continue }
                    if matchesKeywordToken(in: windowTitle, keyword: cleanKw) {
                        handleNativeWebAreaInterception(app: app, reason: "Búsqueda: \(cleanKw)", url: windowTitle)
                        return
                    }
                }
            }
            
            // 3. Obtener la URL activa navegada en la ventana
            if let activeUrl = findRootWebAreaUrl(window, depth: 0), !activeUrl.isEmpty {
                let lowerUrl = activeUrl.lowercased()
                
                if isTeraBoxStrict && AdultBlockListProvider.containsTeraBoxSignature(activeUrl) {
                    handleNativeWebAreaInterception(app: app, reason: "TeraBox Detectado", url: activeUrl)
                    return
                }
                
                for blocked in self.blockedDomains {
                    let cleanBlocked = blocked.lowercased().replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanBlocked.isEmpty else { continue }
                    if matchesDomainOrInstance(targetURL: lowerUrl, domainItem: cleanBlocked) {
                        handleNativeWebAreaInterception(app: app, reason: cleanBlocked, url: activeUrl)
                        return
                    }
                }
            }
            
            // 4. Si el escudo para adultos o TeraBox estricto está activo, inspeccionar resultados de búsqueda / contenido
            if isTeraBoxStrict {
                var foundCount = 0
                scanElementsForTeraBox(window, depth: 0, count: &foundCount)
                if foundCount > 0 {
                    handleNativeWebAreaInterception(app: app, reason: "TeraBox en Resultados", url: windowTitle)
                    return
                }
            }
        }
    }
    
    private func scanElementsForTeraBox(_ element: AXUIElement, depth: Int, count: inout Int) {
        guard depth < 12, count == 0 else { return }
        
        var titleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
        if let title = titleVal as? String, !title.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(title) {
            count += 1
            return
        }
        
        var valVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valVal)
        if let val = valVal as? String, !val.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(val) {
            count += 1
            return
        }
        
        var urlVal: AnyObject?
        AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlVal)
        if let urlStr = (urlVal as? String) ?? ((urlVal as? URL)?.absoluteString), !urlStr.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(urlStr) {
            count += 1
            return
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children {
                scanElementsForTeraBox(child, depth: depth + 1, count: &count)
                if count > 0 { return }
            }
        }
    }
    
    private func findRootWebAreaUrl(_ element: AXUIElement, depth: Int) -> String? {
        guard depth < 16 else { return nil }
        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        let role = (roleVal as? String) ?? ""
        if role == "AXWebArea" {
            var urlVal: AnyObject?
            AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlVal)
            let urlString = (urlVal as? String) ?? ((urlVal as? URL)?.absoluteString ?? "")
            if !urlString.isEmpty && !urlString.contains("127.0.0.1") && !urlString.contains("localhost") {
                return urlString
            }
        }
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children {
                if let found = findRootWebAreaUrl(child, depth: depth + 1) {
                    return found
                }
            }
        }
        return nil
    }
    
    private func inspectElementHierarchy(_ element: AXUIElement, app: NSRunningApplication, depth: Int) {
        guard depth < 16 else { return }
        
        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        let role = (roleVal as? String) ?? ""
        
        if role == "AXWebArea" || role.contains("Web") || role == "AXTextField" || role == "AXStaticText" || role == "AXLink" || role == "AXHeading" {
            var titleVal: AnyObject?
            var urlVal: AnyObject?
            var valueVal: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
            AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlVal)
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueVal)
            
            let title = (titleVal as? String) ?? ""
            let urlString = (urlVal as? String) ?? ((urlVal as? URL)?.absoluteString ?? "")
            let valText = (valueVal as? String) ?? ""
            
            // Ignorar vistas internas locales de la aplicación
            if urlString.contains("127.0.0.1:8484") || urlString.contains("localhost:8484") || urlString.contains("app.asar") {
                return
            }
            
            // Ignorar URLs de autenticación y sincronización de sesiones (Google SSO, OAuth)
            if urlString.contains("accounts.youtube.com") ||
               urlString.contains("accounts.google.com") ||
               urlString.contains("/setsid") ||
               urlString.contains("/set_sid") {
                return
            }
            
            // 0. Verificación Ultra-Estricta de TeraBox
            if self.isAdultShieldEnabled || self.blockedKeywords.contains("terabox") || self.blockedDomains.contains(where: { $0.contains("terabox") }) {
                if AdultBlockListProvider.containsTeraBoxSignature(title) ||
                   AdultBlockListProvider.containsTeraBoxSignature(urlString) ||
                   AdultBlockListProvider.containsTeraBoxSignature(valText) {
                    handleNativeWebAreaInterception(app: app, reason: "TeraBox Detectado", url: urlString)
                    return
                }
            }
            
            // 1. Verificación de Palabras Prohibidas (Tokenización de palabras completas)
            if (self.isKeywordBlockerEnabled || self.isAdultShieldEnabled) && !self.blockedKeywords.isEmpty {
                for kw in self.blockedKeywords {
                    let cleanKw = kw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    guard cleanKw.count >= 2 else { continue }
                    
                    if matchesKeywordToken(in: title, keyword: cleanKw) ||
                       matchesKeywordToken(in: urlString, keyword: cleanKw) ||
                       matchesKeywordToken(in: valText, keyword: cleanKw) {
                        
                        handleNativeWebAreaInterception(app: app, reason: "Búsqueda: \(cleanKw)", url: urlString)
                        return
                    }
                }
            }
            
            // 2. Verificación de Dominios Bloqueados e Instancias (redlib, pornhub, etc.)
            let lowerUrl = urlString.lowercased()
            if !lowerUrl.isEmpty && !lowerUrl.starts(with: "file:") {
                for blocked in self.blockedDomains {
                    let cleanBlocked = blocked.lowercased().replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanBlocked.isEmpty else { continue }
                    
                    if matchesDomainOrInstance(targetURL: lowerUrl, domainItem: cleanBlocked) {
                        handleNativeWebAreaInterception(app: app, reason: cleanBlocked, url: urlString)
                        return
                    }
                }
            }
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for child in children {
                inspectElementHierarchy(child, app: app, depth: depth + 1)
            }
        }
    }
    
    private func matchesKeywordToken(in text: String, keyword: String) -> Bool {
        guard !text.isEmpty, !keyword.isEmpty else { return false }
        let lower = text.lowercased()
        let cleanKw = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si es una firma de TeraBox, coincidencia directa como subcadena en cualquier parte
        if AdultBlockListProvider.containsTeraBoxSignature(cleanKw) {
            return lower.contains(cleanKw)
        }
        
        // Si la palabra clave contiene espacios (frase compuesta como "porno casero")
        if cleanKw.contains(" ") {
            return lower.contains(cleanKw)
        }
        
        // Tokenización de palabras individuales completas (word boundaries)
        let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return tokens.contains(cleanKw)
    }
    
    private func matchesDomainOrInstance(targetURL: String, domainItem: String) -> Bool {
        // Exclusión explícita de endpoints de autenticación SSO de Google / YouTube
        if targetURL.contains("accounts.youtube.com") ||
           targetURL.contains("accounts.google.com") ||
           targetURL.contains("/setsid") ||
           targetURL.contains("/set_sid") {
            return false
        }
        
        if targetURL.contains("terabox") || targetURL.contains("1024tera") || targetURL.contains("freeterabox") {
            return true
        }
        
        let instances = [
            "terabox", "1024tera", "4funbox", "mirrobox", "nephobox", "freeterabox", "tibibox",
            "terashare", "terafileshare", "teradownload", "teraboxdl", "teraboxdownloader",
            "teradl", "teradrive", "terasaver", "terafast", "teraboxlink",
            "redlib", "libreddit", "teddit", "nitter", "proxitok", "invidious", "piped"
        ]
        if instances.contains(where: { domainItem.contains($0) }) || !domainItem.contains(".") {
            if targetURL.contains("://\(domainItem).") ||
               targetURL.contains(".\(domainItem).") ||
               targetURL.contains("/\(domainItem).") ||
               targetURL.contains("://\(domainItem)/") ||
               targetURL.contains(".\(domainItem)/") ||
               targetURL.contains(domainItem) {
                return true
            }
        }
        if targetURL.contains("://\(domainItem)/") ||
           targetURL.contains("://\(domainItem)?") ||
           targetURL.contains("://\(domainItem)#") ||
           targetURL.hasSuffix("://\(domainItem)") ||
           targetURL.contains(".\(domainItem)/") ||
           targetURL.contains(".\(domainItem)?") ||
           targetURL.contains(".\(domainItem)#") ||
           targetURL.hasSuffix(".\(domainItem)") ||
           targetURL.contains("//\(domainItem)/") ||
           targetURL == domainItem ||
           targetURL.contains("://\(domainItem).") ||
           targetURL.contains(".\(domainItem).") {
            return true
        }
        return false
    }
    
    private func handleNativeWebAreaInterception(app: NSRunningApplication, reason: String, url: String) {
        let appName = app.localizedName ?? "App"
        
        // 1. Cerrar la pestaña o preview en Claude / Electron con Cmd + W
        let script = """
        tell application "System Events"
            try
                tell process "\(appName)"
                    keystroke "w" using {command down}
                end tell
            end try
        end tell
        """
        if let cs = NSAppleScript(source: script) {
            var cerr: NSDictionary?
            cs.executeAndReturnError(&cerr)
        }
        
        // 2. Notificar y registrar intercepción con detalle y app de origen
        notifyInterception(domain: reason, sourceApp: appName, isWhitelist: false)
    }
    
    // MARK: - 3.5. Integridad de DNS Cloudflare Families y Archivo /etc/hosts (Auto-reparación y Alerta)
    private var lastDnsTamperCheck: Date = Date.distantPast
    private var wasDnsAlertSentForCurrentTamper: Bool = false
    private var lastHostsTamperCheck: Date = Date.distantPast
    private var wasHostsAlertSentForCurrentTamper: Bool = false
    
    private func checkHostsFileIntegrity() {
        let now = Date()
        guard now.timeIntervalSince(lastHostsTamperCheck) >= 20 else { return }
        lastHostsTamperCheck = now
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let engine = FocusEngine.shared
            let shouldBeBlocking = (engine.sessionStatus == .active) || engine.settings.isPermanentShieldActive
            guard shouldBeBlocking else { return }
            
            DispatchQueue.global(qos: .background).async {
                let isBlocking = HostBlockerService.shared.isCurrentlyBlocking()
                if !isBlocking {
                    print("⚠️ [FocusPanic] Se detectó que el archivo /etc/hosts fue manipulado o vaciado. Restaurando bloqueo...")
                    DispatchQueue.main.async {
                        if engine.sessionStatus == .active {
                            engine.applySystemBlocks()
                        } else {
                            engine.applyPermanentProtectionOnly()
                        }
                        
                        if !self.wasHostsAlertSentForCurrentTamper {
                            self.wasHostsAlertSentForCurrentTamper = true
                            let partnerEmail = engine.settings.officialPartnerEmail
                            if !partnerEmail.isEmpty {
                                EmailService.shared.sendTamperAlert(
                                    toEmail: partnerEmail,
                                    actionDetail: "Se detectó que el archivo del sistema /etc/hosts fue modificado o limpiado externamente para intentar eludir los bloqueos de FocusPanic. La app restauró la protección de inmediato."
                                )
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.wasHostsAlertSentForCurrentTamper = false
                    }
                }
            }
        }
    }
    
    private func checkDnsIntegrity() {
        let now = Date()
        guard now.timeIntervalSince(lastDnsTamperCheck) >= 15 else { return }
        lastDnsTamperCheck = now
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let settings = FocusEngine.shared.settings
            guard settings.isAlwaysBlockAdultSites || settings.isForceSafeSearchEnabled else { return }
            
            DispatchQueue.global(qos: .background).async {
                let isActive = HostBlockerService.shared.isFamilyDNSActive()
                if !isActive {
                    // Se detectó desconexión o manipulación del DNS: Restaurar automáticamente
                    HostBlockerService.shared.applyFamilyDNS()
                    
                    // Si el partner está configurado y no se ha enviado alerta en este ciclo, notificar
                    DispatchQueue.main.async {
                        if !self.wasDnsAlertSentForCurrentTamper {
                            self.wasDnsAlertSentForCurrentTamper = true
                            let partnerEmail = settings.officialPartnerEmail
                            if !partnerEmail.isEmpty {
                                EmailService.shared.sendTamperAlert(
                                    toEmail: partnerEmail,
                                    actionDetail: "Se detectó que los servidores DNS seguros de protección Cloudflare Families (1.1.1.3) fueron desconectados o modificados en las preferencias de red de macOS. FocusPanic restauró la protección de inmediato a nivel de sistema."
                                )
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.wasDnsAlertSentForCurrentTamper = false
                    }
                }
            }
        }
    }
    
    // MARK: - 4. Rastreador Pasivo 24/7 de Tiempo en Pantalla & Visitas
    private var lastActiveSocialDomain: String?
    private var lastSocialSampleTime: Date = Date()
    
    private func trackActiveSocialUsage(runningBundleIds: Set<String>) {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontBundleId = frontApp?.bundleIdentifier ?? ""
        
        var currentUrl: String?
        
        if frontBundleId == "com.apple.Safari" {
            currentUrl = getActiveSafariTabUrl()
        } else if frontBundleId == "com.google.Chrome" {
            currentUrl = getActiveChromiumTabUrl(appName: "Google Chrome")
        } else if frontBundleId == "com.brave.Browser" {
            currentUrl = getActiveChromiumTabUrl(appName: "Brave Browser")
        } else if frontBundleId == "company.thebrowser.Arc" {
            currentUrl = getActiveChromiumTabUrl(appName: "Arc")
        } else if frontBundleId == "com.microsoft.edgemac" {
            currentUrl = getActiveChromiumTabUrl(appName: "Microsoft Edge")
        } else if frontBundleId == "com.operasoftware.Opera" {
            currentUrl = getActiveChromiumTabUrl(appName: "Opera")
        } else if frontBundleId == "com.vivaldi.Vivaldi" {
            currentUrl = getActiveChromiumTabUrl(appName: "Vivaldi")
        } else if frontBundleId == "com.anthropic.claudefordesktop" {
            currentUrl = "https://claude.ai"
        } else if frontBundleId == "com.google.GeminiMacOS" {
            currentUrl = "https://gemini.google.com"
        } else if frontBundleId == "com.openai.chat" {
            currentUrl = "https://chatgpt.com"
        }
        
        guard let url = currentUrl, !url.isEmpty, !url.contains("127.0.0.1:8484") else {
            lastActiveSocialDomain = nil
            return
        }
        
        let lowerUrl = url.lowercased()
        let isSocialOrDistraction = lowerUrl.contains("instagram.com") ||
                                    lowerUrl.contains("tiktok.com") ||
                                    lowerUrl.contains("youtube.com") ||
                                    lowerUrl.contains("twitter.com") ||
                                    lowerUrl.contains("://x.com") ||
                                    lowerUrl.contains(".x.com") ||
                                    lowerUrl.contains("/x.com") ||
                                    lowerUrl.contains("reddit.com") ||
                                    lowerUrl.contains("facebook.com") ||
                                    lowerUrl.contains("netflix.com") ||
                                    lowerUrl.contains("twitch.tv") ||
                                    lowerUrl.contains("threads.net") ||
                                    lowerUrl.contains("discord.com")
        
        if isSocialOrDistraction {
            let matchedSocial = FocusStatsManager.shared.cleanSourceName(lowerUrl)
            let isNewVisit = (lastActiveSocialDomain != matchedSocial)
            let elapsed = Int(Date().timeIntervalSince(lastSocialSampleTime))
            let secondsToAdd = (isNewVisit || elapsed > 10) ? 1 : max(1, min(elapsed, 3))
            
            FocusStatsManager.shared.recordSocialActivity(
                source: matchedSocial,
                seconds: secondsToAdd,
                isNewVisit: isNewVisit
            )
            
            lastActiveSocialDomain = matchedSocial
            lastSocialSampleTime = Date()
            
            // Verificación de Límites de Tiempo Diarios & Aviso de 1 Minuto
            DispatchQueue.main.async {
                guard FocusEngine.shared.settings.isAppLimitsEnabled else { return }
                let today = FocusStatsManager.shared.todayString
                let todayUsageSecs = FocusStatsManager.shared.stats.dailyRecords[today]?.socialUsage[matchedSocial]?.totalSeconds ?? 0
                
                for limit in FocusEngine.shared.settings.appLimits where limit.isEnabled {
                    let limitSource = FocusStatsManager.shared.cleanSourceName(limit.name.isEmpty ? limit.identifier : limit.name)
                    if limitSource == matchedSocial || lowerUrl.contains(limit.identifier.lowercased()) {
                        let limitSecs = limit.limitMinutes * 60
                        let remainingSecs = limitSecs - todayUsageSecs
                        
                        if remainingSecs <= 60 && remainingSecs > 0 {
                            FocusEngine.shared.triggerOneMinuteLimitWarning(for: matchedSocial, limitMinutes: limit.limitMinutes)
                        } else if remainingSecs <= 0 {
                            FocusEngine.shared.applyPermanentProtectionOnly()
                        }
                    }
                }
            }
        } else {
            lastActiveSocialDomain = nil
        }
    }
    
    private func getActiveSafariTabUrl() -> String? {
        let script = "tell application \"Safari\" to try\nreturn URL of current tab of front window\nend try\nreturn \"\""
        if let s = NSAppleScript(source: script) {
            var err: NSDictionary?
            let res = s.executeAndReturnError(&err)
            return res.stringValue
        }
        return nil
    }
    
    private func getActiveChromiumTabUrl(appName: String) -> String? {
        let script = "tell application \"\(appName)\" to try\nreturn URL of active tab of front window\nend try\nreturn \"\""
        if let s = NSAppleScript(source: script) {
            var err: NSDictionary?
            let res = s.executeAndReturnError(&err)
            return res.stringValue
        }
        return nil
    }
}
