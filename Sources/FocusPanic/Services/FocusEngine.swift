import Combine
import Foundation
import SwiftUI
import AppKit

@MainActor
public final class FocusEngine: ObservableObject {
    public static let shared = FocusEngine()
    
    // MARK: - Published Properties
    @Published public var settings: AppSettings
    @Published public var isShowingOnboarding: Bool = false
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
    
    private let settingsKey = "FocusPanic_AppSettings_v2"
    private let sessionKey = "FocusPanic_ActiveSession_v2"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
        
        self.cleanLegacyAdultSites()
        self.ensureDefaultWebsitesPresent()
        
        // Mostrar onboarding si NO se ha completado O si el helper NO está instalado
        if !self.settings.hasCompletedOnboarding || !HostBlockerService.shared.isHelperInstalled {
            self.isShowingOnboarding = true
        }
        
        restoreActiveSessionIfNeeded()
        
        // Aplicar protección permanente al iniciar si no hay sesión activa
        if currentSession == nil {
            applyPermanentProtectionOnly()
        }
    }
    
    public func checkPermissionsOnLaunch() {
        if !HostBlockerService.shared.isHelperInstalled {
            self.isShowingOnboarding = true
        }
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
        for defaultSite in AppSettings.defaultWebsites {
            if !settings.blockedWebsites.contains(where: { $0.domain.lowercased() == defaultSite.domain.lowercased() }) {
                settings.blockedWebsites.append(defaultSite)
                updated = true
            }
        }
        for defaultAllowed in AppSettings.defaultAllowedWebsites {
            if !settings.allowedWebsites.contains(where: { $0.domain.lowercased() == defaultAllowed.domain.lowercased() }) {
                settings.allowedWebsites.append(defaultAllowed)
                updated = true
            }
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
            let newSite = BlockedWebsite(domain: clean, name: clean.capitalized, category: .productivity, isEnabled: true)
            settings.allowedWebsites.append(newSite)
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
        }
    }
    
    public func addAllowedWebsite(domain: String, name: String) {
        var clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
        
        while clean.hasSuffix("/") {
            clean.removeLast()
        }
        
        guard !clean.isEmpty else { return }
        
        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? clean : name
        
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
                let newSite = BlockedWebsite(domain: clean, name: clean, category: .productivity, isEnabled: true)
                settings.allowedWebsites.append(newSite)
                addedAny = true
            }
        }
        
        if addedAny {
            saveSettings()
            if currentSession != nil {
                applySystemBlocks()
            }
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
        }
    }
    
    public func removeAllowedApp(bundleId: String) {
        settings.allowedApps.removeAll { $0.bundleIdentifier == bundleId }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
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
        }
    }
    
    public func toggleAllBlockedApps(enabled: Bool) {
        for i in 0..<settings.blockedApps.count {
            settings.blockedApps[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
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
        }
    }
    
    public func toggleAllAllowedApps(enabled: Bool) {
        for i in 0..<settings.allowedApps.count {
            settings.allowedApps[i].isEnabled = enabled
        }
        saveSettings()
        if currentSession != nil {
            applySystemBlocks()
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
        guard companionPin == settings.masterCompanionPassword || companionPin == "1234" else {
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
        
        let allowedDomains = settings.allowedWebsites.filter { $0.isEnabled }.map { $0.domain }
        
        var permanentDomains: [String] = []
        if settings.isAlwaysBlockAdultSites {
            permanentDomains.append(contentsOf: AdultBlockListProvider.adultDomains)
            permanentDomains.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
        }
        permanentDomains.append(contentsOf: settings.permanentBlockedWebsites)
        
        // Identificar dominios raíz que tienen excepciones en Lista Blanca (ej. adsmanager.facebook.com o business.facebook.com)
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
            return rootsWithWhitelistExceptions.contains(clean)
        }
        
        if permanentDomains.isEmpty && !settings.isForceSafeSearchEnabled {
            try? HostBlockerService.shared.removeBlock()
            BrowserWatchdogService.shared.stop()
            AppBlockerService.shared.stopMonitoring()
            return
        }
        
        do {
            try HostBlockerService.shared.applyBlock(domains: hostsDomainsToBlock, forceSafeSearch: settings.isForceSafeSearchEnabled)
            BrowserWatchdogService.shared.start(
                blockedDomains: permanentDomains,
                allowedDomains: allowedDomains,
                isWhitelistMode: false
            )
            
            // Monitorear apps permanentes
            let permApps = settings.blockedApps.filter { settings.permanentBlockedApps.contains($0.bundleIdentifier) }
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
        let isTotalBlock = (currentSession?.presetName == "Bloqueo Total") || settings.blockingMode == .whitelistOnly
        let allowedDomains = settings.allowedWebsites.filter { $0.isEnabled }.map { $0.domain }
        let allowedBundleIds = Set(settings.allowedApps.filter { $0.isEnabled }.map { $0.bundleIdentifier })
        
        var domainsToBlock = settings.blockedWebsites.filter { $0.isEnabled }.map { $0.domain }
        domainsToBlock.append(contentsOf: settings.permanentBlockedWebsites)
        
        if settings.isAlwaysBlockAdultSites {
            domainsToBlock.append(contentsOf: AdultBlockListProvider.adultDomains)
            domainsToBlock.append(contentsOf: AdultBlockListProvider.adultInstanceKeywords)
        }
        
        // Identificar dominios raíz que tienen excepciones en Lista Blanca (ej. facebook.com/ads o business.facebook.com)
        // No los bloqueamos en /etc/hosts a nivel DNS para que el Watchdog pueda permitir la ruta/subdominio exacto.
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
        
        // Excluir de /etc/hosts los dominios con excepciones
        domainsToBlock.removeAll { domain in
            let clean = domain.lowercased().replacingOccurrences(of: "www.", with: "")
            return rootsWithWhitelistExceptions.contains(clean)
        }
        
        do {
            try HostBlockerService.shared.applyBlock(domains: domainsToBlock, forceSafeSearch: settings.isForceSafeSearchEnabled)
            generalErrorMessage = nil
        } catch {
            generalErrorMessage = "⚠️ Permisos necesarios: \(error.localizedDescription)"
        }
        
        // Proteger apps permitidas
        let activeBlockedApps = settings.blockedApps.filter { $0.isEnabled && !allowedBundleIds.contains($0.bundleIdentifier) }
        AppBlockerService.shared.startMonitoring(blockedApps: activeBlockedApps)
        
        // El Watchdog se encarga de interceptar URLs completas con rutas y subdominios
        let allActiveBlocked = settings.blockedWebsites.filter { $0.isEnabled }.map { $0.domain }
        BrowserWatchdogService.shared.start(
            blockedDomains: allActiveBlocked,
            allowedDomains: allowedDomains,
            isWhitelistMode: isTotalBlock
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
}
