import AppKit
import SwiftUI

public struct VisualEffectBackground: NSViewRepresentable {
    public init() {}
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
