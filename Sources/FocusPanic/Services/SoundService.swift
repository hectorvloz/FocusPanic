import AppKit
import Foundation

public final class SoundService {
    public static let shared = SoundService()
    
    private var cachedSounds: [String: NSSound] = [:]
    private let soundQueue = DispatchQueue(label: "com.focuspanic.soundQueue", qos: .userInteractive)
    
    private init() {
        // Pre-cargar todos los efectos de sonido en memoria para evitar tirones en la interfaz
        soundQueue.async { [weak self] in
            let soundNames = ["Tink", "Hero", "Basso", "Pop", "Ping", "Blow", "Bottle", "Frog", "Funk", "Glass", "Morse", "Purr", "Sosumi", "Submarine"]
            for name in soundNames {
                if let sound = NSSound(named: NSSound.Name(name)) {
                    self?.cachedSounds[name] = sound
                }
            }
        }
    }
    
    public func play(_ name: String) {
        guard !name.isEmpty else { return }
        soundQueue.async { [weak self] in
            if let sound = self?.cachedSounds[name] {
                sound.stop()
                sound.play()
            } else if let sound = NSSound(named: NSSound.Name(name)) {
                self?.cachedSounds[name] = sound
                sound.play()
            }
        }
    }
}
