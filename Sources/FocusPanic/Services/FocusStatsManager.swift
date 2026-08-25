import Foundation

public final class FocusStatsManager: ObservableObject {
    public static let shared = FocusStatsManager()
    
    private let statsKey = "focuspanic_stats_v1"
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone.current
        return df
    }()
    
    @Published public var stats: FocusStats
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let loaded = try? JSONDecoder().decode(FocusStats.self, from: data) {
            self.stats = loaded
        } else {
            self.stats = FocusStats()
        }
        
        self.checkAndRefreshStreak()
    }
    
    public func save() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    private var todayString: String {
        return dateFormatter.string(from: Date())
    }
    
    // MARK: - Registro de Tiempo de Enfoque
    
    public func recordCompletedSession(durationMinutes: Int) {
        guard durationMinutes > 0 else { return }
        
        let today = todayString
        var record = stats.dailyRecords[today] ?? DailyFocusRecord(dateString: today)
        record.focusMinutes += durationMinutes
        record.sessionsCompletedCount += 1
        stats.dailyRecords[today] = record
        
        stats.totalFocusMinutesAllTime += durationMinutes
        
        updateStreakOnActivity(dateString: today)
        save()
    }
    
    // MARK: - Registro de Impulsos / Distracciones Interceptadas
    
    public func recordInterception(source: String, category: String = "social", detail: String = "") {
        let cleanSource = cleanSourceName(source)
        let today = todayString
        
        var record = stats.dailyRecords[today] ?? DailyFocusRecord(dateString: today)
        record.interceptionsCount += 1
        record.interceptionsBySource[cleanSource, default: 0] += 1
        stats.dailyRecords[today] = record
        
        stats.totalInterceptionsAllTime += 1
        
        let event = InterceptionEvent(source: cleanSource, category: category, detail: detail)
        stats.recentInterceptions.insert(event, at: 0)
        if stats.recentInterceptions.count > 100 {
            stats.recentInterceptions = Array(stats.recentInterceptions.prefix(100))
        }
        
        save()
    }
    
    private func cleanSourceName(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("instagram") { return "Instagram" }
        if lower.contains("tiktok") { return "TikTok" }
        if lower.contains("youtube") { return "YouTube" }
        if lower.contains("twitter") || lower.contains("x.com") { return "X (Twitter)" }
        if lower.contains("facebook") { return "Facebook" }
        if lower.contains("reddit") { return "Reddit" }
        if lower.contains("netflix") { return "Netflix" }
        if lower.contains("twitch") { return "Twitch" }
        if lower.contains("discord") { return "Discord" }
        if lower.contains("telegram") { return "Telegram" }
        if lower.contains("incognito") || lower.contains("incógnito") { return "Modo Incógnito" }
        if lower.contains("búsqueda") || lower.contains("termino") || lower.contains("keyword") { return "Búsqueda Prohibida" }
        if lower.contains("porn") || lower.contains("xxx") { return "Sitio Adulto (+18)" }
        
        let cleaned = raw.replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .components(separatedBy: "/").first ?? raw
        return cleaned.capitalized
    }
    
    // MARK: - Lógica de Rachas (Streaks)
    
    private func updateStreakOnActivity(dateString: String) {
        let calendar = Calendar.current
        guard let todayDate = dateFormatter.date(from: dateString) else { return }
        
        if let lastStr = stats.lastActiveDateString, let lastDate = dateFormatter.date(from: lastStr) {
            let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: todayDate)).day ?? 0
            
            if diff == 0 {
                // Mismo día, mantener racha
            } else if diff == 1 {
                // Día consecutivo consecutivo!
                stats.currentStreakDays += 1
                stats.lastActiveDateString = dateString
            } else {
                // Se rompió la racha anterior, reiniciar en 1
                stats.currentStreakDays = 1
                stats.lastActiveDateString = dateString
            }
        } else {
            // Primera sesión registrada
            stats.currentStreakDays = 1
            stats.lastActiveDateString = dateString
        }
        
        if stats.currentStreakDays > stats.bestStreakDays {
            stats.bestStreakDays = stats.currentStreakDays
        }
    }
    
    public func checkAndRefreshStreak() {
        let calendar = Calendar.current
        let todayDate = Date()
        
        if let lastStr = stats.lastActiveDateString, let lastDate = dateFormatter.date(from: lastStr) {
            let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: todayDate)).day ?? 0
            
            // Si pasaron más de 1 día entero sin actividad, la racha expira a 0
            if diff > 1 {
                stats.currentStreakDays = 0
                save()
            }
        }
    }
    
    // MARK: - Consultas para la UI
    
    public var todayFocusMinutes: Int {
        return stats.dailyRecords[todayString]?.focusMinutes ?? 0
    }
    
    public var todayInterceptionsCount: Int {
        return stats.dailyRecords[todayString]?.interceptionsCount ?? 0
    }
    
    public var todaySessionsCount: Int {
        return stats.dailyRecords[todayString]?.sessionsCompletedCount ?? 0
    }
    
    public var topDistractionsToday: [(source: String, count: Int)] {
        let sourceDict = stats.dailyRecords[todayString]?.interceptionsBySource ?? [:]
        return sourceDict.map { (source: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    public var topDistractionsAllTime: [(source: String, count: Int)] {
        var aggregated: [String: Int] = [:]
        for record in stats.dailyRecords.values {
            for (source, count) in record.interceptionsBySource {
                aggregated[source, default: 0] += count
            }
        }
        return aggregated.map { (source: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    public func last7DaysHistory() -> [(date: Date, dayLabel: String, minutes: Int, interceptions: Int, isToday: Bool)] {
        let calendar = Calendar.current
        let now = Date()
        var result: [(date: Date, dayLabel: String, minutes: Int, interceptions: Int, isToday: Bool)] = []
        
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "es_ES")
        weekdayFormatter.dateFormat = "EEE" // Lun, Mar, Mié...
        
        for dayOffset in (0..<7).reversed() {
            if let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) {
                let dateStr = dateFormatter.string(from: targetDate)
                let record = stats.dailyRecords[dateStr]
                let label = weekdayFormatter.string(from: targetDate).capitalized.replacingOccurrences(of: ".", with: "")
                let isToday = dayOffset == 0
                
                result.append((
                    date: targetDate,
                    dayLabel: label,
                    minutes: record?.focusMinutes ?? 0,
                    interceptions: record?.interceptionsCount ?? 0,
                    isToday: isToday
                ))
            }
        }
        return result
    }
}
