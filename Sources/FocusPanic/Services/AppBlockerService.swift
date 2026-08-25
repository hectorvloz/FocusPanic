import AppKit
import Foundation
import UserNotifications

public final class AppBlockerService {
    public static let shared = AppBlockerService()
    
    private var isMonitoring = false
    private var blockedBundleIds = Set<String>()
    private var blockedAppNames = Set<String>()
    private var timer: Timer?
    private var launchObserver: NSObjectProtocol?
    
    private init() {}
    
    /// Inicia la vigilancia activa de aplicaciones bloqueadas
    public func startMonitoring(blockedApps: [BlockedApp]) {
        self.blockedBundleIds = Set(blockedApps.filter { $0.isEnabled }.map { $0.bundleIdentifier.lowercased() })
        self.blockedAppNames = Set(blockedApps.filter { $0.isEnabled }.map { $0.appName.lowercased() })
        
        guard !blockedBundleIds.isEmpty || !blockedAppNames.isEmpty else { return }
        
        self.isMonitoring = true
        
        // 1. Cerrar inmediatamente las que ya estén abiertas
        terminateRunningBlockedApps()
        
        // 2. Escuchar cuando se abra una nueva app
        if launchObserver == nil {
            launchObserver = NSWorkspace.shared.notificationCenter.addObserver(
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
        
        // 3. Revisión periódica en caso de que alguna se quede en segundo plano
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.terminateRunningBlockedApps()
        }
    }
    
    /// Detiene la vigilancia de aplicaciones
    public func stopMonitoring() {
        self.isMonitoring = false
        timer?.invalidate()
        timer = nil
        if let observer = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            launchObserver = nil
        }
    }
    
    private func terminateRunningBlockedApps() {
        guard isMonitoring else { return }
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            checkAndTerminate(app: app)
        }
    }
    
    private func checkAndTerminate(app: NSRunningApplication) {
        guard isMonitoring else { return }
        
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        
        let shouldBlock = blockedBundleIds.contains(bundleId) ||
                          blockedAppNames.contains(name) ||
                          blockedAppNames.contains(where: { !name.isEmpty && name.contains($0) })
        
        if shouldBlock {
            // Intentar terminar suavemente o forzar
            app.terminate()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !app.isTerminated {
                    app.forceTerminate()
                }
            }
            
            sendInterventionNotification(appName: app.localizedName ?? "Aplicación")
        }
    }
    
    private func sendInterventionNotification(appName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🧘 FocusPanic: Modo Enfoque Activo"
        content.body = "Se ha pausado '\(appName)' para proteger tu atención. ¡Tú puedes lograr tu objetivo!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
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
                    
                    if !seenBundleIds.contains(bundleId) {
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
