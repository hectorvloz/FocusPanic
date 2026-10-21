import SwiftUI

@main
struct FocusPanicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            // La escena `Settings` está vacía (los ajustes viven en la ventana
            // principal): sin esto, «Ajustes…» / ⌘, abría una ventana en blanco.
            CommandGroup(replacing: .appSettings) {}
            CommandGroup(replacing: .appInfo) {
                Button("Acerca de FocusPanic") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "FocusPanic",
                            NSApplication.AboutPanelOptionKey.version: UpdateManager.shared.currentVersion,
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Diseñado para enfoque y TDAH"
                        ]
                    )
                }
                
                Divider()
                
                Button("Buscar Actualizaciones...") {
                    UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                }
            }
        }
    }
}
