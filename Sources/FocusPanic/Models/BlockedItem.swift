import Foundation

// MARK: - Modelos de Bloqueo

public struct BlockedWebsite: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var domain: String
    public var name: String
    public var category: WebsiteCategory
    public var isEnabled: Bool
    public var isCustom: Bool

    public init(
        id: UUID = UUID(),
        domain: String,
        name: String,
        category: WebsiteCategory = .custom,
        isEnabled: Bool = true,
        isCustom: Bool = false
    ) {
        self.id = id
        self.domain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = name
        self.category = category
        self.isEnabled = isEnabled
        self.isCustom = isCustom
    }
}

public enum FocusBlockingMode: String, Codable, CaseIterable, Identifiable {
    case selective = "Bloqueo Selectivo"
    case whitelistOnly = "Bloqueo Total (Solo Lista Blanca)"
    
    public var id: String { rawValue }
    
    public var subtitle: String {
        switch self {
        case .selective:
            return "Bloquea las distracciones seleccionadas en tus listas."
        case .whitelistOnly:
            return "Bloquea TODO Internet y apps excepto tu Lista Blanca de trabajo."
        }
    }
    
    public var iconName: String {
        switch self {
        case .selective: return "shield.lefthalf.filled"
        case .whitelistOnly: return "lock.shield.fill"
        }
    }
}

public enum WebsiteCategory: String, Codable, CaseIterable, Identifiable {
    case productivity = "Productividad & Estudio"
    case social = "Redes Sociales"
    case video = "Streaming y Video"
    case news = "Noticias y Foros"
    case gaming = "Zona de Juegos"
    case shopping = "Compras"
    case custom = "Personalizados"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .productivity: return "briefcase.fill"
        case .social: return "bubble.left.and.bubble.right.fill"
        case .video: return "play.tv.fill"
        case .news: return "newspaper.fill"
        case .gaming: return "gamecontroller.fill"
        case .shopping: return "cart.fill"
        case .custom: return "globe"
        }
    }
    
    public var colorHex: String {
        switch self {
        case .productivity: return "#10B981" // Esmeralda
        case .social: return "#3B82F6" // Azul
        case .video: return "#EF4444" // Rojo
        case .news: return "#F59E0B" // Ámbar
        case .gaming: return "#8B5CF6" // Morado
        case .shopping: return "#EC4899" // Rosa
        case .custom: return "#64748B" // Slate
        }
    }
}

public struct BlockedApp: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var bundleIdentifier: String
    public var appName: String
    public var appPath: String
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        appPath: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.appPath = appPath
        self.isEnabled = isEnabled
    }
}

// MARK: - Presets de Enfoque TDAH

public struct FocusPreset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var durationMinutes: Int
    public var subtitle: String
    public var iconName: String
    public var colorHex: String

    public init(
        id: UUID = UUID(),
        name: String,
        durationMinutes: Int,
        subtitle: String,
        iconName: String,
        colorHex: String = "#FF5A5F"
    ) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.subtitle = subtitle
        self.iconName = iconName
        self.colorHex = colorHex
    }

    public static let defaultPresets: [FocusPreset] = [
        FocusPreset(name: "Micro-Sprint", durationMinutes: 15, subtitle: "Superar la inercia inicial", iconName: "bolt.fill", colorHex: "#34C759"),
        FocusPreset(name: "Pomodoro TDAH", durationMinutes: 25, subtitle: "Sprint de concentración óptimo", iconName: "timer", colorHex: "#FF9500"),
        FocusPreset(name: "Enfoque Profundo", durationMinutes: 45, subtitle: "Para tareas complejas", iconName: "brain.head.profile", colorHex: "#AF52DE"),
        FocusPreset(name: "Modo Hiperfoco", durationMinutes: 90, subtitle: "Inmersión total sin ruidos", iconName: "flame.fill", colorHex: "#FF2D55"),
        FocusPreset(name: "Bloqueo Total", durationMinutes: 120, subtitle: "Aislamiento radical de emergencia", iconName: "lock.shield.fill", colorHex: "#10B981")
    ]
}

// MARK: - Estado de la Sesión

public enum SessionStatus: String, Codable {
    case idle
    case active
    case unlockPending
    case completed
}

public struct FocusSession: Codable {
    public var startTime: Date
    public var targetEndTime: Date
    public var originalDurationSeconds: TimeInterval
    public var presetName: String
    public var isEmergencyUnlocked: Bool

    public var remainingSeconds: TimeInterval {
        max(0, targetEndTime.timeIntervalSince(Date()))
    }

    public var progress: Double {
        guard originalDurationSeconds > 0 else { return 0 }
        let elapsed = originalDurationSeconds - remainingSeconds
        return min(1.0, max(0.0, elapsed / originalDurationSeconds))
    }

    public var isFinished: Bool {
        Date() >= targetEndTime
    }

    public init(durationMinutes: Int, presetName: String = "Personalizado") {
        let now = Date()
        self.startTime = now
        let duration = TimeInterval(durationMinutes * 60)
        self.originalDurationSeconds = duration
        self.targetEndTime = now.addingTimeInterval(duration)
        self.presetName = presetName
        self.isEmergencyUnlocked = false
    }
}
