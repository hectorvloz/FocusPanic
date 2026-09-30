import AppKit
import SwiftUI

public final class WhatsAppStatusInterventionWindow: NSWindowController {
    public static let shared = WhatsAppStatusInterventionWindow()
    
    private var panel: NSPanel?
    private var isCurrentlyVisible = false
    
    private init() {
        super.init(window: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    public func show(mode: WhatsAppBlockMode = .status) {
        guard !isCurrentlyVisible else { return }
        
        let contentView = WhatsAppStatusInterventionView(mode: mode, onClose: { [weak self] in
            self?.hide()
        })
        
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 24
        hostingController.view.layer?.masksToBounds = true
        
        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.contentViewController = hostingController
        newPanel.contentView?.wantsLayer = true
        newPanel.contentView?.layer?.cornerRadius = 24
        newPanel.contentView?.layer?.masksToBounds = true
        newPanel.isMovableByWindowBackground = true
        
        // Centrar perfectamente en la pantalla principal
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - 220
            let y = screenRect.midY - 210
            newPanel.setFrame(NSRect(x: x, y: y, width: 440, height: 420), display: true)
        } else {
            newPanel.center()
        }
        
        self.panel = newPanel
        self.window = newPanel
        self.isCurrentlyVisible = true
        
        // Animación suave de entrada
        newPanel.alphaValue = 0.0
        newPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            newPanel.animator().alphaValue = 1.0
        }
    }
    
    @MainActor
    public func hide() {
        guard isCurrentlyVisible, let panel = self.panel else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.panel = nil
            self?.window = nil
            self?.isCurrentlyVisible = false
        })
    }
}
