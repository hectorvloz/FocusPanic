import Foundation
import SwiftUI
import AppKit
import Combine

public struct ReleaseInfo: Codable, Equatable, Identifiable {
    public var id: String { tagName }
    public let tagName: String
    public let name: String
    public let body: String
    public let htmlUrl: String
    public let publishedAt: String?
    public let dmgDownloadUrl: String?
    public let dmgFileSize: Int?
    
    public var versionString: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
    }
}

public enum UpdateState: Equatable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(ReleaseInfo)
    case downloading(progress: Double)
    case installing
    case readyToRestart
    case error(String)
}

@MainActor
public final class UpdateManager: NSObject, ObservableObject {
    public static let shared = UpdateManager()
    
    @Published public var state: UpdateState = .idle
    @Published public var latestRelease: ReleaseInfo? = nil
    @Published public var isUpdateSheetPresented: Bool = false
    @Published public var isBannerVisible: Bool = false
    @Published public var lastCheckDate: Date? = nil
    
    private let repo = "hectorvloz/FocusPanic"
    private var downloadTask: URLSessionDownloadTask?
    private var downloadObservation: NSKeyValueObservation?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0"
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Comprobación de Versiones
    public static func isVersion(_ remote: String, greaterThan local: String) -> Bool {
        let cleanRemote = remote.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let cleanLocal = local.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        
        let remoteParts = cleanRemote.split(separator: ".").compactMap { Int($0) }
        let localParts = cleanLocal.split(separator: ".").compactMap { Int($0) }
        
        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
    
    // MARK: - Buscar Actualizaciones
    public func checkForUpdates(isUserInitiated: Bool = false) {
        guard state != .checking && !isDownloadingNow else { return }
        
        state = .checking
        if isUserInitiated {
            isUpdateSheetPresented = true
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            state = .error("URL de repositorio no válida")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("FocusPanic-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.lastCheckDate = Date()
                
                if let error = error {
                    self.state = .error("Error al conectar con GitHub: \(error.localizedDescription)")
                    return
                }
                
                guard let data = data else {
                    self.state = .error("No se recibieron datos de GitHub")
                    return
                }
                
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let tagName = json["tag_name"] as? String else {
                        self.state = .error("Respuesta de actualización no válida")
                        return
                    }
                    
                    let name = json["name"] as? String ?? tagName
                    let body = json["body"] as? String ?? ""
                    let htmlUrl = json["html_url"] as? String ?? "https://github.com/\(self.repo)/releases/latest"
                    let publishedAt = json["published_at"] as? String
                    
                    var dmgUrl: String? = nil
                    var dmgSize: Int? = nil
                    
                    if let assets = json["assets"] as? [[String: Any]] {
                        for asset in assets {
                            if let assetName = asset["name"] as? String,
                               assetName.lowercased().hasSuffix(".dmg"),
                               let downloadUrl = asset["browser_download_url"] as? String {
                                dmgUrl = downloadUrl
                                dmgSize = asset["size"] as? Int
                                break
                            }
                        }
                    }
                    
                    let release = ReleaseInfo(
                        tagName: tagName,
                        name: name,
                        body: body,
                        htmlUrl: htmlUrl,
                        publishedAt: publishedAt,
                        dmgDownloadUrl: dmgUrl,
                        dmgFileSize: dmgSize
                    )
                    
                    let hasNewVersion = UpdateManager.isVersion(release.versionString, greaterThan: self.currentVersion)
                    
                    if hasNewVersion {
                        self.latestRelease = release
                        self.state = .updateAvailable(release)
                        self.isBannerVisible = true
                        if isUserInitiated {
                            self.isUpdateSheetPresented = true
                        } else {
                            NotificationService.shared.sendNotification(
                                title: "🚀 Nueva Versión de FocusPanic",
                                body: "FocusPanic \(release.tagName) ya está disponible con mejoras de enfoque. Haz clic para actualizar.",
                                sound: "Glass"
                            )
                        }
                    } else {
                        self.latestRelease = nil
                        self.state = .upToDate(currentVersion: self.currentVersion)
                    }
                } catch {
                    self.state = .error("Error decodificando versión: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    private var isDownloadingNow: Bool {
        if case .downloading = state { return true }
        if case .installing = state { return true }
        return false
    }
    
    // MARK: - Descarga e Instalación Automática
    public func startDownloadAndInstall() {
        guard let release = latestRelease,
              let downloadUrlString = release.dmgDownloadUrl,
              let downloadUrl = URL(string: downloadUrlString) else {
            // Si no hay URL directa de DMG, abrir en el navegador
            openReleasePage()
            return
        }
        
        state = .downloading(progress: 0.01)
        isUpdateSheetPresented = true
        
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("FocusPanic_Update.dmg")
        try? FileManager.default.removeItem(at: destination)
        
        let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
        
        let task = session.downloadTask(with: downloadUrl) { [weak self] localURL, response, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.state = .error("Error en la descarga: \(error.localizedDescription)")
                    return
                }
                
                guard let localURL = localURL else {
                    self.state = .error("Archivo descargado no encontrado")
                    return
                }
                
                do {
                    try FileManager.default.moveItem(at: localURL, to: destination)
                    self.executeSilentInstaller(dmgPath: destination.path)
                } catch {
                    self.state = .error("Error guardando instalador: \(error.localizedDescription)")
                }
            }
        }
        
        // Observar progreso
        downloadObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.state = .downloading(progress: progress.fractionCompleted)
            }
        }
        
        self.downloadTask = task
        task.resume()
    }
    
    // MARK: - Ejecutar Reemplazo e Instalación de App
    private func executeSilentInstaller(dmgPath: String) {
        state = .installing
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let mountPoint = "/tmp/FocusPanicUpdateMount"
            let targetDir = FileManager.default.isWritableFile(atPath: "/Applications") ? "/Applications" : ("\(NSHomeDirectory())/Applications")
            let targetApp = "\(targetDir)/FocusPanic.app"
            
            // Script de actualización atómico
            let script = """
            #!/bin/bash
            set -e
            DMG="\(dmgPath)"
            MOUNT="\(mountPoint)"
            TARGET_APP="\(targetApp)"
            
            # 1. Desmontar si existía previo
            hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
            rm -rf "$MOUNT"
            mkdir -p "$MOUNT"
            
            # 2. Montar DMG
            hdiutil attach -nobrowse -quiet -mountpoint "$MOUNT" "$DMG"
            
            # 3. Reemplazar App
            if [ -d "$MOUNT/FocusPanic.app" ]; then
                rm -rf "$TARGET_APP"
                cp -R "$MOUNT/FocusPanic.app" "$TARGET_APP"
            fi
            
            # 4. Desmontar y limpiar
            hdiutil detach "$MOUNT" -quiet || true
            rm -rf "$MOUNT" "$DMG"
            
            # 5. Quitar atributos de cuarentena
            xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true
            
            # 6. Reabrir FocusPanic actualizado y terminar el proceso actual
            sleep 1.2
            open -n "$TARGET_APP"
            """
            
            let tempScript = "/tmp/focuspanic_updater.sh"
            try? script.write(toFile: tempScript, atomically: true, encoding: .utf8)
            
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", tempScript]
            try? chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            Task { @MainActor in
                guard let self = self else { return }
                self.state = .readyToRestart
                
                // Ejecutar script en background y cerrar la app limpia para que se reabra
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let runProcess = Process()
                    runProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
                    runProcess.arguments = [tempScript]
                    try? runProcess.run()
                    
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
    
    public func openReleasePage() {
        if let url = URL(string: latestRelease?.htmlUrl ?? "https://github.com/\(repo)/releases/latest") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func dismissUpdate() {
        isBannerVisible = false
        isUpdateSheetPresented = false
    }
}
