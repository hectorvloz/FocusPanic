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
    // `.utility`: trabajo de fondo continuo; macOS puede usar núcleos de
    // eficiencia en vez de los de rendimiento (impacto energético).
    private let watchdogQueue = DispatchQueue(label: "com.hector.FocusPanic.browserWatchdog", qos: .utility)
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
        watchdogQueue.async { self.cachedRules = [:]; self.cachedNativeMatcher = nil }
        
        stop()
        isRunning = true
        
        // Interceptación instantánea al iniciar
        checkAndInterceptTabs()
        
        DispatchQueue.main.async {
            // Monitoreo continuo ultra-responsivo cada 0.85 segundos
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { [weak self] _ in
                self?.checkAndInterceptTabs()
            }
            // Margen para que macOS agrupe los despertares con otros eventos
            // (menos impacto energético) sin perder la reacción < 1 s.
            self.timer?.tolerance = 0.2
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
        watchdogQueue.async { self.cachedRules = [:]; self.cachedNativeMatcher = nil }
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
            
            // 1. Escudo Anti-Modo Incógnito / Ventanas Privadas: se detecta con
            // la misma lectura de pestañas del paso 3 (un AppleScript por
            // navegador y pasada en vez de tres).

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
            
            var closedIncognito = false
            var activeTabURLs: [String: String] = [:]
            for config in browserConfigs where runningBundleIds.contains(config.bundleId) {
                var snapshot = self.readTabs(appName: config.appName, isSafariLike: config.isSafariLike)
                if self.isAntiIncognitoEnabled && Self.incognitoBundleIds.contains(config.bundleId)
                    && !snapshot.incognitoWindows.isEmpty
                    && self.closeIncognitoWindows(appName: config.appName, isSafariLike: config.isSafariLike) {
                    closedIncognito = true
                    // Cerrar ventanas cambia los índices: se vuelve a leer.
                    snapshot = self.readTabs(appName: config.appName, isSafariLike: config.isSafariLike)
                }
                activeTabURLs[config.bundleId] = self.enforceTabs(
                    appName: config.appName, isSafariLike: config.isSafariLike, snapshot: snapshot
                )
            }
            if closedIncognito {
                self.notifyIncognitoBlocked()
            }

            // 3. Vigilante Nativo de WebViews y Navegadores Integrados (Claude, Electron, PWAs)
            self.inspectNativeWebAreas(runningApps: runningApps)

            // 4. Rastreo Pasivo 24/7 de Tiempo y Visitas en Redes Sociales
            self.trackActiveSocialUsage(runningBundleIds: runningBundleIds, activeTabURLs: activeTabURLs)
        }
    }
    
    // MARK: - 1. Escudo Anti-Incógnito Multi-Navegador
    
    /// Navegadores en los que se cierran las ventanas privadas (los mismos que
    /// antes revisaba `enforceAntiIncognito`, más Safari Technology Preview
    /// aunque Safari también esté abierto).
    static let incognitoBundleIds: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview",
        "com.google.Chrome", "com.google.Chrome.canary",
        "com.brave.Browser", "com.brave.Browser.beta",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Dev",
        "company.thebrowser.Arc", "com.operasoftware.Opera", "com.operasoftware.OperaGX",
        "com.vivaldi.Vivaldi", "org.chromium.Chromium",
    ]

    /// Cierra las ventanas privadas. Solo se llama cuando la lectura de
    /// pestañas ya vio alguna, así que normalmente no se ejecuta.
    private func closeIncognitoWindows(appName: String, isSafariLike: Bool) -> Bool {
        guard isSafariLike else { return closeChromiumIncognito(appName: appName) }
        let safariIncogScript = """
        tell application "\(appName)"
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
        return (runScript(safariIncogScript)?.int32Value ?? 0) > 0
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
        return (runScript(scriptSource)?.int32Value ?? 0) > 0
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
    
    // MARK: - 2. Reglas de pestañas (Safari, WebKit y Chromium)
    //
    // Antes, cada pasada compilaba y ejecutaba un AppleScript enorme por
    // navegador que hacía TODAS las comparaciones (lentas en AppleScript) y,
    // con el escudo de adultos, leía el texto completo de cada pestaña. Una
    // pasada sobre Safari tardaba más de 3 s y, con el temporizador a 0,85 s,
    // FocusPanic quedaba a ~95 % de CPU sin descanso.
    //
    // Ahora: un script precompilado solo LEE URL y título de las pestañas, las
    // reglas se evalúan en Swift (`BrowserTabRules`, misma semántica) y solo se
    // vuelve a AppleScript para redirigir una pestaña bloqueada. El texto de la
    // página se lee únicamente de la pestaña activa y de las que acaban de
    // cambiar de URL, como mucho cada 3 s por pestaña.

    struct BrowserTab {
        let window: Int
        let index: Int
        let url: String
        let title: String
    }

    /// Lo que devuelve una lectura de pestañas de un navegador.
    struct TabSnapshot {
        var tabs: [BrowserTab] = []
        /// Pestaña activa de la ventana 1 (la del frente); 0 si no se sabe.
        var activeIndex = 0
        /// Ventanas privadas / de incógnito.
        var incognitoWindows: [Int] = []

        /// URL de la pestaña activa de la ventana del frente, si se conoce.
        var activeTabURL: String? {
            guard activeIndex > 0 else { return nil }
            return tabs.first { $0.window == 1 && $0.index == activeIndex }?.url
        }
    }

    private var compiledScripts: [String: NSAppleScript] = [:]
    private var cachedRules: [String: BrowserTabRules] = [:]
    private var tabSeenURL: [String: String] = [:]
    private var tabSeenSince: [String: Date] = [:]
    private var tabTextCheckedAt: [String: Date] = [:]

    /// AppleScript compilado una sola vez y reutilizado en cada pasada.
    private func compiledScript(_ source: String) -> NSAppleScript? {
        if let cached = compiledScripts[source] { return cached }
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        script.compileAndReturnError(&error)
        compiledScripts[source] = script
        return script
    }

    private func runScript(_ source: String, cached: Bool = true) -> NSAppleEventDescriptor? {
        let script = cached ? compiledScript(source) : NSAppleScript(source: source)
        var error: NSDictionary?
        return script?.executeAndReturnError(&error)
    }

    private func currentRules(whitelist: Bool) -> BrowserTabRules {
        let key = whitelist ? "whitelist" : "rules"
        if let rules = cachedRules[key] { return rules }
        let isTeraBoxStrict = self.isAdultShieldEnabled
            || self.blockedKeywords.contains("terabox")
            || self.blockedDomains.contains(where: { $0.contains("terabox") })
        let keywordsActive = self.isKeywordBlockerEnabled || self.isAdultShieldEnabled
        let rules = BrowserTabRules(
            mode: whitelist ? .whitelist : .rules,
            allowed: Array(buildAllowedSet()),
            blocked: whitelist ? [] : self.blockedDomains,
            keywords: keywordsActive ? self.blockedKeywords : [],
            isTeraBoxStrict: isTeraBoxStrict
        )
        cachedRules[key] = rules
        return rules
    }

    static func tabListScript(appName: String, isSafariLike: Bool) -> String {
        let titleProperty = isSafariLike ? "name" : "title"
        let activeExpression = isSafariLike ? "index of current tab of window 1" : "active tab index of window 1"
        let privateExpression = isSafariLike ? "(«class pmnd» of window wi) is true" : "(mode of window wi) is \"incognito\""
        // OJO: dentro de `tell application` la palabra `tab` es la CLASE pestaña
        // del navegador, no el carácter tabulador. El separador se define fuera
        // (antes se escribía la palabra «tab» y no se reconocía ninguna pestaña).
        return """
        set sep to (character id 9)
        set nl to (character id 10)
        set out to ""
        tell application "\(appName)"
            try
                set activeIndex to 0
                try
                    set activeIndex to \(activeExpression)
                end try
                set out to "ACTIVE" & sep & (activeIndex as text) & nl
                repeat with wi from 1 to (count of windows)
                    try
                        if \(privateExpression) then set out to out & "PRIVATE" & sep & (wi as text) & nl
                    end try
                    try
                        set tabURLs to URL of every tab of window wi
                        set tabTitles to \(titleProperty) of every tab of window wi
                        repeat with ti from 1 to (count of tabURLs)
                            set u to item ti of tabURLs
                            set n to item ti of tabTitles
                            if u is missing value then set u to ""
                            if n is missing value then set n to ""
                            set out to out & (wi as text) & sep & (ti as text) & sep & u & sep & n & nl
                        end repeat
                    end try
                end repeat
            end try
        end tell
        return out
        """
    }

    private func readTabs(appName: String, isSafariLike: Bool) -> TabSnapshot {
        Self.parseTabList(runScript(Self.tabListScript(appName: appName, isSafariLike: isSafariLike))?.stringValue ?? "")
    }

    static func parseTabList(_ raw: String) -> TabSnapshot {
        var snapshot = TabSnapshot()
        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            if parts.first == "ACTIVE", parts.count >= 2 {
                snapshot.activeIndex = Int(parts[1]) ?? 0
                continue
            }
            if parts.first == "PRIVATE", parts.count >= 2 {
                if let window = Int(parts[1]) { snapshot.incognitoWindows.append(window) }
                continue
            }
            guard parts.count == 4, let window = Int(parts[0]), let index = Int(parts[1]) else { continue }
            snapshot.tabs.append(BrowserTab(window: window, index: index, url: parts[2], title: parts[3]))
        }
        return snapshot
    }

    private func redirectTab(appName: String, tab: BrowserTab, to url: String) {
        let source = "tell application \"\(appName)\" to set URL of tab \(tab.index) of window \(tab.window) to \"\(sanitizeForAppleScript(url))\""
        _ = runScript(source, cached: false)
    }

    /// ¿Toca leer el texto de esta pestaña? Solo la activa y las que acaban de
    /// navegar (15 s, para cubrir la carga), como mucho cada 3 s.
    private func shouldReadPageText(key: String, url: String, isActive: Bool, now: Date) -> Bool {
        if tabSeenURL[key] != url {
            tabSeenURL[key] = url
            tabSeenSince[key] = now
            tabTextCheckedAt[key] = .distantPast
        }
        let recentlyChanged = now.timeIntervalSince(tabSeenSince[key] ?? .distantPast) < 15
        guard isActive || recentlyChanged else { return false }
        guard now.timeIntervalSince(tabTextCheckedAt[key] ?? .distantPast) >= 3 else { return false }
        tabTextCheckedAt[key] = now
        return true
    }

    private func readPageText(appName: String, tab: BrowserTab) -> String {
        let source = "tell application \"\(appName)\" to try\nreturn text of tab \(tab.index) of window \(tab.window)\nend try\nreturn \"\""
        return runScript(source, cached: false)?.stringValue ?? ""
    }

    /// Aplica las reglas a las pestañas leídas y devuelve la URL de la pestaña
    /// activa del frente tal como queda tras redirigir (para las estadísticas
    /// de uso, sin otro AppleScript).
    @discardableResult
    private func enforceTabs(appName: String, isSafariLike: Bool, snapshot: TabSnapshot) -> String? {
        let rules = currentRules(whitelist: self.isWhitelistMode)
        let now = Date()
        var activeTabURL = snapshot.activeTabURL
        var firstDecision: BrowserTabRules.Decision?
        var liveKeys = Set<String>()

        for tab in snapshot.tabs {
            guard BrowserTabRules.shouldInspect(url: tab.url, isSafariLike: isSafariLike) else { continue }
            var decision = rules.evaluate(url: tab.url, title: tab.title)

            // TeraBox en el contenido de la página (solo WebKit expone el texto).
            if decision == nil && isSafariLike && rules.isTeraBoxStrict {
                let key = "\(appName)|\(tab.window)|\(tab.index)"
                liveKeys.insert(key)
                let isActive = tab.window == 1 && tab.index == snapshot.activeIndex
                if shouldReadPageText(key: key, url: tab.url, isActive: isActive, now: now) {
                    decision = rules.evaluatePageText(readPageText(appName: appName, tab: tab))
                }
            }

            if let decision {
                let interventionURL = BrowserTabRules.interventionURL(for: decision)
                redirectTab(appName: appName, tab: tab, to: interventionURL)
                if tab.window == 1 && tab.index == snapshot.activeIndex { activeTabURL = interventionURL }
                if firstDecision == nil { firstDecision = decision }
            }
        }

        // Olvidar pestañas que ya no existen.
        if isSafariLike {
            let prefix = "\(appName)|"
            for key in tabSeenURL.keys where key.hasPrefix(prefix) && !liveKeys.contains(key) {
                tabSeenURL[key] = nil
                tabSeenSince[key] = nil
                tabTextCheckedAt[key] = nil
            }
        }

        if let decision = firstDecision {
            notifyInterception(domain: decision.reported, sourceApp: appName, isWhitelist: rules.mode == .whitelist)
        }
        return activeTabURL
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
    
    private var lastNativeInspection: Date = .distantPast

    private func inspectNativeWebAreas(runningApps: [NSRunningApplication]) {
        guard self.isKeywordBlockerEnabled || !self.blockedDomains.isEmpty || self.isAdultShieldEnabled else { return }
        // Recorrer el árbol de accesibilidad (hasta 16 niveles) de VS Code,
        // Claude, ChatGPT… obliga a esas apps a construirlo y gasta CPU en
        // ellas también. Cada 3 s basta para estas apps (los navegadores se
        // siguen revisando en cada pasada).
        let now = Date()
        guard now.timeIntervalSince(lastNativeInspection) >= 3 else { return }
        lastNativeInspection = now
        
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
                
                if let cleanBlocked = firstBlockedDomain(lowerUrl) {
                    handleNativeWebAreaInterception(app: app, reason: cleanBlocked, url: activeUrl)
                    return
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
        
        // Título, valor, URL e hijos en una sola llamada (antes, cuatro).
        let values = copyAttributes(element, [kAXTitleAttribute as String, kAXValueAttribute as String, "AXURL", kAXChildrenAttribute as String])
        if let title = values[0] as? String, !title.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(title) {
            count += 1
            return
        }
        if let val = values[1] as? String, !val.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(val) {
            count += 1
            return
        }
        if let urlStr = (values[2] as? String) ?? ((values[2] as? URL)?.absoluteString), !urlStr.isEmpty, AdultBlockListProvider.containsTeraBoxSignature(urlStr) {
            count += 1
            return
        }
        if let children = values[3] as? [AXUIElement] {
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
    
    /// Reglas para apps con WebViews (Claude, ChatGPT, VS Code…), preparadas
    /// una sola vez por cambio de ajustes en vez de por cada elemento.
    private struct NativeTextMatcher {
        enum KeywordKind { case substring, token }
        let isTeraBoxStrict: Bool
        let keywords: [(keyword: String, kind: KeywordKind)]
        let blocked: [String]
        let blockedIndex: DomainIndex

        /// Misma semántica que `matchesKeywordToken`, pero cada texto se pasa a
        /// minúsculas y se parte en palabras UNA vez (antes: una vez por palabra
        /// clave, 37 veces por elemento). Respeta el orden de las palabras clave.
        func firstKeyword(in texts: [String]) -> String? {
            guard !keywords.isEmpty else { return nil }
            let lowered = texts.filter { !$0.isEmpty }.map { $0.lowercased() }
            guard !lowered.isEmpty else { return nil }
            var tokenSets: [Set<String>]?
            for entry in keywords {
                switch entry.kind {
                case .substring:
                    if lowered.contains(where: { $0.contains(entry.keyword) }) { return entry.keyword }
                case .token:
                    if tokenSets == nil {
                        tokenSets = lowered.map {
                            Set($0.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
                        }
                    }
                    if tokenSets!.contains(where: { $0.contains(entry.keyword) }) { return entry.keyword }
                }
            }
            return nil
        }
    }

    private var cachedNativeMatcher: NativeTextMatcher?

    private func nativeMatcher() -> NativeTextMatcher {
        if let matcher = cachedNativeMatcher { return matcher }
        let keywordsActive = self.isKeywordBlockerEnabled || self.isAdultShieldEnabled
        let keywords: [(keyword: String, kind: NativeTextMatcher.KeywordKind)] = keywordsActive
            ? self.blockedKeywords.compactMap { kw in
                let clean = kw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                guard clean.count >= 2 else { return nil }
                let substring = AdultBlockListProvider.containsTeraBoxSignature(clean) || clean.contains(" ")
                return (clean, substring ? .substring : .token)
            }
            : []
        let blocked = self.blockedDomains
            .map { $0.lowercased().replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let matcher = NativeTextMatcher(
            isTeraBoxStrict: self.isAdultShieldEnabled
                || self.blockedKeywords.contains("terabox")
                || self.blockedDomains.contains(where: { $0.contains("terabox") }),
            keywords: keywords,
            blocked: blocked,
            blockedIndex: DomainIndex(items: blocked) { item in
                Self.instanceFragments.contains(where: { item.contains($0) }) || !item.contains(".")
            }
        )
        cachedNativeMatcher = matcher
        return matcher
    }

    /// Primer dominio bloqueado (en el orden de la lista) que coincide con la
    /// URL según `matchesDomainOrInstance`, usando el índice en vez de recorrer
    /// los ~1.200 dominios uno a uno.
    private func firstBlockedDomain(_ lowerUrl: String) -> String? {
        let matcher = nativeMatcher()
        // `matchesDomainOrInstance` da positivo con CUALQUIER elemento si la URL
        // es de TeraBox (salvo SSO): se conserva devolviendo el primero.
        let isSSO = lowerUrl.contains("accounts.youtube.com") || lowerUrl.contains("accounts.google.com")
            || lowerUrl.contains("/setsid") || lowerUrl.contains("/set_sid")
        if !isSSO && (lowerUrl.contains("terabox") || lowerUrl.contains("1024tera") || lowerUrl.contains("freeterabox")) {
            return matcher.blocked.first
        }
        return matcher.blockedIndex.firstMatch(in: lowerUrl) { matchesDomainOrInstance(targetURL: lowerUrl, domainItem: $0) }
    }
    
    /// Varios atributos en UNA llamada al otro proceso (antes, una por atributo).
    private func copyAttributes(_ element: AXUIElement, _ names: [String]) -> [AnyObject?] {
        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(
            element, names as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values
        )
        guard result == .success, let array = values as [AnyObject]?, array.count == names.count else {
            return Array(repeating: nil, count: names.count)
        }
        return array.map { value -> AnyObject? in
            // Un atributo ausente llega como AXValue de error.
            if CFGetTypeID(value) == AXValueGetTypeID(), AXValueGetType(value as! AXValue) == .axError { return nil }
            return value
        }
    }

    private func inspectElementHierarchy(_ element: AXUIElement, app: NSRunningApplication, depth: Int) {
        guard depth < 16 else { return }
        let matcher = nativeMatcher()

        let base = copyAttributes(element, [kAXRoleAttribute as String, kAXChildrenAttribute as String])
        let role = (base[0] as? String) ?? ""
        
        if role == "AXWebArea" || role.contains("Web") || role == "AXTextField" || role == "AXStaticText" || role == "AXLink" || role == "AXHeading" {
            let details = copyAttributes(element, [kAXTitleAttribute as String, "AXURL", kAXValueAttribute as String])
            let title = (details[0] as? String) ?? ""
            let urlString = (details[1] as? String) ?? ((details[1] as? URL)?.absoluteString ?? "")
            let valText = (details[2] as? String) ?? ""
            
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
            if matcher.isTeraBoxStrict {
                if AdultBlockListProvider.containsTeraBoxSignature(title) ||
                   AdultBlockListProvider.containsTeraBoxSignature(urlString) ||
                   AdultBlockListProvider.containsTeraBoxSignature(valText) {
                    handleNativeWebAreaInterception(app: app, reason: "TeraBox Detectado", url: urlString)
                    return
                }
            }
            
            // 1. Verificación de Palabras Prohibidas (Tokenización de palabras completas)
            if let keyword = matcher.firstKeyword(in: [title, urlString, valText]) {
                handleNativeWebAreaInterception(app: app, reason: "Búsqueda: \(keyword)", url: urlString)
                return
            }
            
            // 2. Verificación de Dominios Bloqueados e Instancias (redlib, pornhub, etc.)
            let lowerUrl = urlString.lowercased()
            if !lowerUrl.isEmpty && !lowerUrl.starts(with: "file:") {
                if let cleanBlocked = firstBlockedDomain(lowerUrl) {
                    handleNativeWebAreaInterception(app: app, reason: cleanBlocked, url: urlString)
                    return
                }
            }
        }
        
        if let children = base[1] as? [AXUIElement] {
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
    
    private static let instanceFragments = [
        "terabox", "1024tera", "4funbox", "mirrobox", "nephobox", "freeterabox", "tibibox",
        "terashare", "terafileshare", "teradownload", "teraboxdl", "teraboxdownloader",
        "teradl", "teradrive", "terasaver", "terafast", "teraboxlink",
        "redlib", "libreddit", "teddit", "nitter", "proxitok", "invidious", "piped"
    ]
    
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
        
        if Self.instanceFragments.contains(where: { domainItem.contains($0) }) || !domainItem.contains(".") {
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
    
    /// `activeTabURLs`: URL de la pestaña activa de cada navegador leída en
    /// esta misma pasada. Si está, se usa en vez de preguntar otra vez al
    /// navegador con AppleScript.
    private func trackActiveSocialUsage(runningBundleIds: Set<String>, activeTabURLs: [String: String] = [:]) {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontBundleId = frontApp?.bundleIdentifier ?? ""
        
        var currentUrl: String?
        
        if Self.socialTrackedBrowsers.contains(frontBundleId), let known = activeTabURLs[frontBundleId] {
            currentUrl = known
        } else if frontBundleId == "com.apple.Safari" {
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
    
    /// Navegadores cuyo tiempo en redes sociales se mide (los de la cadena de
    /// `if` de `trackActiveSocialUsage`).
    private static let socialTrackedBrowsers: Set<String> = [
        "com.apple.Safari", "com.google.Chrome", "com.brave.Browser", "company.thebrowser.Arc",
        "com.microsoft.edgemac", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
    ]

    private func getActiveSafariTabUrl() -> String? {
        let script = "tell application \"Safari\" to try\nreturn URL of current tab of front window\nend try\nreturn \"\""
        return runScript(script)?.stringValue
    }
    
    private func getActiveChromiumTabUrl(appName: String) -> String? {
        let script = "tell application \"\(appName)\" to try\nreturn URL of active tab of front window\nend try\nreturn \"\""
        return runScript(script)?.stringValue
    }
}
