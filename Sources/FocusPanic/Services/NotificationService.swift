import AppKit
import Foundation
import UserNotifications

public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
    
    public func sendNotification(title: String, body: String, sound: String = "Glass") {
        DispatchQueue.main.async {
            // 1. Reproducir sonido del sistema
            if !sound.isEmpty {
                NSSound(named: sound)?.play()
            }
            
            // 2. Enviar mediante UNUserNotificationCenter (usa el icono oficial de la app)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if error != nil {
                    // Fallback a AppleScript si no estuviese concedido
                    let cleanTitle = title.replacingOccurrences(of: "\"", with: "'")
                    let cleanBody = body.replacingOccurrences(of: "\"", with: "'")
                    let scriptSource = """
                    display notification "\(cleanBody)" with title "\(cleanTitle)" sound name "\(sound)"
                    """
                    if let script = NSAppleScript(source: scriptSource) {
                        var err: NSDictionary?
                        script.executeAndReturnError(&err)
                    }
                }
            }
        }
    }
}
