import SwiftUI

@main
struct FocusPanicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
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
