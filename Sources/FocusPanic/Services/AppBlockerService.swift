import AppKit
import Foundation
import UserNotifications

public final class AppBlockerService {
    public static let shared = AppBlockerService()
    
    private var isMonitoring = false
    private var blockedBundleIds = Set<String>()
    private var blockedNames = Set<String>()
    private var blockedKeywords = Set<String>()
    
    private var timer: Timer?
    private var launchObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?
    private var lastInterventionNotificationTimes: [String: Date] = [:]
    
    private init() {}
    
    /// Inicia la vigilancia activa de aplicaciones bloqueadas
    public func startMonitoring(blockedApps: [BlockedApp]) {
        var bundleIds = Set<String>()
        var names = Set<String>()
        var keywords = Set<String>()
        
        for app in blockedApps {
            let bId = app.bundleIdentifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let name = app.appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !bId.isEmpty {
                bundleIds.insert(bId)
            }
            if !name.isEmpty {
                names.insert(name)
                // Extraer palabra clave raíz (ej. "Telegram" -> "telegram", "Mail de Apple" -> "mail")
                let rootWords = name.components(separatedBy: CharacterSet.alphanumerics.inverted)
                    .filter { $0.count >= 3 && $0 != "app" && $0 != "apple" && $0 != "mac" }
                for word in rootWords {
                    keywords.insert(word.lowercased())
                }
            }
        }
        
        self.blockedBundleIds = bundleIds
        self.blockedNames = names
        self.blockedKeywords = keywords
        
        guard !blockedBundleIds.isEmpty || !blockedNames.isEmpty else {
            stopMonitoring()
            return
        }
        
        self.isMonitoring = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 1. Cerrar inmediatamente todas las que ya estén abiertas
            self.terminateRunningBlockedApps()
            
            // 2. Escuchar cuando se abra o active una app
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
            
            // 3. Revisión periódica de alta velocidad (cada 0.4s)
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
                self?.terminateRunningBlockedApps()
            }
        }
    }
    
    /// Detiene la vigilancia de aplicaciones
    public func stopMonitoring() {
        self.isMonitoring = false
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
    }
    
    public func terminateRunningBlockedApps() {
        guard isMonitoring else { return }
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            checkAndTerminate(app: app)
        }
    }
    
    private func checkAndTerminate(app: NSRunningApplication) {
        guard isMonitoring else { return }
        
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        let localizedName = app.localizedName?.lowercased() ?? ""
        let bundleName = app.bundleURL?.lastPathComponent.lowercased().replacingOccurrences(of: ".app", with: "") ?? ""
        let execName = app.executableURL?.lastPathComponent.lowercased() ?? ""
        
        // No bloquear la propia FocusPanic ni Finder
        if bundleId == "com.focuspanic.mac" || bundleId == "com.apple.finder" || bundleId == "com.apple.systemevents" {
            return
        }
        
        var isBlocked = false
        
        // 1. Coincidencia por Bundle ID exacto
        if !bundleId.isEmpty && blockedBundleIds.contains(bundleId) {
            isBlocked = true
        }
        
        // 2. Coincidencia por Bundle ID parcial
        if !isBlocked && !bundleId.isEmpty {
            for bId in blockedBundleIds {
                if bundleId.contains(bId) || bId.contains(bundleId) {
                    isBlocked = true
                    break
                }
            }
        }
        
        // 3. Coincidencia por Nombre de App o Nombre de Bundle
        if !isBlocked {
            for name in blockedNames {
                if (!localizedName.isEmpty && localizedName == name) ||
                   (!bundleName.isEmpty && bundleName == name) ||
                   (!execName.isEmpty && execName == name) ||
                   (!localizedName.isEmpty && localizedName.contains(name)) ||
                   (!bundleName.isEmpty && bundleName.contains(name)) {
                    isBlocked = true
                    break
                }
            }
        }
        
        // 4. Coincidencia por Palabras Clave de la App (ej. discord, telegram, whatsapp, slack, steam, spotify)
        if !isBlocked {
            for kw in blockedKeywords {
                if (!localizedName.isEmpty && localizedName.contains(kw)) ||
                   (!bundleName.isEmpty && bundleName.contains(kw)) ||
                   (!bundleId.isEmpty && bundleId.contains(kw)) ||
                   (!execName.isEmpty && execName.contains(kw)) {
                    isBlocked = true
                    break
                }
            }
        }
        
        if isBlocked {
            // Terminar instantáneamente
            app.forceTerminate()
            
            let displayName = app.localizedName ?? bundleName.capitalized
            let appKey = displayName.lowercased()
            
            let now = Date()
            let lastTime = lastInterventionNotificationTimes[appKey] ?? Date.distantPast
            if now.timeIntervalSince(lastTime) > 3.0 {
                lastInterventionNotificationTimes[appKey] = now
                sendInterventionNotification(appName: displayName)
            }
        }
    }
    
    private func sendInterventionNotification(appName: String) {
        FocusStatsManager.shared.recordInterception(
            source: appName,
            category: "app",
            detail: "Aplicación cerrada"
        )
        
        SoundService.shared.play("Basso")
        
        NotificationService.shared.sendNotification(
            title: "🛑 Aplicación Bloqueada",
            body: "FocusPanic cerró '\(appName)' para proteger tu atención y enfoque.",
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
        return results.sorted { $0.appName.localizedCompare($1.appName) == .orderedAscending }
    }
}
