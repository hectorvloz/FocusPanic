import AppKit
import Foundation

public final class AppIconCache {
    public static let shared = AppIconCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 150
    }
    
    public func icon(for app: BlockedApp, size: CGFloat = 36) -> NSImage? {
        let cacheKey = "\(app.bundleIdentifier)_\(Int(size))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        
        let fileManager = FileManager.default
        var loadedImage: NSImage?
        
        // 1. Intentar por appPath
        if !app.appPath.isEmpty && fileManager.fileExists(atPath: app.appPath) {
            loadedImage = NSWorkspace.shared.icon(forFile: app.appPath)
        }
        // 2. Intentar por Bundle ID
        else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            loadedImage = NSWorkspace.shared.icon(forFile: url.path)
        }
        // 3. Fallback rutas conocidas
        else {
            let candidates = [
                "/Applications/\(app.appName).app",
                "/System/Applications/\(app.appName).app",
                "/System/Applications/Utilities/\(app.appName).app"
            ]
            for path in candidates {
                if fileManager.fileExists(atPath: path) {
                    loadedImage = NSWorkspace.shared.icon(forFile: path)
                    break
                }
            }
        }
        
        if let image = loadedImage {
            image.size = NSSize(width: size * 2, height: size * 2)
            cache.setObject(image, forKey: cacheKey)
            return image
        }
        
        return nil
    }
}
