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
        
        // Asegurar que la app viva en el Dock y tenga ventana
        NSApp.setActivationPolicy(.regular)
        
        // Asignar icono explícito para el Dock
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "png") ?? Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImg = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImg
        }
        
        setupStatusBarItem()
        setupMenuBarBinding()
        
        // Iniciar servidor local de página de bloqueo motivacional
        LocalInterventionServer.shared.start()
    }
    
    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // La app debe seguir viva en segundo plano y en la barra de menús
        return false
    }
    
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let engine = FocusEngine.shared
        
        // Si la clave del compañero está activa, NUNCA permitir cerrar la app sin su PIN
        if engine.settings.isMasterPasswordEnabled && !engine.settings.masterCompanionPassword.isEmpty {
            let alert = NSAlert()
            alert.messageText = "FocusPanic Protegido"
            alert.informativeText = "No está permitido cerrar FocusPanic para evitar burlar los bloqueos. Tu compañero debe autorizar el cierre con su PIN."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Ingresar Clave del Compañero")
            alert.addButton(withTitle: "Cancelar")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                openMainWindow()
                engine.initiateEmergencyUnlock()
            }
            return .terminateCancel
        }
        
        if engine.sessionStatus == .active {
            let alert = NSAlert()
            alert.messageText = "¿Detener sesión y salir?"
            alert.informativeText = "Tienes una sesión de enfoque activa. Al salir se desbloquearán las distracciones."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Detener y Salir")
            alert.addButton(withTitle: "Seguir Enfocado")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                engine.endSession(didCompleteNormally: false)
                return .terminateNow
            } else {
                return .terminateCancel
            }
        }
        return .terminateNow
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
        button.action = #selector(togglePopover)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        
        // Popover con la consola de control rápido
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 360)
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
    
    @objc public func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Actualizar vista y mostrar anclado al botón
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    
    public func closePopover() {
        popover?.performClose(nil)
    }
    
    public func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
}
