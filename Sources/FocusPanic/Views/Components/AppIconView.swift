import AppKit
import SwiftUI

public struct AppIconView: View {
    let app: BlockedApp
    let size: CGFloat
    
    public init(app: BlockedApp, size: CGFloat = 36) {
        self.app = app
        self.size = size
    }
    
    public var body: some View {
        if let iconImage = AppIconCache.shared.icon(for: app, size: size) {
            Image(nsImage: iconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .cornerRadius(size * 0.22)
                .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: size, height: size)
                
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(.secondary)
            }
        }
    }
}
