import AppKit
import Foundation
import UserNotifications

public final class AppBlockerService {
    public static let shared = AppBlockerService()
    
    private var isMonitoring = false
    private var isWhitelistMode = false
    private var isAdultShieldActive = false
    
    private var blockedBundleIds = Set<String>()
    private var blockedNames = Set<String>()
    private var blockedKeywords = Set<String>()
    
    private var allowedBundleIds = Set<String>()
    private var allowedNames = Set<String>()
    
    private var timer: Timer?
    private var launchObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    private var lastInterventionNotificationTimes: [String: Date] = [:]
    
    // Apps esenciales del sistema que nunca deben terminarse
    private let systemProtectedBundleIds: Set<String> = [
        "com.focuspanic.mac",
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.dock.extra",
        "com.apple.systemevents",
        "com.apple.systemuiserver",
        "com.apple.windowmanager",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.spotlight",
        "com.apple.loginwindow",
        "com.apple.screencapture",
        "com.apple.wallpaper",
        "com.apple.wallpaper.agent",
        "com.apple.desktopscreenservices",
        "com.apple.quicklook",
        "com.apple.quicklook.ui.helper",
        "com.apple.coreservices.uiagent",
        "com.apple.keychaincircle",
        "com.apple.storeuid",
        "com.apple.siri",
        "com.apple.siri.launcher",
        "com.apple.airplay",
        "com.apple.menuextra"
    ]
    
    private init() {}
    
    /// Inicia la vigilancia activa de aplicaciones bloqueadas o modo Lista Blanca
    public func startMonitoring(
        blockedApps: [BlockedApp],
        allowedApps: [BlockedApp] = [],
        isWhitelistMode: Bool = false,
        isAdultShieldActive: Bool = false
    ) {
        self.isWhitelistMode = isWhitelistMode
        self.isAdultShieldActive = isAdultShieldActive
        
        var bundleIds = Set<String>()
        var names = Set<String>()
        
        for app in blockedApps {
            let bId = app.bundleIdentifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let name = app.appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !bId.isEmpty {
                bundleIds.insert(bId)
            }
            if !name.isEmpty {
                names.insert(name)
            }
        }
        
        self.blockedBundleIds = bundleIds
        self.blockedNames = names
        self.blockedKeywords.removeAll()
        
        var allowedIds = Set<String>()
        var allowedNms = Set<String>()
        for app in allowedApps where app.isEnabled {
            let bId = app.bundleIdentifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let name = app.appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !bId.isEmpty { allowedIds.insert(bId) }
            if !name.isEmpty { allowedNms.insert(name) }
        }
        self.allowedBundleIds = allowedIds
        self.allowedNames = allowedNms
        
        if !isWhitelistMode && blockedBundleIds.isEmpty && blockedNames.isEmpty {
            stopMonitoring()
            return
        }
        
        self.isMonitoring = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Cerrar inmediatamente todas las que no estén permitidas
            self.terminateRunningBlockedApps()
            
            // 2. Escuchar cuando se abra o active una app en primer plano
            if self.launchObserver == nil {
                self.launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didLaunchApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let self = self, self.isMonitoring else { return }
                    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                        self.checkAndTerminate(app: app)
                    }
                }
            }
            
            if self.activateObserver == nil {
                self.activateObserver = NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didActivateApplicationNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] notification in
                    guard let self = self, self.isMonitoring else { return }
                    if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                        self.checkAndTerminate(app: app)
                    }
                }
            }
            
            // 3. Revisión periódica cada 1.0s para apps de usuario en primer plano
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.terminateRunningBlockedApps()
            }
        }
    }
    
    /// Detiene la vigilancia de aplicaciones
    public func stopMonitoring() {
        self.isMonitoring = false
        self.isWhitelistMode = false
        self.timer?.invalidate()
        self.timer = nil
        
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.launchObserver = nil
        }
        if let observer = activateObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.activateObserver = nil
        }
        
        self.blockedBundleIds.removeAll()
        self.blockedNames.removeAll()
        self.blockedKeywords.removeAll()
        self.allowedBundleIds.removeAll()
        self.allowedNames.removeAll()
    }
    
    public func terminateRunningBlockedApps() {
        guard isMonitoring else { return }
        let running = NSWorkspace.shared.runningApplications
        for app in running where app.activationPolicy == .regular {
            checkAndTerminate(app: app)
        }
    }
    
    private func checkAndTerminate(app: NSRunningApplication) {
        guard isMonitoring else { return }
        
        // 0. Proteger FocusPanic y sus procesos
        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }
        
        // 1. REGLA FUNDAMENTAL: SOLO monitorear y bloquear aplicaciones de PRIMER PLANO (con UI regular de usuario)
        // Las aplicaciones y procesos en segundo plano (.accessory y .prohibited) como fondo de pantalla, dock plugins,
        // servicios de audio, helpers del sistema, utilidades de barra de menús, Creative Cloud background, etc. NUNCA se cierran.
        guard app.activationPolicy == .regular else {
            return
        }
        
        let bundleId = app.bundleIdentifier?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let localizedName = app.localizedName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bundleName = app.bundleURL?.lastPathComponent.lowercased().replacingOccurrences(of: ".app", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let execName = app.executableURL?.lastPathComponent.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // 2. Proteger FocusPanic y elementos esenciales del sistema operativo
        if bundleId.isEmpty || systemProtectedBundleIds.contains(bundleId) || bundleId == "com.focuspanic.mac" || bundleId.contains("focuspanic") {
            return
        }
        
        // Proteger componentes y servicios internos del sistema macOS
        if bundleId.hasPrefix("com.apple.wallpaper") ||
           bundleId.hasPrefix("com.apple.desktopscreenservices") ||
           bundleId.hasPrefix("com.apple.coreservices") ||
           bundleId.hasPrefix("com.apple.systemuiserver") ||
           bundleId.hasPrefix("com.apple.dock") ||
           bundleId.hasPrefix("com.apple.windowmanager") ||
           bundleId.hasPrefix("com.apple.controlcenter") ||
           bundleId.hasPrefix("com.apple.notificationcenter") ||
           bundleId.hasPrefix("com.apple.screencapture") ||
           bundleId.hasPrefix("com.apple.menuextra") ||
           bundleId.hasPrefix("com.apple.keychain") ||
           bundleId.hasPrefix("com.apple.inputmethod") ||
           bundleId.hasPrefix("com.apple.corelocation") ||
           bundleId.hasPrefix("com.apple.textinput") ||
           bundleId.hasPrefix("com.apple.pressandhold") ||
           bundleId.hasPrefix("com.apple.webkit") {
            return
        }
        
        var isBlocked = false
        
        // Bloqueo forzoso del Navegador DuckDuckGo si el Escudo Anti-Porn está activo
        if isAdultShieldActive {
            if bundleId == "com.duckduckgo.macos.browser" ||
               bundleId == "com.duckduckgo.mobile.ios" ||
               bundleId.contains("duckduckgo.macos.browser") ||
               localizedName == "duckduckgo" ||
               localizedName == "duckduckgo privacy browser" ||
               bundleName == "duckduckgo" ||
               execName == "duckduckgo" {
                isBlocked = true
            }
        }
        
        if !isBlocked && isWhitelistMode {
            // MODO LISTA BLANCA (BLOQUEO TOTAL): Solo se permiten apps de usuario explícitamente en la lista blanca
            var isExplicitlyAllowed = false
            
            if allowedBundleIds.contains(bundleId) {
                isExplicitlyAllowed = true
            }
            
            if !isExplicitlyAllowed {
                for aId in allowedBundleIds {
                    if bundleId == aId || (bundleId.count > 4 && bundleId.hasPrefix(aId)) {
                        isExplicitlyAllowed = true
                        break
                    }
                }
            }
            
            if !isExplicitlyAllowed {
                for aName in allowedNames {
                    if (!localizedName.isEmpty && localizedName == aName) ||
                       (!bundleName.isEmpty && bundleName == aName) ||
                       (!execName.isEmpty && execName == aName) {
                        isExplicitlyAllowed = true
                        break
                    }
                }
            }
            
            // Si es una aplicación regular de usuario no permitida, se bloquea
            if !isExplicitlyAllowed {
                isBlocked = true
            }
        } else {
            // MODO LISTA NEGRA: Se bloquean las apps configuradas explícitamente
            if blockedBundleIds.contains(bundleId) {
                isBlocked = true
            }
            
            if !isBlocked {
                for bId in blockedBundleIds {
                    if bundleId == bId || (bundleId.count > 4 && bundleId.hasPrefix(bId)) {
                        isBlocked = true
                        break
                    }
                }
            }
            
            if !isBlocked {
                for name in blockedNames {
                    if (!localizedName.isEmpty && localizedName == name) ||
                       (!bundleName.isEmpty && bundleName == name) ||
                       (!execName.isEmpty && execName == name) {
                        isBlocked = true
                        break
                    }
                }
            }
        }
        
        if isBlocked {
            // Terminar la aplicación de primer plano bloqueada
            app.forceTerminate()
            
            let displayName = app.localizedName ?? bundleName.capitalized
            let appKey = displayName.lowercased()
            
            let now = Date()
            let lastTime = lastInterventionNotificationTimes[appKey] ?? Date.distantPast
            if now.timeIntervalSince(lastTime) > 3.0 {
                lastInterventionNotificationTimes[appKey] = now
                sendInterventionNotification(appName: displayName, isWhitelist: isWhitelistMode)
            }
        }
    }
    
    private func sendInterventionNotification(appName: String, isWhitelist: Bool) {
        FocusStatsManager.shared.recordInterception(
            source: appName,
            category: "app",
            detail: isWhitelist ? "No permitida en Bloqueo Total" : "Aplicación cerrada"
        )
        
        SoundService.shared.play("Basso")
        
        let title = isWhitelist ? "🔒 Bloqueo Total Activo" : "🛑 Aplicación Bloqueada"
        let msg = isWhitelist
            ? "'\(appName)' no está en tu Lista Blanca. Solo las herramientas permitidas están habilitadas."
            : "FocusPanic cerró '\(appName)' para proteger tu atención y enfoque."
        
        NotificationService.shared.sendNotification(
            title: title,
            body: msg,
            sound: "Basso"
        )
    }
    
    /// Obtiene las aplicaciones instaladas en /Applications y /System/Applications para sugerir en configuración
    public static func discoverInstalledApplications() -> [BlockedApp] {
        var results: [BlockedApp] = []
        let searchPaths = ["/Applications", "/System/Applications", "/System/Applications/Utilities"]
        let fileManager = FileManager.default
        
        var seenBundleIds = Set<String>()
        
        for path in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let fullPath = (path as NSString).appendingPathComponent(item)
                let url = URL(fileURLWithPath: fullPath)
                if let bundle = Bundle(url: url) {
                    let bundleId = bundle.bundleIdentifier ?? item
                    let appName = (bundle.infoDictionary?["CFBundleDisplayName"] as? String) ??
                                  (bundle.infoDictionary?["CFBundleName"] as? String) ??
                                  item.replacingOccurrences(of: ".app", with: "")
                    
                    if !seenBundleIds.contains(bundleId) && bundleId != "com.focuspanic.mac" {
                        seenBundleIds.insert(bundleId)
                        results.append(BlockedApp(
                            bundleIdentifier: bundleId,
                            appName: appName,
                            appPath: fullPath,
                            isEnabled: false
                        ))
                    }
                }
            }
        }
        return results.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }
    
    /// Verifica si una aplicación está efectivamente instalada en el sistema
    public static func isAppInstalled(_ app: BlockedApp) -> Bool {
        if !app.appPath.isEmpty && FileManager.default.fileExists(atPath: app.appPath) {
            return true
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) != nil {
            return true
        }
        
        let targetClean = app.appName
            .replacingOccurrences(of: "\u{200E}", with: "")
            .replacingOccurrences(of: "\u{200F}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        let searchDirs = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "\(NSHomeDirectory())/Applications"
        ]
        
        let fileManager = FileManager.default
        for dir in searchDirs {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let itemClean = item
                    .replacingOccurrences(of: ".app", with: "")
                    .replacingOccurrences(of: "\u{200E}", with: "")
                    .replacingOccurrences(of: "\u{200F}", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                
                if itemClean == targetClean {
                    return true
                }
            }
        }
        return false
    }
}
