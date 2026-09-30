import Foundation
import ServiceManagement
import AppKit

public final class LaunchAtLoginService {
    public static let shared = LaunchAtLoginService()
    
    private init() {}
    
    /// Activa o desactiva el inicio automático de FocusPanic al arrancar macOS
    public func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        print("🚀 [FocusPanic] SMAppService registrado exitosamente para inicio con macOS.")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        print("🚀 [FocusPanic] SMAppService desregistrado exitosamente.")
                    }
                }
            } catch {
                print("⚠️ [FocusPanic] SMAppService lanzó error: \(error.localizedDescription). Aplicando fallback AppleScript.")
                applyAppleScriptFallback(enabled: enabled)
            }
        } else {
            applyAppleScriptFallback(enabled: enabled)
        }
    }
    
    private func applyAppleScriptFallback(enabled: Bool) {
        let appPath = Bundle.main.bundlePath
        let appName = "FocusPanic"
        
        if enabled {
            let script = """
            tell application "System Events"
                if not (exists login item "\(appName)") then
                    make new login item at end of login items with properties {path:"\(appPath)", hidden:false, name:"\(appName)"}
                end if
            end tell
            """
            _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
        } else {
            let script = """
            tell application "System Events"
                if exists login item "\(appName)" then
                    delete login item "\(appName)"
                end if
            end tell
            """
            _ = NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
    }
}
