import Foundation

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
    
    public init(
        dateString: String,
        focusMinutes: Int = 0,
        sessionsCompletedCount: Int = 0,
        interceptionsCount: Int = 0,
        interceptionsBySource: [String: Int] = [:]
    ) {
        self.dateString = dateString
        self.focusMinutes = focusMinutes
        self.sessionsCompletedCount = sessionsCompletedCount
        self.interceptionsCount = interceptionsCount
        self.interceptionsBySource = interceptionsBySource
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
    
    public init(
        currentStreakDays: Int = 0,
        bestStreakDays: Int = 0,
        lastActiveDateString: String? = nil,
        dailyTargetMinutes: Int = 60,
        totalFocusMinutesAllTime: Int = 0,
        totalInterceptionsAllTime: Int = 0,
        dailyRecords: [String: DailyFocusRecord] = [:],
        recentInterceptions: [InterceptionEvent] = []
    ) {
        self.currentStreakDays = currentStreakDays
        self.bestStreakDays = bestStreakDays
        self.lastActiveDateString = lastActiveDateString
        self.dailyTargetMinutes = dailyTargetMinutes
        self.totalFocusMinutesAllTime = totalFocusMinutesAllTime
        self.totalInterceptionsAllTime = totalInterceptionsAllTime
        self.dailyRecords = dailyRecords
        self.recentInterceptions = recentInterceptions
    }
}
