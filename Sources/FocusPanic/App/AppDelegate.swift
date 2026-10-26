import AppKit
import Combine
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Asegurar que la app viva en el Dock y tenga ventana inicialmente
        NSApp.setActivationPolicy(.regular)
        
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImg = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImg
        }
        
        setupStatusBarItem()
        setupMenuBarBinding()
        
        // Iniciar servidor local de página de bloqueo motivacional
        LocalInterventionServer.shared.start()
        
        // Sincronizar inicio automático con macOS
        LaunchAtLoginService.shared.updateLaunchAtLogin(enabled: FocusEngine.shared.settings.launchAtLogin)
        
        setupGuardian()
        
        // Abrir la ventana principal al iniciar
        DispatchQueue.main.async { [weak self] in
            self?.openMainWindow()
        }
        
        // La escena vacía de Ajustes de SwiftUI puede abrirse sola al relanzar
        // la app (restauración de ventanas): se cierra en cuanto aparece.
        closeEmptySettingsWindows()
        settingsWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeEmptySettingsWindows()
        }
        
        // Comprobar actualizaciones de software en segundo plano
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            if FocusEngine.shared.settings.autoCheckForUpdates {
                UpdateManager.shared.checkForUpdates(isUserInitiated: false)
            }
        }
        
        // Detectar si el sistema macOS se va a apagar o reiniciar para no interrumpir el apagado
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willPowerOffNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isSystemPoweringOff = true
            }
        }
        
        // Manejar suspensión (Sleep) y reanudación (Wake) de macOS para evitar bloqueos/congelamientos de hilos y sockets
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("💤 [FocusPanic] Mac suspendido: pausando vigilancia...")
            BrowserWatchdogService.shared.stop()
            WhatsAppStatusWatcherService.shared.stop()
            LocalInterventionServer.shared.stop()
        }
        
        // Escuchar solicitudes de sesión desde InnotchBar mediante notificaciones distribuidas
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.focuspanic.startSession"),
            object: nil,
            queue: .main
        ) { notification in
            let minutesStr = notification.userInfo?["minutes"] as? String ?? "25"
            let preset = notification.userInfo?["preset"] as? String ?? "Personalizado"
            let minutes = Int(minutesStr) ?? 25
            DispatchQueue.main.async {
                FocusEngine.shared.startFocusSession(durationMinutes: minutes, presetName: preset)
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.focuspanic.endSession"),
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                FocusEngine.shared.endSession(didCompleteNormally: false)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("☀️ [FocusPanic] Mac despertado: reiniciando subsistemas y restaurando protección...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                FocusEngine.shared.restartSubsystems()
            }
        }
    }
    
    public func applicationDidBecomeActive(_ notification: Notification) {
        let visibleWindows = NSApp.windows.filter { !($0 is NSPanel) && $0.className != "NSPopoverWindow" && $0.isVisible }
        if visibleWindows.isEmpty {
            openMainWindow()
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow()
        return true
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // La app debe seguir viva en segundo plano y en la barra de menús
        return false
    }
    
    private var settingsWindowObserver: NSObjectProtocol?
    
    private func closeEmptySettingsWindows() {
        for window in NSApp.windows where window.identifier?.rawValue.contains("Settings_window") == true {
            window.close()
        }
    }
    
    private var isAuthorizedToTerminate = false
    private var isSystemPoweringOff = false
    
    /// Permite cerrar la app sin volver a pedir el PIN (p. ej. tras desinstalar con PIN).
    public func authorizeTermination() {
        isAuthorizedToTerminate = true
    }
    
    // MARK: - Guardián (helper v2 + LaunchDaemon que relanza la app)
    
    private let lastBackedUpVersionKey = "FocusPanic_GuardBackupVersion"
    
    private func setupGuardian() {
        let guardService = GuardService.shared
        let engine = FocusEngine.shared
        
        // Instalaciones con el helper antiguo: ofrecer la actualización (pide la contraseña de admin una vez)
        if HostBlockerService.shared.isHelperInstalled && !guardService.isActive {
            let alert = NSAlert()
            alert.messageText = "Actualizar la protección de FocusPanic"
            alert.informativeText = "La nueva protección guarda el PIN de tu compañero fuera del alcance de otros programas (incluidos agentes de IA) y vuelve a abrir FocusPanic si alguien lo cierra o lo mata sin el PIN. macOS te pedirá tu contraseña de administrador una sola vez."
            alert.addButton(withTitle: "Actualizar Ahora")
            alert.addButton(withTitle: "Más Tarde")
            if alert.runModal() == .alertFirstButtonReturn {
                do {
                    try HostBlockerService.shared.installHelper()
                } catch {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "No se pudo actualizar la protección"
                    errorAlert.informativeText = error.localizedDescription
                    errorAlert.runModal()
                }
            }
        }
        
        guard guardService.isActive else { return }
        // Si se reabrió antes de que acabe una pausa autorizada, el resto de la pausa ya no aplica
        guardService.resumeGuardian()
        engine.migrateCompanionSecretsToGuardIfNeeded()
        
        // Mantener al día la copia de respaldo que el guardián restaura si borran la app
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if UserDefaults.standard.string(forKey: lastBackedUpVersionKey) != currentVersion {
            guardService.syncAppBackup()
            UserDefaults.standard.set(currentVersion, forKey: lastBackedUpVersionKey)
        }
        
        if let detail = guardService.unreportedTamperEvent() {
            let partner = engine.settings.officialPartnerEmail
            if engine.settings.isPartnerAlertUninstallEnabled && !partner.isEmpty {
                EmailService.shared.sendTamperAlert(toEmail: partner, actionDetail: detail)
            }
        }
    }
    
    public func authorizeAndRelaunch() {
        isAuthorizedToTerminate = true
        let bundlePath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", bundlePath]
        try? process.run()
        NSApp.terminate(nil)
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // 1. Si el Mac se está apagando o reiniciando, permitir el cierre inmediato del sistema
        if isSystemPoweringOff {
            BrowserWatchdogService.shared.stop()
            AppBlockerService.shared.stopMonitoring()
            LocalInterventionServer.shared.stop()
            return .terminateNow
        }
        
        // 2. Si el usuario ya fue autorizado por el PIN del compañero
        if isAuthorizedToTerminate {
            cleanupBeforeExit()
            return .terminateNow
        }
        
        let engine = FocusEngine.shared
        
        // 3. Si la clave del compañero está activa, solicitar el PIN directamente para autorizar el cierre manual (Cmd+Q o Quit)
        if engine.isCompanionPinEnforced {
            promptCompanionPasswordForExit()
            return .terminateCancel
        }
        
        if engine.sessionStatus == .active {
            let alert = NSAlert()
            alert.messageText = "¿Detener sesión y salir?"
            alert.informativeText = "Tienes una sesión de enfoque activa. Al salir se desbloquearán las distracciones hasta que vuelvas a abrir la app."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Detener y Salir")
            alert.addButton(withTitle: "Seguir Enfocado")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                engine.endSession(didCompleteNormally: false)
                _ = GuardService.shared.pauseGuardian(pin: "")
                cleanupBeforeExit()
                return .terminateNow
            } else {
                return .terminateCancel
            }
        }
        
        // Sin PIN configurado el guardián acepta la pausa sin clave; con PIN esto no llega a ejecutarse
        _ = GuardService.shared.pauseGuardian(pin: "")
        cleanupBeforeExit()
        return .terminateNow
    }
    
    private func promptCompanionPasswordForExit() {
        let alert = NSAlert()
        alert.messageText = "FocusPanic Protegido"
        alert.informativeText = GuardService.shared.isActive
            ? "No está permitido cerrar FocusPanic para evitar burlar los bloqueos. Tu compañero debe ingresar su PIN para autorizar el cierre. FocusPanic se volverá a abrir solo en \(GuardService.exitPauseMinutes) minutos."
            : "No está permitido cerrar FocusPanic para evitar burlar los bloqueos. Tu compañero debe ingresar su PIN de 4 dígitos para autorizar el cierre:"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Autorizar y Cerrar App")
        alert.addButton(withTitle: "Cancelar")
        
        let inputField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        inputField.placeholderString = "PIN de tu compañero"
        alert.accessoryView = inputField
        
        alert.window.initialFirstResponder = inputField
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let entered = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            var result = FocusEngine.shared.checkCompanionSecret(entered)
            if result == .ok && GuardService.shared.isActive {
                // Sin esta pausa el guardián volvería a abrir la app a los pocos segundos
                result = GuardService.shared.pauseGuardian(pin: entered)
            }
            
            if result == .ok {
                SoundService.shared.play("Hero")
                isAuthorizedToTerminate = true
                cleanupBeforeExit()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NSApplication.shared.terminate(nil)
                }
            } else {
                SoundService.shared.play("Basso")
                let partner = FocusEngine.shared.settings.officialPartnerEmail
                if FocusEngine.shared.settings.isPartnerAlertUninstallEnabled && !partner.isEmpty {
                    EmailService.shared.sendTamperAlert(
                        toEmail: partner,
                        actionDetail: "Intento no autorizado de cerrar la aplicación FocusPanic (PIN incorrecto)."
                    )
                }
                
                let errorAlert = NSAlert()
                errorAlert.messageText = "Clave Incorrecta"
                errorAlert.informativeText = "\(GuardService.message(for: result)) FocusPanic continuará ejecutándose para proteger tu enfoque."
                errorAlert.alertStyle = .critical
                errorAlert.addButton(withTitle: "Entendido")
                errorAlert.runModal()
            }
        }
    }
    
    private func cleanupBeforeExit() {
        // Restaurar estado del sistema de forma limpia al salir
        try? HostBlockerService.shared.removeBlock()
        BrowserWatchdogService.shared.stop()
        AppBlockerService.shared.stopMonitoring()
        LocalInterventionServer.shared.stop()
    }
    
    private func setupStatusBarItem() {
        // Crear el item en la barra superior con longitud automática
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        guard let button = statusItem?.button else { return }
        
        // Configurar icono nítido y compatible con tema claro/oscuro
        if let image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "FocusPanic") {
            image.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
        }
        
        button.title = ""
        button.target = self
        button.action = #selector(togglePopover)
        
        // Popover con la consola de control rápido estilo Centro de Control de Apple
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 230)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
        self.popover = popover
    }
    
    private func setupMenuBarBinding() {
        FocusEngine.shared.$sessionStatus
            .combineLatest(FocusEngine.shared.$remainingSeconds)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status, remaining in
                guard let self = self, let button = self.statusItem?.button else { return }
                
                if status == .active {
                    let total = Int(remaining)
                    let mins = total / 60
                    let secs = total % 60
                    button.title = String(format: " %02d:%02d", mins, secs)
                    if let flameImage = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Enfoque Activo") {
                        flameImage.isTemplate = true
                        button.image = flameImage
                    }
                } else {
                    button.title = ""
                    if let brainImage = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "FocusPanic") {
                        brainImage.isTemplate = true
                        button.image = brainImage
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private var eventMonitor: Any?
    
    @objc public func togglePopover() {
        guard let popover = popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }
    
    private func showPopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }
    
    public func closePopover() {
        popover?.close()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private var mainWindowController: NSWindowController?
    
    public func getOrCreateMainWindow() -> NSWindow {
        if let controller = mainWindowController, let window = controller.window {
            return window
        }
        
        let dashboard = MainDashboardView()
            .frame(minWidth: 780, minHeight: 620)
        let hostingView = NSHostingView(rootView: dashboard)
        
        let newWin = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 840, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWin.title = "FocusPanic"
        newWin.titleVisibility = .hidden
        newWin.titlebarAppearsTransparent = true
        newWin.isReleasedWhenClosed = false
        newWin.contentView = hostingView
        newWin.center()
        newWin.delegate = self
        
        let controller = NSWindowController(window: newWin)
        self.mainWindowController = controller
        return newWin
    }
    
    public func openMainWindow() {
        closePopover()
        
        NSApp.setActivationPolicy(.regular)
        
        let window = getOrCreateMainWindow()
        window.isReleasedWhenClosed = false
        window.delegate = self
        
        mainWindowController?.showWindow(nil)
        window.setIsVisible(true)
        window.deminiaturize(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.isReleasedWhenClosed = false
        sender.orderOut(nil)
        return false
    }
}
