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
    @Published public var newlyUnlockedTier: FocusTier? = nil
    @Published public var newlyUnlockedBadge: FocusBadge? = nil
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: statsKey),
           let loaded = try? JSONDecoder().decode(FocusStats.self, from: data) {
            self.stats = loaded
        } else {
            self.stats = FocusStats()
        }
        
        self.checkAndRefreshStreak()
        self.evaluateBadges()
    }
    
    public func save() {
        if let encoded = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(encoded, forKey: statsKey)
        }
    }
    
    public var todayString: String {
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
        
        // Gamificación: +10 XP por minuto completado
        addXP(points: durationMinutes * 10, reason: "Sesión de enfoque de \(durationMinutes)m")
        
        updateStreakOnActivity(dateString: today)
        save()
    }
    
    // MARK: - Registro de Uso Pasivo 24/7 de Redes Sociales (Visitas y Tiempo)
    
    public func recordSocialActivity(source: String, seconds: Int, isNewVisit: Bool) {
        let cleanSource = cleanSourceName(source)
        let today = todayString
        
        var record = stats.dailyRecords[today] ?? DailyFocusRecord(dateString: today)
        var socialUsage = record.socialUsage
        var itemUsage = socialUsage[cleanSource] ?? SocialUsageRecord()
        
        if isNewVisit {
            itemUsage.visitsCount += 1
        }
        itemUsage.totalSeconds += seconds
        
        socialUsage[cleanSource] = itemUsage
        record.socialUsage = socialUsage
        stats.dailyRecords[today] = record
        
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
        
        // Gamificación: +5 XP por impulso interceptado
        addXP(points: 5, reason: "Impulso interceptado (\(cleanSource))")
        
        save()
    }
    
    public func cleanSourceName(_ raw: String) -> String {
        let lower = raw.lowercased()
        
        // 1. Búsquedas y Términos Prohibidos
        if lower.contains("búsqueda") || lower.contains("busqueda") || lower.contains("termino") || lower.contains("término") || lower.contains("keyword") {
            let extracted = raw
                .replacingOccurrences(of: "Búsqueda: ", with: "")
                .replacingOccurrences(of: "busqueda: ", with: "")
                .replacingOccurrences(of: "Búsqueda:", with: "")
                .replacingOccurrences(of: "Termino Prohibido: ", with: "")
                .replacingOccurrences(of: "Termino Prohibido:", with: "")
                .replacingOccurrences(of: "término:", with: "")
                .components(separatedBy: " en ").first ?? raw
            let clean = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && clean.lowercased() != "prohibida" && clean.lowercased() != "prohibido" {
                return "Búsqueda: \"\(clean)\""
            } else {
                return "Búsqueda Prohibida"
            }
        }
        
        // 2. Almacenamiento & Filtraciones (TeraBox, Mega, etc.)
        if lower.contains("terabox") || lower.contains("1024tera") || lower.contains("4funbox") || lower.contains("mirrobox") || lower.contains("nephobox") {
            return "TeraBox"
        }
        if lower.contains("mega.nz") || lower == "mega" { return "Mega" }
        if lower.contains("gofile") { return "Gofile" }
        if lower.contains("pixeldrain") { return "Pixeldrain" }
        if lower.contains("bunkr") { return "Bunkr" }
        if lower.contains("coomer") { return "Coomer" }
        if lower.contains("kemono") { return "Kemono" }
        if lower.contains("fapello") { return "Fapello" }
        if lower.contains("erome") { return "Erome" }
        
        // 3. Sitios para Adultos Específicos
        if lower.contains("pornhub") { return "Pornhub" }
        if lower.contains("xvideos") { return "Xvideos" }
        if lower.contains("xnxx") { return "XNXX" }
        if lower.contains("xhamster") { return "xHamster" }
        if lower.contains("onlyfans") { return "OnlyFans" }
        if lower.contains("chaturbate") { return "Chaturbate" }
        if lower.contains("stripchat") { return "Stripchat" }
        if lower.contains("spankbang") { return "SpankBang" }
        if lower.contains("redtube") { return "RedTube" }
        if lower.contains("youporn") { return "YouPorn" }
        if lower.contains("porn") || lower.contains("xxx") { return "Sitio Adulto (+18)" }
        
        // 4. Redes Sociales & Entretenimiento
        if lower.contains("netflix") { return "Netflix" }
        if lower.contains("instagram") { return "Instagram" }
        if lower.contains("tiktok") { return "TikTok" }
        if lower.contains("youtube") || lower.contains("youtu.be") { return "YouTube" }
        if lower.contains("twitter") || lower.contains("://x.com") || lower.contains(".x.com") || lower.contains("/x.com") || lower == "x.com" { return "X (Twitter)" }
        if lower.contains("facebook") || lower.contains("fb.com") { return "Facebook" }
        if lower.contains("redlib") || lower.contains("libreddit") || lower.contains("teddit") { return "Reddit (Proxy / Redlib)" }
        if lower.contains("reddit") { return "Reddit" }
        if lower.contains("twitch") { return "Twitch" }
        if lower.contains("discord") { return "Discord" }
        if lower.contains("telegram") || lower.contains("t.me") { return "Telegram" }
        if lower.contains("whatsapp") { return "WhatsApp (Estados)" }
        if lower.contains("threads.net") { return "Threads" }
        if lower.contains("incognito") || lower.contains("incógnito") { return "Modo Incógnito" }
        
        // 5. Aplicaciones de IA / Contenedores
        if lower.contains("claude") { return "Claude AI" }
        if lower.contains("chatgpt") || lower.contains("openai") { return "ChatGPT" }
        if lower.contains("gemini") { return "Gemini AI" }
        
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
                addXP(points: 100, reason: "Bono de Racha Diaria 🔥")
            } else {
                // Se rompió la racha anterior, reiniciar en 1
                stats.currentStreakDays = 1
                stats.lastActiveDateString = dateString
                addXP(points: 50, reason: "Nueva Racha Iniciada")
            }
        } else {
            // Primera sesión registrada
            stats.currentStreakDays = 1
            stats.lastActiveDateString = dateString
            addXP(points: 100, reason: "¡Primera Racha Registrada!")
        }
        
        if stats.currentStreakDays > stats.bestStreakDays {
            stats.bestStreakDays = stats.currentStreakDays
        }
        
        evaluateBadges()
    }
    
    // MARK: - Métodos de Gamificación "Racha de Hierro"
    
    public var currentTier: FocusTier {
        return FocusTier.tier(for: stats.totalXP)
    }
    
    public var nextTier: FocusTier? {
        let current = currentTier
        return FocusTier.tiers.first(where: { $0.level == current.level + 1 })
    }
    
    public var tierProgressFraction: Double {
        let current = currentTier
        guard let next = nextTier else { return 1.0 }
        let currentRange = next.minXP - current.minXP
        guard currentRange > 0 else { return 1.0 }
        let earnedInTier = stats.totalXP - current.minXP
        return min(1.0, max(0.0, Double(earnedInTier) / Double(currentRange)))
    }
    
    public var xpNeededForNextTier: Int {
        guard let next = nextTier else { return 0 }
        return max(0, next.minXP - stats.totalXP)
    }
    
    public func addXP(points: Int, reason: String = "") {
        guard points > 0 else { return }
        let oldTier = currentTier
        stats.totalXP += points
        
        let newTier = currentTier
        if newTier.level > oldTier.level {
            stats.lastCelebratedTierLevel = newTier.level
            newlyUnlockedTier = newTier
            let tierTitle = newTier.title
            let tierLevel = newTier.level
            let streak = stats.currentStreakDays
            DispatchQueue.main.async {
                let partner = FocusEngine.shared.settings.officialPartnerEmail
                if FocusEngine.shared.settings.isPartnerAlertAchievementsEnabled && !partner.isEmpty {
                    EmailService.shared.sendAchievementAlert(
                        toEmail: partner,
                        tierTitle: tierTitle,
                        tierLevel: tierLevel,
                        streakDays: streak
                    )
                }
            }
        }
        
        evaluateBadges()
        save()
    }
    
    public func evaluateBadges() {
        var unlocked = Set(stats.unlockedBadgeIds)
        
        // 1. Primer Paso: al menos 10 min de enfoque
        if stats.totalFocusMinutesAllTime >= 10 || stats.dailyRecords.values.contains(where: { $0.sessionsCompletedCount >= 1 }) {
            if !unlocked.contains("first_session") {
                unlocked.insert("first_session")
                notifyBadgeUnlocked(id: "first_session")
            }
        }
        
        // 2. Racha de 3 días
        if stats.currentStreakDays >= 3 || stats.bestStreakDays >= 3 {
            if !unlocked.contains("streak_3") {
                unlocked.insert("streak_3")
                notifyBadgeUnlocked(id: "streak_3")
            }
        }
        
        // 3. Racha de 7 días (Racha de Hierro)
        if stats.currentStreakDays >= 7 || stats.bestStreakDays >= 7 {
            if !unlocked.contains("streak_7") {
                unlocked.insert("streak_7")
                notifyBadgeUnlocked(id: "streak_7")
            }
        }
        
        // 4. Titán 30 días
        if stats.currentStreakDays >= 30 || stats.bestStreakDays >= 30 {
            if !unlocked.contains("streak_30") {
                unlocked.insert("streak_30")
                notifyBadgeUnlocked(id: "streak_30")
            }
        }
        
        // 5. Escudo Mental: 25 intercepciones
        if stats.totalInterceptionsAllTime >= 25 {
            if !unlocked.contains("interceptions_25") {
                unlocked.insert("interceptions_25")
                notifyBadgeUnlocked(id: "interceptions_25")
            }
        }
        
        // 6. Horas 10h (600 min)
        if stats.totalFocusMinutesAllTime >= 600 {
            if !unlocked.contains("hours_10") {
                unlocked.insert("hours_10")
                notifyBadgeUnlocked(id: "hours_10")
            }
        }
        
        // 7. Horas 50h (3000 min)
        if stats.totalFocusMinutesAllTime >= 3000 {
            if !unlocked.contains("hours_50") {
                unlocked.insert("hours_50")
                notifyBadgeUnlocked(id: "hours_50")
            }
        }
        
        stats.unlockedBadgeIds = Array(unlocked)
    }
    
    private func notifyBadgeUnlocked(id: String) {
        if let badge = FocusBadge.allBadges.first(where: { $0.id == id }) {
            newlyUnlockedBadge = badge
            SoundService.shared.play("Hero")
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
    
    public var todaySocialUsageList: [(source: String, visits: Int, minutes: Int, seconds: Int)] {
        let usageMap = stats.dailyRecords[todayString]?.socialUsage ?? [:]
        return usageMap.map { (source: $0.key, visits: $0.value.visitsCount, minutes: $0.value.totalSeconds / 60, seconds: $0.value.totalSeconds) }
            .sorted { $0.seconds > $1.seconds }
    }
    
    public var totalSocialTimeTodayMinutes: Int {
        let usageMap = stats.dailyRecords[todayString]?.socialUsage ?? [:]
        let totalSecs = usageMap.values.reduce(0) { $0 + $1.totalSeconds }
        return totalSecs / 60
    }
    
    public var totalSocialVisitsToday: Int {
        let usageMap = stats.dailyRecords[todayString]?.socialUsage ?? [:]
        return usageMap.values.reduce(0) { $0 + $1.visitsCount }
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
