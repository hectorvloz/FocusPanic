import Foundation

public struct SocialUsageRecord: Codable, Equatable {
    public var visitsCount: Int
    public var totalSeconds: Int
    
    public init(visitsCount: Int = 0, totalSeconds: Int = 0) {
        self.visitsCount = visitsCount
        self.totalSeconds = totalSeconds
    }
}

public struct InterceptionEvent: Identifiable, Codable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var source: String // ej. "Instagram", "TikTok", "YouTube", "Discord", "Modo Incógnito"
    public var category: String // "social", "video", "adult", "keyword", "app"
    public var detail: String
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        category: String = "social",
        detail: String = ""
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.category = category
        self.detail = detail
    }
}

public struct DailyFocusRecord: Codable, Equatable {
    public var dateString: String // "yyyy-MM-dd"
    public var focusMinutes: Int
    public var sessionsCompletedCount: Int
    public var interceptionsCount: Int
    public var interceptionsBySource: [String: Int] // ["Instagram": 8, "TikTok": 5]
    public var socialUsage: [String: SocialUsageRecord] // ["Instagram": (visits: 18, seconds: 1200)]
    
    public init(
        dateString: String,
        focusMinutes: Int = 0,
        sessionsCompletedCount: Int = 0,
        interceptionsCount: Int = 0,
        interceptionsBySource: [String: Int] = [:],
        socialUsage: [String: SocialUsageRecord] = [:]
    ) {
        self.dateString = dateString
        self.focusMinutes = focusMinutes
        self.sessionsCompletedCount = sessionsCompletedCount
        self.interceptionsCount = interceptionsCount
        self.interceptionsBySource = interceptionsBySource
        self.socialUsage = socialUsage
    }
}

public struct FocusBadge: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var description: String
    public var icon: String
    public var colorHex: String
    
    public init(id: String, name: String, description: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.colorHex = colorHex
    }
    
    public static let allBadges: [FocusBadge] = [
        FocusBadge(id: "first_session", name: "Primer Paso", description: "Completa tu primera sesión de enfoque", icon: "bolt.fill", colorHex: "#F59E0B"),
        FocusBadge(id: "streak_3", name: "Chispa de Enfoque", description: "Alcanza una racha de 3 días seguidos", icon: "flame.fill", colorHex: "#F97316"),
        FocusBadge(id: "streak_7", name: "Racha de Hierro", description: "Mantén 7 días de disciplina inquebrantable", icon: "shield.fill", colorHex: "#EF4444"),
        FocusBadge(id: "streak_30", name: "Titán Imparable", description: "30 días de maestría de atención", icon: "crown.fill", colorHex: "#F59E0B"),
        FocusBadge(id: "interceptions_25", name: "Escudo Mental", description: "Evita 25 impulsos de distracción", icon: "shield.checkered", colorHex: "#10B981"),
        FocusBadge(id: "hours_10", name: "Maestro del Tiempo", description: "Acumula 10 horas totales de enfoque", icon: "hourglass.bottomhalf.filled", colorHex: "#6366F1"),
        FocusBadge(id: "hours_50", name: "Mente Diamante", description: "Acumula 50 horas de hiperfoco", icon: "diamond.fill", colorHex: "#06B6D4")
    ]
}

public struct FocusTier: Equatable {
    public let level: Int
    public let title: String
    public let icon: String
    public let colorHex: String
    public let minXP: Int
    public let maxXP: Int
    
    public static let tiers: [FocusTier] = [
        FocusTier(level: 1, title: "Iniciado", icon: "flame", colorHex: "#F97316", minXP: 0, maxXP: 500),
        FocusTier(level: 2, title: "Aprendiz de Enfoque", icon: "flame.fill", colorHex: "#F59E0B", minXP: 500, maxXP: 1500),
        FocusTier(level: 3, title: "Guerrero de Atención", icon: "bolt.shield.fill", colorHex: "#E11D48", minXP: 1500, maxXP: 3500),
        FocusTier(level: 4, title: "Racha de Hierro", icon: "shield.checkered", colorHex: "#EF4444", minXP: 3500, maxXP: 7000),
        FocusTier(level: 5, title: "Mente Imparable", icon: "diamond.fill", colorHex: "#06B6D4", minXP: 7000, maxXP: 12000),
        FocusTier(level: 6, title: "Monje Digital", icon: "crown.fill", colorHex: "#A855F7", minXP: 12000, maxXP: 25000)
    ]
    
    public static func tier(for xp: Int) -> FocusTier {
        for t in tiers.reversed() {
            if xp >= t.minXP {
                return t
            }
        }
        return tiers[0]
    }
}

public struct FocusStats: Codable, Equatable {
    public var currentStreakDays: Int
    public var bestStreakDays: Int
    public var lastActiveDateString: String? // "yyyy-MM-dd"
    public var dailyTargetMinutes: Int
    public var totalFocusMinutesAllTime: Int
    public var totalInterceptionsAllTime: Int
    public var dailyRecords: [String: DailyFocusRecord]
    public var recentInterceptions: [InterceptionEvent]
    
    // Campos de Gamificación "Racha de Hierro"
    public var totalXP: Int
    public var unlockedBadgeIds: [String]
    public var lastCelebratedTierLevel: Int
    
    public init(
        currentStreakDays: Int = 0,
        bestStreakDays: Int = 0,
        lastActiveDateString: String? = nil,
        dailyTargetMinutes: Int = 60,
        totalFocusMinutesAllTime: Int = 0,
        totalInterceptionsAllTime: Int = 0,
        dailyRecords: [String: DailyFocusRecord] = [:],
        recentInterceptions: [InterceptionEvent] = [],
        totalXP: Int = 0,
        unlockedBadgeIds: [String] = [],
        lastCelebratedTierLevel: Int = 1
    ) {
        self.currentStreakDays = currentStreakDays
        self.bestStreakDays = bestStreakDays
        self.lastActiveDateString = lastActiveDateString
        self.dailyTargetMinutes = dailyTargetMinutes
        self.totalFocusMinutesAllTime = totalFocusMinutesAllTime
        self.totalInterceptionsAllTime = totalInterceptionsAllTime
        self.dailyRecords = dailyRecords
        self.recentInterceptions = recentInterceptions
        self.totalXP = totalXP
        self.unlockedBadgeIds = unlockedBadgeIds
        self.lastCelebratedTierLevel = lastCelebratedTierLevel
    }
}
