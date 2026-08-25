import AppKit
import Foundation

public final class NotificationService {
    public static let shared = NotificationService()
    
    private init() {}
    
    public func sendNotification(title: String, body: String, sound: String = "Glass") {
        DispatchQueue.main.async {
            // 1. Reproducir sonido del sistema
            if !sound.isEmpty {
                NSSound(named: sound)?.play()
            }
            
            // 2. Enviar notificación nativa visual mediante AppleScript (100% infalible en macOS)
            let cleanTitle = title.replacingOccurrences(of: "\"", with: "'")
            let cleanBody = body.replacingOccurrences(of: "\"", with: "'")
            let scriptSource = """
            display notification "\(cleanBody)" with title "\(cleanTitle)" sound name "\(sound)"
            """
            
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let script = NSAppleScript(source: scriptSource) {
                    script.executeAndReturnError(&error)
                }
            }
        }
    }
}
