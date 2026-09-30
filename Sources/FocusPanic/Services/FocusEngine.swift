import Combine
import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct PendingPartnerOTP {
    public let code: String
    public let site: String
    public let minutes: Int
    public let createdAt: Date
    public let expiresAt: Date
    public var isUsed: Bool
    
    public init(code: String, site: String, minutes: Int, createdAt: Date = Date(), expiresAt: Date, isUsed: Bool = false) {
        self.code = code
        self.site = site
        self.minutes = minutes
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.isUsed = isUsed
    }
}

@MainActor
public final class FocusEngine: ObservableObject {
    public static let shared = FocusEngine()
    
    // MARK: - Published Properties
    @Published public var settings: AppSettings
    @Published public var isShowingOnboarding: Bool = false
    @Published public var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    @Published public var currentSession: FocusSession?
    @Published public var sessionStatus: SessionStatus = .idle
    @Published public var remainingSeconds: TimeInterval = 0
    @Published public var progress: Double = 0.0
    @Published public var generalErrorMessage: String?
    
    // Estado del desbloqueo de emergencia y navegación
    @Published public var isSettingsPresented: Bool = false
    @Published public var isEmergencyModalPresented: Bool = false
    @Published public var unlockMode: Int = 1
    @Published public var emergencyStep: Int = 1
    @Published public var enteredReflectionText: String = ""
    @Published public var unlockDelayRemainingSeconds: TimeInterval = 0
    @Published public var enteredEmergencyCode: String = ""
    @Published public var enteredMasterPassword: String = ""
    @Published public var emergencyErrorMessage: String?
    @Published public var emergencySuccessMessage: String?
    @Published public var isSendingEmail: Bool = false
    
    public var emergencyTimerProgress: Double {
        let total = Double(max(1, settings.unlockDelayMinutes) * 60)
        let remaining = unlockDelayRemainingSeconds
        guard total > 0 else { return 0 }
        return max(0, min(1, (total - remaining) / total))
    }
    
    public var formattedEmergencyRemainingTime: String {
        let total = Int(unlockDelayRemainingSeconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // Timer interno
    private var sessionTimer: AnyCancellable?
    private var delayTimer: AnyCancellable?
    private var alertedPartnerLimitsToday: Set<String> = []
    
    // Control de Códigos OTP y Bypass Temporal
    private var pendingPartnerOTPs: [String: PendingPartnerOTP] = [:]
    @Published public var temporaryBypasses: [String: Date] = [:]
    private var temporaryBypassTimers: [String: DispatchWorkItem] = [:]
    
    private let settingsKey = "FocusPanic_AppSettings_v2"
    private let sessionKey = "FocusPanic_ActiveSession_v2"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
            // Si el usuario ya tiene datos o clave guardada, marcar onboarding completado permanentemente
            if !decoded.masterCompanionPassword.isEmpty || decoded.hasCompletedOnboarding {
                self.settings.hasCompletedOnboarding = true
            }
        } else {
            self.settings = AppSettings()
        }
        
        // Sincronizar idioma de la interfaz
        LocalizationService.shared.setLanguage(self.settings.appLanguage)
        
        self.cleanLegacyAdultSites()
        self.ensureDefaultWebsitesPresent()
        
        // Mostrar onboarding ÚNICAMENTE si el usuario NO lo ha completado antes
        if !self.settings.hasCompletedOnboarding {
            self.isShowingOnboarding = true
        }
        
        restoreActiveSessionIfNeeded()
        
        // Iniciar servidor local de página de intervención motivacional
        LocalInterventionServer.shared.start()
        
        // Iniciar vigilante de Estados y Canales de WhatsApp
        WhatsAppStatusWatcherService.shared.start(
            isStatusEnabled: self.settings.isWhatsAppStatusBlockerEnabled,
            isChannelsEnabled: self.settings.isWhatsAppChannelsBlockerEnabled
        )
        
        // Aplicar protección permanente al iniciar si no hay sesión activa
        if currentSession == nil {
            applyPermanentProtectionOnly()
        }
        
        // Iniciar programador automático de reportes semanales al compañero
        schedulePeriodicWeeklyReportChecker()
    }
    
    // MARK: - Programador Automático de Reportes Semanales
    
    private var periodicWeeklyTimer: AnyCancellable?
    
    private func schedulePeriodicWeeklyReportChecker() {
        periodicWeeklyTimer?.cancel()
        
        // Ejecutar verificación suave a los 5 segundos de abrir la app
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.checkAndSendAutomaticWeeklyReportIfNeeded()
        }
        
        // Y verificar periódicamente cada hora en segundo plano
        periodicWeeklyTimer = Timer.publish(every: 3600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAndSendAutomaticWeeklyReportIfNeeded()
            }
    }
    
    public func checkAndSendAutomaticWeeklyReportIfNeeded() {
        guard settings.isWeeklyReportEnabled else { return }
        let partner = settings.officialPartnerEmail
        guard !partner.isEmpty else { return }
        
        let now = Date()
        let calendar = Calendar.current
        
        var shouldSend = false
        if let lastDate = settings.lastWeeklyReportDate {
            let daysPassed = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: now)).day ?? 0
            if daysPassed >= 7 {
                shouldSend = true
            }
        } else {
            // Primer registro
            settings.lastWeeklyReportDate = now
            saveSettings()
            return
        }
        
        if shouldSend {
            EmailService.shared.sendWeeklyPartnerReport(
                toEmail: partner,
                stats: FocusStatsManager.shared.stats,
                statsManager: FocusStatsManager.shared
            ) { [weak self] result in
                if case .success = result {
                    DispatchQueue.main.async {
                        self?.settings.lastWeeklyReportDate = Date()
                        self?.saveSettings()
                    }
                }
            }
        }
    }
    
    public func checkPermissionsOnLaunch() {
        refreshPermissions()
        if !self.settings.hasCompletedOnboarding {
            self.isShowingOnboarding = true
        }
    }
    
    public func refreshPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        self.isAccessibilityTrusted = AXIsProcessTrustedWithOptions(options)
    }
    
    private func cleanLegacyAdultSites() {
        let legacyNames = Set(["Pornhub", "XVideos", "XNXX", "RedTube", "YouPorn", "OnlyFans", "Chaturbate", "Stripchat", "Cam4", "Eporner", "Tube8", "SpankBang", "Beeg", "HQPorner", "BravoTeens", "TNAFlix", "LiveJasmin", "Rule34", "nhentai"])
        let beforeCount = settings.blockedWebsites.count
        settings.blockedWebsites.removeAll { legacyNames.contains($0.name) }
        if settings.blockedWebsites.count != beforeCount {
            saveSettings()
        }
    }
    
    private func ensureDefaultWebsitesPresent() {
        var updated = false
        if settings.blockedWebsites.isEmpty {
            settings.blockedWebsites = AppSettings.defaultWebsites
            updated = true
        }
        
        // Limpieza de sitios predeterminados obsoletos/no deseados (noticias, compras, juegos secundarios)
        let obsoleteDomains = Set([
            "elmundo.es", "elpais.com", "cnn.com", "bbc.com", "news.ycombinator.com",
            "amazon.com", "mercadolibre.com", "aliexpress.com", "ebay.com",
            "poki.com", "friv.com", "ea.com", "battle.net", "riotgames.com",
            "linkedin.com", "netflix.com", "disneyplus.com", "primevideo.com"
        ])
        
        let initialCount = settings.blockedWebsites.count
        settings.blockedWebsites.removeAll { site in
            return obsoleteDomains.contains(site.domain.lowercased()) && !site.isCustom
        }
        for obs in obsoleteDomains {
            settings.permanentBlockedWebsites.removeAll { $0 == obs }
        }
        if settings.blockedWebsites.count != initialCount {
            updated = true
        }
        
        if settings.allowedWebsites.isEmpty {
            settings.allowedWebsites = AppSettings.defaultAllowedWebsites
            updated = true
        }
        if settings.allowedApps.isEmpty {
            settings.allowedApps = AppSettings.defaultAllowedApps
            updated = true
        }
        if settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            settings.masterCompanionPassword = "1234"
            settings.isMasterPasswordEnabled = true
            updated = true
        }
        // Migración: Asegurar que los límites por defecto no bloqueen sin configuración explícita
        if settings.isAppLimitsEnabled {
            settings.isAppLimitsEnabled = false
            updated = true
        }
        for i in 0..<settings.appLimits.count {
            if AppSettings.defaultAppLimits.contains(where: { $0.identifier == settings.appLimits[i].identifier }) && settings.appLimits[i].isEnabled {
                settings.appLimits[i].isEnabled = false
                updated = true
            }
        }
        if updated {
            saveSettings()
        }
    }
    
    // MARK: - Persistencia
    
    public func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: settingsKey)
        }
    }
    
    // MARK: - Copia de Seguridad & Transferencia (Importar / Exportar Ajustes)
    
    public func exportSettingsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    public func importSettings(from jsonString: String) -> Result<Void, Error> {
        guard let data = jsonString.data(using: .utf8) else {
            let error = NSError(domain: "FocusPanic", code: 400, userInfo: [NSLocalizedDescriptionKey: "El archivo no contiene texto legible."])
            return .failure(error)
        }
        
        do {
            let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
            self.settings = decoded
            self.saveSettings()
            
            // Sincronizar servicios del sistema e idioma
            LocalizationService.shared.setLanguage(decoded.appLanguage)
            LaunchAtLoginService.shared.updateLaunchAtLogin(enabled: decoded.launchAtLogin)
            
            if self.sessionStatus == .active {
                self.applySystemBlocks()
            } else {
                self.applyPermanentProtectionOnly()
            }
            self.refreshWatchdogRules()
            return .success(())
        } catch {
            return .failure(error)
        }
    }
    
    public func setLanguage(_ language: AppLanguage) {
        self.settings.appLanguage = language
        LocalizationService.shared.setLanguage(language)
        self.saveSettings()
    }
    
    public func exportSettingsToFile(completion: ((Bool, String) -> Void)? = nil) {
        guard let jsonString = exportSettingsJSON() else {
            completion?(false, "No se pudo generar el archivo de configuración.")
            return
        }
        
        let savePanel = NSSavePanel()
        savePanel.title = "Guardar Copia de Seguridad de FocusPanic"
        savePanel.prompt = "Exportar"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        savePanel.nameFieldStringValue = "FocusPanic_Ajustes_\(dateStr).json"
        savePanel.allowedContentTypes = [.json]
        
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try jsonString.write(to: url, atomically: true, encoding: .utf8)
                SoundService.shared.play("Hero")
                completion?(true, "Copia de seguridad exportada en: \(url.lastPathComponent)")
            } catch {
                SoundService.shared.play("Basso")
                completion?(false, "Error al guardar el archivo: \(error.localizedDescription)")
            }
        }
    }
    
    public func importSettingsFromFile(completion: ((Bool, String) -> Void)? = nil) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Seleccionar Copia de Seguridad de FocusPanic"
        openPanel.prompt = "Importar"
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        let response = openPanel.runModal()
        if response == .OK, let url = openPanel.url {
            do {
                let jsonString = try String(contentsOf: url, encoding: .utf8)
                let result = importSettings(from: jsonString)
                switch result {
                case .success:
                    SoundService.shared.play("Hero")
                    completion?(true, "Ajustes importados y aplicados exitosamente desde \(url.lastPathComponent).")
                case .failure(let error):
                    SoundService.shared.play("Basso")
                    completion?(false, "El archivo seleccionado no es válido: \(error.localizedDescription)")
                }
            } catch {
                SoundService.shared.play("Basso")
                completion?(false, "Error al leer el archivo: \(error.localizedDescription)")
            }
        }
    }
    
    public func completeOnboarding() {
        guard HostBlockerService.shared.isHelperInstalled else {
            self.generalErrorMessage = "⚠️ Debes completar la configuración de permisos antes de continuar."
            return
        }
        self.settings.hasCompletedOnboarding = true
        self.isShowingOnboarding = false
        self.saveSettings()
    }
    
    // MARK: - Gestión del Escudo Permanente 24/7
    
    public func updateAlwaysBlockAdultSites(enabled: Bool) {
        settings.isAlwaysBlockAdultSites = enabled
        saveSettings()
        
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    public func updateForceSafeSearch(enabled: Bool) {
        settings.isForceSafeSearchEnabled = enabled
        saveSettings()
        
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    public func togglePermanentWebsite(domain: String) {
        let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.permanentBlockedWebsites.contains(clean) {
            settings.permanentBlockedWebsites.removeAll { $0 == clean }
        } else {
            settings.permanentBlockedWebsites.append(clean)
        }
        saveSettings()
        
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    public func togglePermanentApp(bundleId: String) {
        if settings.permanentBlockedApps.contains(bundleId) {
            settings.permanentBlockedApps.removeAll { $0 == bundleId }
        } else {
            settings.permanentBlockedApps.append(bundleId)
        }
        saveSettings()
        
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    // MARK: - Gestión de la Lista Blanca (Whitelist)
    
    public func setBlockingMode(_ mode: FocusBlockingMode) {
        settings.blockingMode = mode
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        }
    }
    
    public func toggleAllowedWebsite(domain: String) {
        let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let idx = settings.allowedWebsites.firstIndex(where: { $0.domain.lowercased() == clean }) {
            settings.allowedWebsites[idx].isEnabled.toggle()
        } else {
            let newSite = BlockedWebsite(domain: clean, name: FocusEngine.cleanDomainToName(clean), category: .productivity, isEnabled: true)
            settings.allowedWebsites.append(newSite)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func removeAllowedWebsite(id: UUID) {
        settings.allowedWebsites.removeAll { $0.id == id }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public static func cleanDomainToName(_ domain: String) -> String {
        let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        let pathParts = clean.components(separatedBy: "/")
        let host = pathParts.first ?? clean
        let hostParts = host.components(separatedBy: ".")
        
        var name = host
        if hostParts.count >= 2 {
            let core = hostParts[hostParts.count - 2].capitalized
            if hostParts.count > 2 {
                let sub = hostParts[0].capitalized
                name = "\(sub) \(core)"
            } else {
                name = core
            }
        } else {
            name = host.capitalized
        }
        
        if pathParts.count > 1 && !pathParts[1].isEmpty {
            name += " (/\(pathParts.dropFirst().joined(separator: "/")))"
        }
        return name
    }
    
    public func addAllowedWebsite(domain: String, name: String = "") {
        var clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        
        guard !clean.isEmpty else { return }
        
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? FocusEngine.cleanDomainToName(clean) : name
        
        if let idx = settings.allowedWebsites.firstIndex(where: { $0.domain.lowercased() == clean }) {
            settings.allowedWebsites[idx].isEnabled = true
            settings.allowedWebsites[idx].name = finalName
        } else {
            let newSite = BlockedWebsite(domain: clean, name: finalName, category: .productivity, isEnabled: true)
            settings.allowedWebsites.append(newSite)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func processBatchAllowedWebsites(text: String) {
        let rawItems = text.components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",;")))
        var addedAny = false
        
        for raw in rawItems {
            var clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")
            
            while clean.hasSuffix("/") {
                clean.removeLast()
            }
            
            guard !clean.isEmpty && !clean.hasPrefix("#") && clean.contains(".") else { continue }
            
            if let idx = settings.allowedWebsites.firstIndex(where: { $0.domain.lowercased() == clean }) {
                settings.allowedWebsites[idx].isEnabled = true
                addedAny = true
            } else {
                let newSite = BlockedWebsite(domain: clean, name: FocusEngine.cleanDomainToName(clean), category: .productivity, isEnabled: true)
                settings.allowedWebsites.append(newSite)
                addedAny = true
            }
        }
        
        if addedAny {
            saveSettings()
            if currentSession != nil {
                applySystemBlocks()
            } else {
                applyPermanentProtectionOnly()
            }
        }
    }
    
    public func removeBlockedWebsite(id: UUID) {
        if let site = settings.blockedWebsites.first(where: { $0.id == id }) {
            let domainClean = site.domain.lowercased()
            settings.permanentBlockedWebsites.removeAll { $0 == domainClean }
        }
        settings.blockedWebsites.removeAll { $0.id == id }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func addBlockedApp(app: BlockedApp) {
        if let idx = settings.blockedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            settings.blockedApps[idx].isEnabled = true
        } else {
            var newApp = app
            newApp.isEnabled = true
            settings.blockedApps.append(newApp)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func toggleBlockedApp(id: UUID, isEnabled: Bool) {
        if let idx = settings.blockedApps.firstIndex(where: { $0.id == id }) {
            settings.blockedApps[idx].isEnabled = isEnabled
            saveSettings()
            if currentSession != nil {
                applySystemBlocks()
            } else {
                applyPermanentProtectionOnly()
            }
        }
    }
    
    public func removeBlockedApp(id: UUID) {
        settings.blockedApps.removeAll { $0.id == id }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func addAllowedApp(app: BlockedApp) {
        if let idx = settings.allowedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            settings.allowedApps[idx].isEnabled = true
        } else {
            var newApp = app
            newApp.isEnabled = true
            settings.allowedApps.append(newApp)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func removeAllowedApp(bundleId: String) {
        settings.allowedApps.removeAll { $0.bundleIdentifier == bundleId }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func toggleAllowedApp(bundleId: String) {
        if let idx = settings.allowedApps.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
            settings.allowedApps[idx].isEnabled.toggle()
        } else {
            let app = BlockedApp(bundleIdentifier: bundleId, appName: bundleId, isEnabled: true)
            settings.allowedApps.append(app)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    // MARK: - Operaciones Masivas (Activar / Desactivar Todos)
    
    public func toggleAllWebsites(enabled: Bool) {
        for i in 0..<settings.blockedWebsites.count {
            settings.blockedWebsites[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func toggleAllBlockedApps(enabled: Bool) {
        for i in 0..<settings.blockedApps.count {
            settings.blockedApps[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func toggleAllPermanentWebsites(enabled: Bool) {
        if enabled {
            settings.permanentBlockedWebsites = settings.blockedWebsites.map { $0.domain.lowercased() }
        } else {
            settings.permanentBlockedWebsites.removeAll()
        }
        saveSettings()
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    public func toggleAllPermanentApps(enabled: Bool) {
        if enabled {
            settings.permanentBlockedApps = settings.blockedApps.map { $0.bundleIdentifier }
        } else {
            settings.permanentBlockedApps.removeAll()
        }
        saveSettings()
        if currentSession == nil {
            applyPermanentProtectionOnly()
        } else {
            applySystemBlocks()
        }
    }
    
    public func toggleAllAllowedWebsites(enabled: Bool) {
        for i in 0..<settings.allowedWebsites.count {
            settings.allowedWebsites[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    public func toggleAllAllowedApps(enabled: Bool) {
        for i in 0..<settings.allowedApps.count {
            settings.allowedApps[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
    }
    
    // MARK: - Protección Anti-Desinstalación
    
    public func setUninstallProtection(enabled: Bool) {
        settings.isUninstallProtectionEnabled = enabled
        saveSettings()
        
        let appPath = "/Applications/FocusPanic.app"
        if FileManager.default.fileExists(atPath: appPath) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
            task.arguments = [enabled ? "uchg" : "nouchg", appPath]
            try? task.run()
        }
    }
    
    public func performUninstall(companionPin: String) -> Bool {
        let master = settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !master.isEmpty && companionPin == master else {
            let partner = settings.officialPartnerEmail
            if settings.isPartnerAlertUninstallEnabled && !partner.isEmpty {
                EmailService.shared.sendTamperAlert(toEmail: partner, actionDetail: "Intento de desinstalar FocusPanic del sistema con PIN incorrecto.")
            }
            return false
        }
        
        let appPath = "/Applications/FocusPanic.app"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/chflags")
        task.arguments = ["nouchg", appPath]
        try? task.run()
        task.waitUntilExit()
        
        try? HostBlockerService.shared.clearAllBlocks()
        try? HostBlockerService.shared.uninstallHelper()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let rmTask = Process()
            rmTask.executableURL = URL(fileURLWithPath: "/bin/rm")
            rmTask.arguments = ["-rf", appPath]
            try? rmTask.run()
            NSApp.terminate(nil)
        }
        return true
    }
    
    public func setPermanentShieldActive(_ active: Bool) {
        settings.isPermanentShieldActive = active
        saveSettings()
        if sessionStatus != .active {
            applyPermanentProtectionOnly()
        }
    }
    
    public func applyPermanentProtectionOnly() {
        guard settings.isPermanentShieldActive else {
            try? HostBlockerService.shared.removeBlock()
            BrowserWatchdogService.shared.stop()
            AppBlockerService.shared.stopMonitoring()
            return
        }
        
        var allowedDomains = settings.allowedWebsites.filter { $0.isEnabled }.map { $0.domain }
        let now = Date()
        for (domain, expiry) in temporaryBypasses where expiry > now {
            if !allowedDomains.contains(domain) {
                allowedDomains.append(domain)
            }
        }
        
        var permanentDomains: [String] = []
        if settings.isAlwaysBlockAdultSites {
            permanentDomains.append(contentsOf: AdultBlockListProvider.adultDomains)
            permanentDomains.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
        }
        if settings.isForceSafeSearchEnabled {
            permanentDomains.append(contentsOf: AdultBlockListProvider.alternativeSearchEngines)
        }
        permanentDomains.append(contentsOf: settings.permanentBlockedWebsites)
        
        // MARK: - 1. Si Tiempo Desactivado está en curso en este momento
        if isDowntimeActiveNow && settings.downtimeSchedule.blockDuringDowntime {
            do {
                let allBlocked = settings.blockedWebsites.map { $0.domain }
                try HostBlockerService.shared.applyBlock(domains: allBlocked, allowedDomains: allowedDomains, forceSafeSearch: settings.isForceSafeSearchEnabled)
                BrowserWatchdogService.shared.start(
                    blockedDomains: allBlocked,
                    allowedDomains: allowedDomains,
                    blockedKeywords: settings.blockedKeywords,
                    isWhitelistMode: true,
                    isAntiIncognitoEnabled: settings.isAntiIncognitoEnabled,
                    isKeywordBlockerEnabled: settings.isKeywordBlockerEnabled,
                    isAdultShieldEnabled: settings.isAlwaysBlockAdultSites
                )
                
                let activeAllowedApps = settings.allowedApps.filter { $0.isEnabled }
                AppBlockerService.shared.startMonitoring(
                    blockedApps: settings.blockedApps,
                    allowedApps: activeAllowedApps,
                    isWhitelistMode: true
                )
                generalErrorMessage = nil
                return
            } catch {
                generalErrorMessage = "Permisos requeridos para activar el Tiempo Desactivado."
            }
        }
        
        // MARK: - 2. Incluir Límites de Apps y Sitios SOLO si el límite de tiempo diario fue superado
        if settings.isAppLimitsEnabled {
            let today = FocusStatsManager.shared.todayString
            let dailyUsage = FocusStatsManager.shared.stats.dailyRecords[today]?.socialUsage ?? [:]
            
            for limit in settings.appLimits where limit.isEnabled {
                let cleanSource = FocusStatsManager.shared.cleanSourceName(limit.name.isEmpty ? limit.identifier : limit.name)
                let usedSecs = dailyUsage[cleanSource]?.totalSeconds ?? 0
                let usedMins = usedSecs / 60
                
                if usedMins >= limit.limitMinutes {
                    if !alertedPartnerLimitsToday.contains(cleanSource) {
                        alertedPartnerLimitsToday.insert(cleanSource)
                        let partner = settings.officialPartnerEmail
                        if settings.isPartnerAlertSocialLimitEnabled && !partner.isEmpty {
                            EmailService.shared.sendSocialLimitAlert(
                                toEmail: partner,
                                appName: limit.name.isEmpty ? cleanSource : limit.name,
                                limitMinutes: limit.limitMinutes,
                                totalMinutes: usedMins
                            )
                        }
                    }
                    
                    if limit.targetType == "website" {
                        let clean = limit.identifier.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        if !permanentDomains.contains(clean) {
                            permanentDomains.append(clean)
                        }
                    }
                }
            }
        }
        
        // Excluir dominios con bypass temporal activo
        permanentDomains = permanentDomains.filter { domain in
            let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let expiry = temporaryBypasses[clean], expiry > now {
                return false
            }
            return true
        }
        
        // Identificar dominios raíz que tienen excepciones en Lista Blanca o Bypass Temporal
        var rootsWithWhitelistExceptions: Set<String> = []
        for allowed in allowedDomains {
            let hostOnly = allowed.components(separatedBy: "/").first ?? allowed
            let parts = hostOnly.components(separatedBy: ".")
            if parts.count >= 2 {
                let root = parts.suffix(2).joined(separator: ".").lowercased()
                rootsWithWhitelistExceptions.insert(root)
                rootsWithWhitelistExceptions.insert(hostOnly.lowercased())
            }
        }
        
        var hostsDomainsToBlock = permanentDomains
        hostsDomainsToBlock.removeAll { domain in
            let clean = domain.lowercased().replacingOccurrences(of: "www.", with: "")
            if rootsWithWhitelistExceptions.contains(clean) { return true }
            if let expiry = temporaryBypasses[clean], expiry > now { return true }
            return false
        }
        
        if permanentDomains.isEmpty && !settings.isForceSafeSearchEnabled && settings.permanentBlockedApps.isEmpty {
            try? HostBlockerService.shared.removeBlock()
            BrowserWatchdogService.shared.stop()
            AppBlockerService.shared.stopMonitoring()
            return
        }
        
        do {
            try HostBlockerService.shared.applyBlock(domains: hostsDomainsToBlock, allowedDomains: allowedDomains, forceSafeSearch: settings.isForceSafeSearchEnabled)
            var permKeywords = settings.blockedKeywords
            if settings.isAlwaysBlockAdultSites {
                permKeywords.append(contentsOf: AdultBlockListProvider.adultKeywords)
            }
            BrowserWatchdogService.shared.start(
                blockedDomains: permanentDomains,
                allowedDomains: allowedDomains,
                blockedKeywords: permKeywords,
                isWhitelistMode: false,
                isAntiIncognitoEnabled: settings.isAntiIncognitoEnabled,
                isKeywordBlockerEnabled: settings.isKeywordBlockerEnabled,
                isAdultShieldEnabled: settings.isAlwaysBlockAdultSites
            )
            
            // Monitorear apps permanentes + límites de apps agotados + navegadores del escudo
            var permApps: [BlockedApp] = []
            if settings.isAlwaysBlockAdultSites {
                permApps.append(contentsOf: AdultBlockListProvider.blockedBrowsers)
            }
            for bId in settings.permanentBlockedApps {
                if let found = settings.blockedApps.first(where: { $0.bundleIdentifier == bId }) {
                    var activeApp = found
                    activeApp.isEnabled = true
                    if !permApps.contains(where: { $0.bundleIdentifier == activeApp.bundleIdentifier }) {
                        permApps.append(activeApp)
                    }
                } else {
                    if !permApps.contains(where: { $0.bundleIdentifier == bId }) {
                        permApps.append(BlockedApp(bundleIdentifier: bId, appName: bId, isEnabled: true))
                    }
                }
            }
            
            if settings.isAppLimitsEnabled {
                let today = FocusStatsManager.shared.todayString
                let dailyUsage = FocusStatsManager.shared.stats.dailyRecords[today]?.socialUsage ?? [:]
                
                for limit in settings.appLimits where limit.isEnabled && limit.targetType == "app" {
                    let cleanSource = FocusStatsManager.shared.cleanSourceName(limit.name.isEmpty ? limit.identifier : limit.name)
                    let usedSecs = dailyUsage[cleanSource]?.totalSeconds ?? 0
                    let usedMins = usedSecs / 60
                    
                    if usedMins >= limit.limitMinutes {
                        if !permApps.contains(where: { $0.bundleIdentifier == limit.identifier }) {
                            permApps.append(BlockedApp(bundleIdentifier: limit.identifier, appName: limit.name, isEnabled: true))
                        }
                    }
                }
            }
            
            if !permApps.isEmpty {
                AppBlockerService.shared.startMonitoring(blockedApps: permApps)
            } else {
                AppBlockerService.shared.stopMonitoring()
            }
            generalErrorMessage = nil
        } catch {
            generalErrorMessage = "Permisos requeridos para activar el Escudo Permanente."
        }
    }
    
    // MARK: - Evaluación de Tiempo Desactivado y Límites de Apps
    
    public var isDowntimeActiveNow: Bool {
        guard settings.downtimeSchedule.isEnabled else { return false }
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.weekday, from: now)
        guard settings.downtimeSchedule.activeDays.contains(currentDay) else { return false }
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMins = currentHour * 60 + currentMinute
        
        let startTotalMins = settings.downtimeSchedule.startHour * 60 + settings.downtimeSchedule.startMinute
        let endTotalMins = settings.downtimeSchedule.endHour * 60 + settings.downtimeSchedule.endMinute
        
        if startTotalMins <= endTotalMins {
            return currentTotalMins >= startTotalMins && currentTotalMins < endTotalMins
        } else {
            return currentTotalMins >= startTotalMins || currentTotalMins < endTotalMins
        }
    }
    
    public func evaluateDowntimeAndLimits() {
        guard currentSession == nil else { return }
        applyPermanentProtectionOnly()
    }
    
    // MARK: - Alertas de Límites y Extensión de Tiempo por Compañero
    
    private var warnedLimitsToday: Set<String> = []
    private var lastWarningDateString: String = ""
    
    public func triggerOneMinuteLimitWarning(for source: String, limitMinutes: Int) {
        let today = FocusStatsManager.shared.todayString
        if lastWarningDateString != today {
            warnedLimitsToday.removeAll()
            lastWarningDateString = today
        }
        
        let cleanKey = source.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !warnedLimitsToday.contains(cleanKey) else { return }
        warnedLimitsToday.insert(cleanKey)
        
        SoundService.shared.play("Glass")
        NotificationService.shared.sendNotification(
            title: "⏳ Te queda 1 minuto en \(source)",
            body: "Tu límite diario de \(limitMinutes) min está a punto de alcanzarse.",
            sound: "Glass"
        )
    }
    
    // MARK: - Métodos de Bypass Temporal y Desbloqueo de Compañero
    
    public func generateAndSendPartnerOTP(site: String, minutes: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let cleanSite = site.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? site
        
        let partnerEmail = settings.officialPartnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !partnerEmail.isEmpty else {
            let error = NSError(domain: "FocusPanic.PartnerOTP", code: 400, userInfo: [NSLocalizedDescriptionKey: "No hay un correo de compañero configurado. Configúralo en los Ajustes de FocusPanic."])
            completion(.failure(error))
            return
        }
        
        let code = EmailService.shared.generateEmergencyCode()
        let now = Date()
        let expires = now.addingTimeInterval(15 * 60) // Válido 15 minutos
        
        let otp = PendingPartnerOTP(code: code, site: cleanSite, minutes: minutes, createdAt: now, expiresAt: expires, isUsed: false)
        pendingPartnerOTPs[code] = otp
        
        EmailService.shared.sendPartnerOTPTimeRequest(toEmail: partnerEmail, site: cleanSite, minutes: minutes, otpCode: code) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    public func verifyAndConsumePartnerOTP(site: String, code: String) -> (isValid: Bool, minutes: Int) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let otp = pendingPartnerOTPs[cleanCode], !otp.isUsed else {
            return (false, 0)
        }
        
        if Date() > otp.expiresAt {
            pendingPartnerOTPs.removeValue(forKey: cleanCode)
            return (false, 0)
        }
        
        pendingPartnerOTPs[cleanCode]?.isUsed = true
        pendingPartnerOTPs.removeValue(forKey: cleanCode)
        return (true, otp.minutes)
    }
    
    public func grantTemporaryBypass(identifier: String, minutes: Int) -> Bool {
        guard minutes > 0 else { return false }
        let cleanId = identifier.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? identifier.lowercased()
        
        guard !cleanId.isEmpty else { return false }
        
        let expiryDate = Date().addingTimeInterval(Double(minutes) * 60)
        
        var targets = [cleanId, "www.\(cleanId)"]
        if cleanId.contains("instagram") {
            targets.append(contentsOf: ["instagram.com", "www.instagram.com", "cdninstagram.com", "static.cdninstagram.com", "threads.net", "scontent.cdninstagram.com", "graph.instagram.com", "api.instagram.com"])
        } else if cleanId.contains("facebook") || cleanId == "fb.com" {
            targets.append(contentsOf: ["facebook.com", "www.facebook.com", "fbcdn.net", "facebook.net", "fb.com", "messenger.com", "web.facebook.com"])
        } else if cleanId.contains("youtube") || cleanId == "youtu.be" {
            targets.append(contentsOf: ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be", "ytimg.com", "googlevideo.com"])
        } else if cleanId.contains("tiktok") {
            targets.append(contentsOf: ["tiktok.com", "www.tiktok.com", "m.tiktok.com", "tiktokcdn.com", "byteoversea.com", "ibytedtos.com"])
        } else if cleanId.contains("twitter") || cleanId == "x.com" {
            targets.append(contentsOf: ["twitter.com", "www.twitter.com", "x.com", "www.x.com", "twimg.com", "t.co"])
        } else if cleanId.contains("reddit") {
            targets.append(contentsOf: ["reddit.com", "www.reddit.com", "redd.it", "redditstatic.com", "redditmedia.com"])
        } else if cleanId.contains("netflix") {
            targets.append(contentsOf: ["netflix.com", "www.netflix.com", "nflxext.com", "nflximg.net", "nflxvideo.net"])
        }
        
        for target in targets {
            let cleanTarget = target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            temporaryBypasses[cleanTarget] = expiryDate
            temporaryBypassTimers[cleanTarget]?.cancel()
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.temporaryBypasses.removeValue(forKey: cleanTarget)
                self.temporaryBypassTimers.removeValue(forKey: cleanTarget)
                self.refreshWatchdogRules()
                if self.currentSession != nil {
                    self.applySystemBlocks()
                } else {
                    self.applyPermanentProtectionOnly()
                }
                
                if cleanTarget == cleanId {
                    NotificationService.shared.sendNotification(
                        title: "🔒 Tiempo Concluido",
                        body: "Los \(minutes) minutos de acceso para \(FocusStatsManager.shared.cleanSourceName(cleanId)) han terminado. El bloqueo ha sido reactivado.",
                        sound: "Basso"
                    )
                }
            }
            temporaryBypassTimers[cleanTarget] = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes) * 60, execute: workItem)
        }
        
        // Extender app limits si aplica
        _ = self.extendLimit(identifier: cleanId, additionalMinutes: minutes)
        
        refreshWatchdogRules()
        if currentSession != nil {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
        
        SoundService.shared.play("Hero")
        NotificationService.shared.sendNotification(
            title: "✨ Acceso Otorgado (+\(minutes) min)",
            body: "Tu compañero aprobó \(minutes) minutos de acceso temporal para \(FocusStatsManager.shared.cleanSourceName(cleanId)).",
            sound: "Hero"
        )
        return true
    }
    
    public func extendLimit(identifier: String, additionalMinutes: Int) -> Bool {
        guard additionalMinutes > 0 else { return false }
        let cleanId = identifier.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first ?? identifier.lowercased()
        
        var foundAny = false
        
        for i in 0..<settings.appLimits.count {
            let limitId = settings.appLimits[i].identifier.lowercased()
            let limitName = settings.appLimits[i].name.lowercased()
            let targetClean = FocusStatsManager.shared.cleanSourceName(limitName).lowercased()
            let inputClean = FocusStatsManager.shared.cleanSourceName(cleanId).lowercased()
            
            if limitId.contains(cleanId) || cleanId.contains(limitId) || targetClean == inputClean || limitName.contains(cleanId) {
                settings.appLimits[i].limitMinutes += additionalMinutes
                foundAny = true
            }
        }
        
        if !foundAny {
            let sourceName = FocusStatsManager.shared.cleanSourceName(cleanId)
            let currentUsedSecs = FocusStatsManager.shared.stats.dailyRecords[FocusStatsManager.shared.todayString]?.socialUsage[sourceName]?.totalSeconds ?? 0
            let currentUsedMins = currentUsedSecs / 60
            let newLimit = AppTimeLimit(
                targetType: cleanId.contains(".") ? "website" : "app",
                identifier: cleanId,
                name: sourceName,
                limitMinutes: currentUsedMins + additionalMinutes,
                isEnabled: true
            )
            settings.appLimits.append(newLimit)
        }
        
        warnedLimitsToday.remove(FocusStatsManager.shared.cleanSourceName(cleanId).lowercased())
        
        saveSettings()
        applyPermanentProtectionOnly()
        return true
    }
    
    public func verifyCompanionPassword(_ entered: String) -> Bool {
        let cleanEntered = entered.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEntered.isEmpty else { return false }
        
        let master = settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !master.isEmpty && cleanEntered == master {
            return true
        }
        
        let secAnswer = settings.securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !secAnswer.isEmpty && cleanEntered.lowercased() == secAnswer {
            return true
        }
        
        return false
    }
    
    // MARK: - Métodos de Control Anti-Incógnito y Palabras Prohibidas
    
    public func updateAntiIncognito(enabled: Bool) {
        settings.isAntiIncognitoEnabled = enabled
        saveSettings()
        refreshWatchdogRules()
    }
    
    public func updateKeywordBlocker(enabled: Bool) {
        settings.isKeywordBlockerEnabled = enabled
        saveSettings()
        refreshWatchdogRules()
    }
    
    public func updateWhatsAppStatusBlocker(enabled: Bool) {
        settings.isWhatsAppStatusBlockerEnabled = enabled
        saveSettings()
        if enabled {
            promptAndOpenAccessibilitySettingsIfNeeded()
        }
        WhatsAppStatusWatcherService.shared.updateState(
            isStatusEnabled: settings.isWhatsAppStatusBlockerEnabled,
            isChannelsEnabled: settings.isWhatsAppChannelsBlockerEnabled
        )
    }
    
    public func updateWhatsAppChannelsBlocker(enabled: Bool) {
        settings.isWhatsAppChannelsBlockerEnabled = enabled
        saveSettings()
        if enabled {
            promptAndOpenAccessibilitySettingsIfNeeded()
        }
        WhatsAppStatusWatcherService.shared.updateState(
            isStatusEnabled: settings.isWhatsAppStatusBlockerEnabled,
            isChannelsEnabled: settings.isWhatsAppChannelsBlockerEnabled
        )
    }
    
    public func promptAndOpenAccessibilitySettingsIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        if !AXIsProcessTrustedWithOptions(options) {
            let promptOptions: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(promptOptions)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    public func addBlockedKeyword(_ keyword: String) {
        let clean = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty && !settings.blockedKeywords.contains(clean) else { return }
        settings.blockedKeywords.append(clean)
        saveSettings()
        refreshWatchdogRules()
    }
    
    public func removeBlockedKeyword(_ keyword: String) {
        settings.blockedKeywords.removeAll { $0.lowercased() == keyword.lowercased() }
        saveSettings()
        refreshWatchdogRules()
    }
    
    public func resetDefaultKeywords() {
        settings.blockedKeywords = AppSettings.defaultBlockedKeywords
        saveSettings()
        refreshWatchdogRules()
    }
    
    private func refreshWatchdogRules() {
        var allowedDomains = settings.allowedWebsites.filter { $0.isEnabled }.map { $0.domain }
        let now = Date()
        for (domain, expiry) in temporaryBypasses where expiry > now {
            if !allowedDomains.contains(domain) {
                allowedDomains.append(domain)
            }
        }
        
        var blocked = sessionStatus == .active
            ? settings.blockedWebsites.filter { $0.isEnabled }.map { $0.domain }
            : settings.permanentBlockedWebsites
        
        blocked = blocked.filter { domain in
            let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let expiry = temporaryBypasses[clean], expiry > now {
                return false
            }
            return true
        }
        
        var keywords = settings.blockedKeywords
        if settings.isAlwaysBlockAdultSites {
            blocked.append(contentsOf: AdultBlockListProvider.adultDomains)
            blocked.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
            keywords.append(contentsOf: AdultBlockListProvider.adultKeywords)
        }
        if settings.isForceSafeSearchEnabled {
            blocked.append(contentsOf: AdultBlockListProvider.alternativeSearchEngines)
        }
        
        BrowserWatchdogService.shared.updateRules(
            blockedDomains: blocked,
            allowedDomains: allowedDomains,
            blockedKeywords: keywords,
            isWhitelistMode: (sessionStatus == .active && currentSession?.presetName == "Bloqueo Total"),
            isAntiIncognitoEnabled: settings.isAntiIncognitoEnabled,
            isKeywordBlockerEnabled: settings.isKeywordBlockerEnabled,
            isAdultShieldEnabled: settings.isAlwaysBlockAdultSites
        )
    }
    
    private func saveCurrentSession() {
        if let currentSession = currentSession,
           let encoded = try? JSONEncoder().encode(currentSession) {
            UserDefaults.standard.set(encoded, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }
    
    private func restoreActiveSessionIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(FocusSession.self, from: data) else {
            return
        }
        
        if session.isFinished {
            endSession(didCompleteNormally: true)
        } else {
            self.currentSession = session
            self.sessionStatus = .active
            self.remainingSeconds = session.remainingSeconds
            self.progress = session.progress
            
            applySystemBlocks()
            startSessionTimer()
        }
    }
    
    // MARK: - Control de Sesión Temporal (Modo Enfoque / Pomodoro)
    
    public func startFocusSession(durationMinutes: Int, presetName: String = "Personalizado") {
        guard HostBlockerService.shared.isHelperInstalled else {
            self.isShowingOnboarding = true
            return
        }
        
        let session = FocusSession(durationMinutes: durationMinutes, presetName: presetName)
        self.currentSession = session
        self.sessionStatus = .active
        self.remainingSeconds = session.remainingSeconds
        self.progress = 0.0
        self.generalErrorMessage = nil
        self.saveCurrentSession()
        
        applySystemBlocks()
        startSessionTimer()
        
        let isTotal = presetName == "Bloqueo Total"
        NotificationService.shared.sendNotification(
            title: isTotal ? "🔒 Bloqueo Total Activado" : "🛡️ Modo Enfoque Activado",
            body: isTotal
                ? "Aislamiento total activo por \(durationMinutes) min. Solo tu Lista Blanca está permitida."
                : "Bloqueo activo por \(durationMinutes) minutos. ¡A por tu meta!",
            sound: settings.isSoundEnabled ? "Glass" : ""
        )
    }
    
    public func applySystemBlocks() {
        let isTotalBlock = (currentSession?.presetName == "Bloqueo Total" || settings.blockingMode == .whitelistOnly)
        
        var allowedDomains = settings.allowedWebsites.filter { $0.isEnabled }.map { $0.domain }
        let now = Date()
        for (domain, expiry) in temporaryBypasses where expiry > now {
            if !allowedDomains.contains(domain) {
                allowedDomains.append(domain)
            }
        }
        
        let allowedBundleIds = settings.allowedApps.filter { $0.isEnabled }.map { $0.bundleIdentifier }
        
        var domainsToBlock: [String] = []
        if isTotalBlock {
            domainsToBlock = []
        } else {
            domainsToBlock = settings.blockedWebsites.filter { $0.isEnabled }.map { $0.domain }
        }
        
        if settings.isAlwaysBlockAdultSites {
            domainsToBlock.append(contentsOf: AdultBlockListProvider.adultDomains)
            domainsToBlock.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
        }
        
        var rootsWithWhitelistExceptions: Set<String> = []
        for allowed in allowedDomains {
            let hostOnly = allowed.components(separatedBy: "/").first ?? allowed
            let parts = hostOnly.components(separatedBy: ".")
            if parts.count >= 2 {
                let root = parts.suffix(2).joined(separator: ".").lowercased()
                rootsWithWhitelistExceptions.insert(root)
                rootsWithWhitelistExceptions.insert(hostOnly.lowercased())
            }
        }
        
        domainsToBlock.removeAll { domain in
            let clean = domain.lowercased().replacingOccurrences(of: "www.", with: "")
            if rootsWithWhitelistExceptions.contains(clean) { return true }
            if let expiry = temporaryBypasses[clean], expiry > now { return true }
            return false
        }
        
        do {
            try HostBlockerService.shared.applyBlock(domains: domainsToBlock, allowedDomains: allowedDomains, forceSafeSearch: settings.isForceSafeSearchEnabled)
            generalErrorMessage = nil
        } catch {
            generalErrorMessage = "⚠️ Permisos necesarios: \(error.localizedDescription)"
        }
        
        var activeBlockedApps = settings.blockedApps.filter { $0.isEnabled && !allowedBundleIds.contains($0.bundleIdentifier) }
        
        if settings.isBlockDevToolsEnabled {
            let devTools = [
                BlockedApp(bundleIdentifier: "com.apple.Terminal", appName: "Terminal", isEnabled: true),
                BlockedApp(bundleIdentifier: "com.apple.ActivityMonitor", appName: "Monitor de Actividad", isEnabled: true),
                BlockedApp(bundleIdentifier: "com.googlecode.iterm2", appName: "iTerm2", isEnabled: true),
                BlockedApp(bundleIdentifier: "dev.warp.Warp-Stable", appName: "Warp", isEnabled: true),
                BlockedApp(bundleIdentifier: "io.alacritty", appName: "Alacritty", isEnabled: true),
                BlockedApp(bundleIdentifier: "net.kovidgoyal.kitty", appName: "kitty", isEnabled: true),
                BlockedApp(bundleIdentifier: "com.mitchellh.ghostty", appName: "Ghostty", isEnabled: true)
            ]
            for tool in devTools {
                if !activeBlockedApps.contains(where: { $0.bundleIdentifier.lowercased() == tool.bundleIdentifier.lowercased() }) {
                    activeBlockedApps.append(tool)
                }
            }
        }
        
        if settings.isAlwaysBlockAdultSites {
            for browserApp in AdultBlockListProvider.blockedBrowsers {
                if !activeBlockedApps.contains(where: { $0.bundleIdentifier.lowercased() == browserApp.bundleIdentifier.lowercased() }) {
                    activeBlockedApps.append(browserApp)
                }
            }
        }
        
        let activeAllowedApps = settings.allowedApps.filter { $0.isEnabled }
        AppBlockerService.shared.startMonitoring(
            blockedApps: activeBlockedApps,
            allowedApps: activeAllowedApps,
            isWhitelistMode: isTotalBlock
        )
        
        var allActiveBlocked = settings.blockedWebsites.filter { $0.isEnabled }.map { $0.domain }
        allActiveBlocked.removeAll { domain in
            let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if let expiry = temporaryBypasses[clean], expiry > now { return true }
            return false
        }
        
        var sessionKeywords = settings.blockedKeywords
        if settings.isAlwaysBlockAdultSites {
            allActiveBlocked.append(contentsOf: AdultBlockListProvider.adultDomains)
            allActiveBlocked.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
            sessionKeywords.append(contentsOf: AdultBlockListProvider.adultKeywords)
        }
        if settings.isForceSafeSearchEnabled {
            allActiveBlocked.append(contentsOf: AdultBlockListProvider.alternativeSearchEngines)
        }
        
        BrowserWatchdogService.shared.start(
            blockedDomains: allActiveBlocked,
            allowedDomains: allowedDomains,
            blockedKeywords: sessionKeywords,
            isWhitelistMode: isTotalBlock,
            isAntiIncognitoEnabled: settings.isAntiIncognitoEnabled,
            isKeywordBlockerEnabled: settings.isKeywordBlockerEnabled,
            isAdultShieldEnabled: settings.isAlwaysBlockAdultSites
        )
    }
    
    private func startSessionTimer() {
        sessionTimer?.cancel()
        sessionTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let session = self.currentSession else { return }
                
                let remaining = session.remainingSeconds
                self.remainingSeconds = remaining
                self.progress = session.progress
                
                if remaining <= 0 {
                    self.endSession(didCompleteNormally: true)
                }
            }
    }
    
    public func endSession(didCompleteNormally: Bool) {
        sessionTimer?.cancel()
        sessionTimer = nil
        
        // Registrar tiempo de enfoque para racha y estadísticas
        if let session = currentSession {
            let totalMins = Int(session.originalDurationSeconds / 60)
            let elapsedMins = Int((session.originalDurationSeconds - session.remainingSeconds) / 60)
            if didCompleteNormally {
                FocusStatsManager.shared.recordCompletedSession(durationMinutes: totalMins)
            } else if elapsedMins >= 3 {
                FocusStatsManager.shared.recordCompletedSession(durationMinutes: elapsedMins)
            }
        }
        
        AppBlockerService.shared.stopMonitoring()
        
        // Volver al estado de protección permanente (Anti-Porn + SafeSearch + Sitios 24/7)
        applyPermanentProtectionOnly()
        
        self.currentSession = nil
        self.sessionStatus = didCompleteNormally ? .completed : .idle
        self.remainingSeconds = 0
        self.progress = 0.0
        self.saveCurrentSession()
        
        if didCompleteNormally {
            NotificationService.shared.sendNotification(
                title: "🎉 ¡Objetivo Cumplido!",
                body: "Completaste tu sesión de enfoque. Los sitios temporales han sido desbloqueados.",
                sound: settings.isSoundEnabled ? "Hero" : ""
            )
        } else {
            NotificationService.shared.sendNotification(
                title: "🔓 Modo Enfoque Desactivado",
                body: "El bloqueo temporal ha sido desactivado.",
                sound: settings.isSoundEnabled ? "Hero" : ""
            )
        }
    }
    
    // MARK: - Flujo de Desbloqueo de Emergencia
    
    public func initiateEmergencyUnlock() {
        self.unlockMode = 1
        self.emergencyStep = 1
        self.enteredReflectionText = ""
        self.enteredMasterPassword = ""
        self.emergencyErrorMessage = nil
        self.emergencySuccessMessage = nil
        self.enteredEmergencyCode = ""
        self.isEmergencyModalPresented = true
    }
    
    public func unlockInstantlyWithMasterPassword() {
        let entered = enteredMasterPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let actual = settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard settings.isMasterPasswordEnabled else {
            emergencyErrorMessage = "La clave del compañero está desactivada en Ajustes."
            return
        }
        
        if entered == actual && !actual.isEmpty {
            self.isEmergencyModalPresented = false
            self.enteredMasterPassword = ""
            self.emergencyErrorMessage = nil
            endSession(didCompleteNormally: false)
        } else {
            emergencyErrorMessage = "Clave incorrecta. Pídesela a tu compañero."
        }
    }
    
    public func unlockWithSecurityAnswer(_ answer: String) -> Bool {
        let clean = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let expected = settings.securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !expected.isEmpty else {
            emergencyErrorMessage = "No se configuró una respuesta secreta."
            return false
        }
        
        if clean == expected {
            self.isEmergencyModalPresented = false
            self.emergencyErrorMessage = nil
            endSession(didCompleteNormally: false)
            return true
        } else {
            emergencyErrorMessage = "Respuesta secreta incorrecta."
            return false
        }
    }
    
    public func startFrictionCooldown() {
        emergencyErrorMessage = nil
        let delayMinutes = max(1, settings.unlockDelayMinutes)
        self.unlockDelayRemainingSeconds = TimeInterval(delayMinutes * 60)
        self.emergencyStep = 1
        startUnlockDelayTimer()
    }
    
    public func submitFrictionReflection() {
        let cleanInput = enteredReflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPhrase = settings.reflectionPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanInput.caseInsensitiveCompare(targetPhrase) == .orderedSame || cleanInput.count >= targetPhrase.count {
            let remainingMins = max(1, Int(self.remainingSeconds / 60))
            let phrase = cleanInput.isEmpty ? targetPhrase : cleanInput
            let partner = settings.officialPartnerEmail
            if settings.isPartnerAlertEmergencyUnlockEnabled && !partner.isEmpty {
                EmailService.shared.sendEmergencyUnlockAlert(
                    toEmail: partner,
                    reflectionText: phrase,
                    remainingMinutes: remainingMins
                )
            }
            
            self.isEmergencyModalPresented = false
            self.enteredReflectionText = ""
            self.emergencyErrorMessage = nil
            endSession(didCompleteNormally: false)
        } else {
            emergencyErrorMessage = "Debes escribir el texto completo de compromiso de forma exacta."
        }
    }
    
    private func startUnlockDelayTimer() {
        delayTimer?.cancel()
        delayTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.unlockDelayRemainingSeconds > 0 {
                    self.unlockDelayRemainingSeconds -= 1
                } else {
                    self.delayTimer?.cancel()
                    self.delayTimer = nil
                    // Al terminar la espera, pasamos al paso de escritura de texto largo
                    self.emergencyStep = 2
                    NSSound(named: "Hero")?.play()
                }
            }
    }
    
    public func cancelEmergencyUnlock() {
        delayTimer?.cancel()
        delayTimer = nil
        isEmergencyModalPresented = false
        emergencyStep = 1
        unlockMode = 1
        enteredReflectionText = ""
        enteredEmergencyCode = ""
        enteredMasterPassword = ""
        emergencyErrorMessage = nil
    }
    
    public var formattedRemainingTime: String {
        let total = Int(remainingSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    public var formattedDelayRemainingTime: String {
        let total = Int(unlockDelayRemainingSeconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
    
    // MARK: - Recuperación y Reinicio Seguro
    
    public func relaunchApp() {
        saveSettings()
        SoundService.shared.play("Hero")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            AppDelegate.shared?.authorizeAndRelaunch()
        }
    }
    
    public func restartSubsystems() {
        saveSettings()
        LocalInterventionServer.shared.stop()
        LocalInterventionServer.shared.start()
        
        BrowserWatchdogService.shared.stop()
        WhatsAppStatusWatcherService.shared.stop()
        AppBlockerService.shared.stopMonitoring()
        
        if sessionStatus == .active {
            applySystemBlocks()
        } else {
            applyPermanentProtectionOnly()
        }
        
        evaluateDowntimeAndLimits()
        SoundService.shared.play("Hero")
    }
}
