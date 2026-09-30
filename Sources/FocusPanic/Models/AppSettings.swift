import Foundation

public struct SMTPSettings: Codable, Equatable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String
    public var useSSL: Bool
    public var fromEmail: String

    public init(
        host: String = "smtp.gmail.com",
        port: Int = 587,
        username: String = "",
        password: String = "",
        useSSL: Bool = true,
        fromEmail: String = ""
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.useSSL = useSSL
        self.fromEmail = fromEmail
    }
}

public struct AppSettings: Codable, Equatable {
    public var hasCompletedOnboarding: Bool
    public var recoveryEmail: String
    public var partnerEmail: String
    public var isPartnerEmailEnabled: Bool
    public var isWeeklyReportEnabled: Bool // Enviar reporte semanal automático de enfoque al compañero
    public var lastWeeklyReportDate: Date?
    
    // Alertas Automáticas al Compañero de Responsabilidad (Accountability)
    public var isPartnerAlertKeywordsEnabled: Bool // Alerta por búsqueda de palabras prohibidas
    public var isPartnerAlertUninstallEnabled: Bool // Alerta por intento de manipulación o desinstalación
    public var isPartnerAlertEmergencyUnlockEnabled: Bool // Alerta por cancelación anticipada de sesión
    public var isPartnerAlertIncognitoEnabled: Bool // Alerta por intentos repetidos de navegación privada
    public var isPartnerAlertAchievementsEnabled: Bool // Celebración de rachas y ascensos de nivel
    public var isPartnerAlertSocialLimitEnabled: Bool // Alerta por límite de tiempo diario en redes superado
    
    // Correo oficial unificado del compañero (utilizado para PIN, Reportes y Alertas)
    public var officialPartnerEmail: String {
        let p = partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty { return p }
        return recoveryEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var masterCompanionPassword: String
    public var isMasterPasswordEnabled: Bool
    public var unlockDelayMinutes: Int
    public var reflectionPhrase: String
    public var isReflectionRequired: Bool
    public var isSoundEnabled: Bool
    public var launchAtLogin: Bool
    public var appLanguage: AppLanguage
    public var showMotivationalRedirect: Bool
    public var isAlwaysBlockAdultSites: Bool // Switch del Escudo Anti-Porn (+1,000 sitios)
    public var isForceSafeSearchEnabled: Bool // Forzar SafeSearch estricto en Google, Bing, DuckDuckGo
    public var isAntiIncognitoEnabled: Bool // Cerrar automáticamente ventanas privadas en Safari, Chrome, Brave, Arc, Edge
    public var isKeywordBlockerEnabled: Bool // Interceptar búsquedas con términos prohibidos
    public var isWhatsAppStatusBlockerEnabled: Bool // Interceptar y mostrar popup nativo al ver estados de WhatsApp
    public var isWhatsAppChannelsBlockerEnabled: Bool // Interceptar y mostrar popup nativo al ver canales de WhatsApp
    public var blockedKeywords: [String] // Palabras clave prohibidas en buscadores y redes sociales
    public var permanentBlockedWebsites: [String] // Sitios bloqueados 24/7 permanentemente
    public var permanentBlockedApps: [String] // Apps bloqueadas 24/7 permanentemente
    public var blockedWebsites: [BlockedWebsite]
    public var blockedApps: [BlockedApp]
    public var smtpSettings: SMTPSettings
    public var lastEmergencyCode: String?
    public var lastEmergencyCodeExpiry: Date?

    public static let defaultReflectionPhrase = "Reconozco que este es un impulso de distracción y elijo respirar con calma antes de actuar."

    public static let defaultBlockedKeywords: [String] = [
        "porn", "porno", "xxx", "sex", "sexx", "hentai", "xvideos", "pornhub", "xhamster",
        "redtube", "onlyfans", "erotic", "erotico", "erotica", "nudity", "nude", "nudes",
        "desnuda", "desnudas", "camgirl", "chaturbate", "escort", "stripper", "fetish",
        "milf", "rule34", "nsfw", "brazzers", "youporn", "xnxx",
        "redlib", "libreddit", "teddit", "nitter", "proxitok",
        "casino", "ruleta online", "bet365", "apuestas", "tragaperras", "slots online", "stake casino"
    ]

    public static let defaultWebsites: [BlockedWebsite] = [
        // Redes Sociales Esenciales
        BlockedWebsite(domain: "x.com", name: "X (Twitter)", category: .social),
        BlockedWebsite(domain: "twitter.com", name: "Twitter", category: .social),
        BlockedWebsite(domain: "instagram.com", name: "Instagram", category: .social),
        BlockedWebsite(domain: "facebook.com", name: "Facebook", category: .social),
        BlockedWebsite(domain: "tiktok.com", name: "TikTok", category: .social),
        BlockedWebsite(domain: "threads.net", name: "Threads", category: .social),
        BlockedWebsite(domain: "reddit.com", name: "Reddit", category: .social),
        BlockedWebsite(domain: "youtube.com", name: "YouTube", category: .video),
        BlockedWebsite(domain: "twitch.tv", name: "Twitch", category: .video),
        
        // Juegos Esenciales
        BlockedWebsite(domain: "roblox.com", name: "Roblox", category: .gaming),
        BlockedWebsite(domain: "chess.com", name: "Chess.com", category: .gaming),
        BlockedWebsite(domain: "steampowered.com", name: "Steam Store", category: .gaming),
        BlockedWebsite(domain: "epicgames.com", name: "Epic Games", category: .gaming)
    ]

    public static let defaultApps: [BlockedApp] = [
        BlockedApp(bundleIdentifier: "com.apple.mail", appName: "Mail de Apple", appPath: "/System/Applications/Mail.app", isEnabled: false),
        BlockedApp(bundleIdentifier: "com.hnc.Discord", appName: "Discord", appPath: "/Applications/Discord.app", isEnabled: true),
        BlockedApp(bundleIdentifier: "ru.keepcoder.Telegram", appName: "Telegram", appPath: "/Applications/Telegram.app", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.tinyspeck.slackmacgap", appName: "Slack", appPath: "/Applications/Slack.app", isEnabled: false),
        BlockedApp(bundleIdentifier: "com.spotify.client", appName: "Spotify", appPath: "/Applications/Spotify.app", isEnabled: false),
        BlockedApp(bundleIdentifier: "com.valvesoftware.steam", appName: "Steam", appPath: "/Applications/Steam.app", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.MobileSMS", appName: "Mensajes (iMessage)", appPath: "/System/Applications/Messages.app", isEnabled: false)
    ]

    // Lista Blanca Predeterminada (Sitios de Productividad & Trabajo)
    public static let defaultAllowedWebsites: [BlockedWebsite] = [
        // Meta & Google para Trabajo
        BlockedWebsite(domain: "business.facebook.com", name: "Meta Business Suite", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "adsmanager.facebook.com", name: "Meta Ads Manager", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "developers.facebook.com", name: "Meta for Developers", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "music.youtube.com", name: "YouTube Music", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "analytics.google.com", name: "Google Analytics", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "ads.google.com", name: "Google Ads", category: .productivity, isEnabled: true),
        
        // Herramientas de Desarrollo y Estudio
        BlockedWebsite(domain: "github.com", name: "GitHub", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "notion.so", name: "Notion", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "docs.google.com", name: "Google Docs / Drive", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "drive.google.com", name: "Google Drive", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "mail.google.com", name: "Gmail", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "accounts.google.com", name: "Google Accounts (Login)", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "stackoverflow.com", name: "Stack Overflow", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "chatgpt.com", name: "ChatGPT", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "openai.com", name: "OpenAI", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "claude.ai", name: "Claude AI", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "canvas.net", name: "Canvas LMS", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "figma.com", name: "Figma", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "zoom.us", name: "Zoom", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "trello.com", name: "Trello", category: .productivity, isEnabled: true),
        BlockedWebsite(domain: "linear.app", name: "Linear", category: .productivity, isEnabled: true)
    ]

    // Apps Permitidas Predeterminadas para el Modo Bloqueo Total
    public static let defaultAllowedApps: [BlockedApp] = [
        BlockedApp(bundleIdentifier: "com.apple.dt.Xcode", appName: "Xcode", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.Terminal", appName: "Terminal", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.microsoft.VSCode", appName: "Visual Studio Code", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.todesktop.230313mzl4w4u92", appName: "Cursor", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.Notes", appName: "Notas de Apple", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.Calculator", appName: "Calculadora", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.iCal", appName: "Calendario", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.reminders", appName: "Recordatorios", isEnabled: true),
        BlockedApp(bundleIdentifier: "com.apple.finder", appName: "Finder", isEnabled: true)
    ]

    // Dominios Vitales e Intocables de macOS y Conectividad
    public static let systemEssentialDomains: Set<String> = [
        "apple.com", "icloud.com", "captive.apple.com", "time.apple.com",
        "ocsp.apple.com", "swscan.apple.com", "swcdn.apple.com", "gateway.icloud.com",
        "push.apple.com", "aaplimg.com", "cdn-apple.com", "mzstatic.com",
        "digicert.com", "sectigo.com", "letsencrypt.org", "lencr.org",
        "localhost", "127.0.0.1", "::1"
    ]

    public var blockingMode: FocusBlockingMode
    public var allowedWebsites: [BlockedWebsite]
    public var allowedApps: [BlockedApp]
    public var isUninstallProtectionEnabled: Bool
    public var isBlockDevToolsEnabled: Bool
    public var isAutoDoNotDisturbEnabled: Bool
    public var recoveryMethod: String // "question" o "email"
    public var securityQuestion: String
    public var securityAnswer: String
    public var isFrictionUnlockAllowed: Bool
    public var isPermanentShieldActive: Bool
    
    // MARK: - Nuevas Secciones: Tiempo Desactivado & Límites de Apps
    public var downtimeSchedule: DowntimeSchedule
    public var isAppLimitsEnabled: Bool
    public var appLimits: [AppTimeLimit]

    public init(
        hasCompletedOnboarding: Bool = false,
        recoveryEmail: String = "",
        partnerEmail: String = "",
        isPartnerEmailEnabled: Bool = false,
        isWeeklyReportEnabled: Bool = true,
        lastWeeklyReportDate: Date? = nil,
        isPartnerAlertKeywordsEnabled: Bool = true,
        isPartnerAlertUninstallEnabled: Bool = true,
        isPartnerAlertEmergencyUnlockEnabled: Bool = true,
        isPartnerAlertIncognitoEnabled: Bool = true,
        isPartnerAlertAchievementsEnabled: Bool = true,
        isPartnerAlertSocialLimitEnabled: Bool = true,
        masterCompanionPassword: String = "",
        isMasterPasswordEnabled: Bool = false,
        unlockDelayMinutes: Int = 3,
        reflectionPhrase: String = defaultReflectionPhrase,
        isReflectionRequired: Bool = true,
        isSoundEnabled: Bool = true,
        launchAtLogin: Bool = true,
        appLanguage: AppLanguage = .spanish,
        showMotivationalRedirect: Bool = true,
        isAlwaysBlockAdultSites: Bool = true,
        isForceSafeSearchEnabled: Bool = true,
        isAntiIncognitoEnabled: Bool = true,
        isKeywordBlockerEnabled: Bool = true,
        isWhatsAppStatusBlockerEnabled: Bool = true,
        isWhatsAppChannelsBlockerEnabled: Bool = true,
        blockedKeywords: [String] = defaultBlockedKeywords,
        blockingMode: FocusBlockingMode = .selective,
        permanentBlockedWebsites: [String] = [],
        permanentBlockedApps: [String] = [],
        blockedWebsites: [BlockedWebsite] = defaultWebsites,
        allowedWebsites: [BlockedWebsite] = defaultAllowedWebsites,
        blockedApps: [BlockedApp] = defaultApps,
        allowedApps: [BlockedApp] = defaultAllowedApps,
        smtpSettings: SMTPSettings = SMTPSettings(),
        isUninstallProtectionEnabled: Bool = true,
        isBlockDevToolsEnabled: Bool = false,
        isAutoDoNotDisturbEnabled: Bool = false,
        recoveryMethod: String = "question",
        securityQuestion: String = "¿Cuál fue el nombre de tu primera mascota?",
        securityAnswer: String = "",
        isFrictionUnlockAllowed: Bool = true,
        isPermanentShieldActive: Bool = true,
        downtimeSchedule: DowntimeSchedule = DowntimeSchedule(),
        isAppLimitsEnabled: Bool = false,
        appLimits: [AppTimeLimit] = AppSettings.defaultAppLimits
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.recoveryEmail = recoveryEmail
        self.partnerEmail = partnerEmail
        self.isPartnerEmailEnabled = isPartnerEmailEnabled
        self.isWeeklyReportEnabled = isWeeklyReportEnabled
        self.lastWeeklyReportDate = lastWeeklyReportDate
        self.isPartnerAlertKeywordsEnabled = isPartnerAlertKeywordsEnabled
        self.isPartnerAlertUninstallEnabled = isPartnerAlertUninstallEnabled
        self.isPartnerAlertEmergencyUnlockEnabled = isPartnerAlertEmergencyUnlockEnabled
        self.isPartnerAlertIncognitoEnabled = isPartnerAlertIncognitoEnabled
        self.isPartnerAlertAchievementsEnabled = isPartnerAlertAchievementsEnabled
        self.isPartnerAlertSocialLimitEnabled = isPartnerAlertSocialLimitEnabled
        self.masterCompanionPassword = masterCompanionPassword
        self.isMasterPasswordEnabled = isMasterPasswordEnabled
        self.unlockDelayMinutes = unlockDelayMinutes
        self.reflectionPhrase = reflectionPhrase
        self.isReflectionRequired = isReflectionRequired
        self.isSoundEnabled = isSoundEnabled
        self.launchAtLogin = launchAtLogin
        self.appLanguage = appLanguage
        self.showMotivationalRedirect = showMotivationalRedirect
        self.isAlwaysBlockAdultSites = isAlwaysBlockAdultSites
        self.isForceSafeSearchEnabled = isForceSafeSearchEnabled
        self.isAntiIncognitoEnabled = isAntiIncognitoEnabled
        self.isKeywordBlockerEnabled = isKeywordBlockerEnabled
        self.isWhatsAppStatusBlockerEnabled = isWhatsAppStatusBlockerEnabled
        self.isWhatsAppChannelsBlockerEnabled = isWhatsAppChannelsBlockerEnabled
        self.blockedKeywords = blockedKeywords
        self.blockingMode = blockingMode
        self.permanentBlockedWebsites = permanentBlockedWebsites
        self.permanentBlockedApps = permanentBlockedApps
        self.blockedWebsites = blockedWebsites
        self.allowedWebsites = allowedWebsites
        self.blockedApps = blockedApps
        self.allowedApps = allowedApps
        self.smtpSettings = smtpSettings
        self.isUninstallProtectionEnabled = isUninstallProtectionEnabled
        self.isBlockDevToolsEnabled = isBlockDevToolsEnabled
        self.isAutoDoNotDisturbEnabled = isAutoDoNotDisturbEnabled
        self.recoveryMethod = recoveryMethod
        self.securityQuestion = securityQuestion
        self.securityAnswer = securityAnswer
        self.isFrictionUnlockAllowed = isFrictionUnlockAllowed
        self.isPermanentShieldActive = isPermanentShieldActive
        self.downtimeSchedule = downtimeSchedule
        self.isAppLimitsEnabled = isAppLimitsEnabled
        self.appLimits = appLimits
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        self.recoveryEmail = try container.decodeIfPresent(String.self, forKey: .recoveryEmail) ?? ""
        self.partnerEmail = try container.decodeIfPresent(String.self, forKey: .partnerEmail) ?? ""
        self.isPartnerEmailEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerEmailEnabled) ?? false
        self.isWeeklyReportEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWeeklyReportEnabled) ?? true
        self.lastWeeklyReportDate = try container.decodeIfPresent(Date.self, forKey: .lastWeeklyReportDate)
        self.isPartnerAlertKeywordsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertKeywordsEnabled) ?? true
        self.isPartnerAlertUninstallEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertUninstallEnabled) ?? true
        self.isPartnerAlertEmergencyUnlockEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertEmergencyUnlockEnabled) ?? true
        self.isPartnerAlertIncognitoEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertIncognitoEnabled) ?? true
        self.isPartnerAlertAchievementsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertAchievementsEnabled) ?? true
        self.isPartnerAlertSocialLimitEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPartnerAlertSocialLimitEnabled) ?? true
        self.masterCompanionPassword = try container.decodeIfPresent(String.self, forKey: .masterCompanionPassword) ?? ""
        self.isMasterPasswordEnabled = try container.decodeIfPresent(Bool.self, forKey: .isMasterPasswordEnabled) ?? false
        self.unlockDelayMinutes = try container.decodeIfPresent(Int.self, forKey: .unlockDelayMinutes) ?? 3
        self.reflectionPhrase = try container.decodeIfPresent(String.self, forKey: .reflectionPhrase) ?? AppSettings.defaultReflectionPhrase
        self.isReflectionRequired = try container.decodeIfPresent(Bool.self, forKey: .isReflectionRequired) ?? true
        self.isSoundEnabled = try container.decodeIfPresent(Bool.self, forKey: .isSoundEnabled) ?? true
        self.launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        self.appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .spanish
        self.showMotivationalRedirect = try container.decodeIfPresent(Bool.self, forKey: .showMotivationalRedirect) ?? true
        self.isAlwaysBlockAdultSites = try container.decodeIfPresent(Bool.self, forKey: .isAlwaysBlockAdultSites) ?? true
        self.isForceSafeSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .isForceSafeSearchEnabled) ?? true
        self.isAntiIncognitoEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAntiIncognitoEnabled) ?? true
        self.isKeywordBlockerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isKeywordBlockerEnabled) ?? true
        self.isWhatsAppStatusBlockerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWhatsAppStatusBlockerEnabled) ?? true
        self.isWhatsAppChannelsBlockerEnabled = try container.decodeIfPresent(Bool.self, forKey: .isWhatsAppChannelsBlockerEnabled) ?? true
        self.blockedKeywords = try container.decodeIfPresent([String].self, forKey: .blockedKeywords) ?? AppSettings.defaultBlockedKeywords
        self.blockingMode = try container.decodeIfPresent(FocusBlockingMode.self, forKey: .blockingMode) ?? .selective
        self.permanentBlockedWebsites = try container.decodeIfPresent([String].self, forKey: .permanentBlockedWebsites) ?? []
        self.permanentBlockedApps = try container.decodeIfPresent([String].self, forKey: .permanentBlockedApps) ?? []
        self.blockedWebsites = try container.decodeIfPresent([BlockedWebsite].self, forKey: .blockedWebsites) ?? AppSettings.defaultWebsites
        self.allowedWebsites = try container.decodeIfPresent([BlockedWebsite].self, forKey: .allowedWebsites) ?? AppSettings.defaultAllowedWebsites
        self.blockedApps = try container.decodeIfPresent([BlockedApp].self, forKey: .blockedApps) ?? AppSettings.defaultApps
        self.allowedApps = try container.decodeIfPresent([BlockedApp].self, forKey: .allowedApps) ?? AppSettings.defaultAllowedApps
        self.smtpSettings = try container.decodeIfPresent(SMTPSettings.self, forKey: .smtpSettings) ?? SMTPSettings()
        self.isUninstallProtectionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isUninstallProtectionEnabled) ?? true
        self.isBlockDevToolsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isBlockDevToolsEnabled) ?? false
        self.isAutoDoNotDisturbEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoDoNotDisturbEnabled) ?? false
        self.recoveryMethod = try container.decodeIfPresent(String.self, forKey: .recoveryMethod) ?? "question"
        self.securityQuestion = try container.decodeIfPresent(String.self, forKey: .securityQuestion) ?? "¿Cuál fue el nombre de tu primera mascota?"
        self.securityAnswer = try container.decodeIfPresent(String.self, forKey: .securityAnswer) ?? ""
        self.isFrictionUnlockAllowed = try container.decodeIfPresent(Bool.self, forKey: .isFrictionUnlockAllowed) ?? true
        self.isPermanentShieldActive = try container.decodeIfPresent(Bool.self, forKey: .isPermanentShieldActive) ?? true
        self.downtimeSchedule = try container.decodeIfPresent(DowntimeSchedule.self, forKey: .downtimeSchedule) ?? DowntimeSchedule()
        self.isAppLimitsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAppLimitsEnabled) ?? false
        self.appLimits = try container.decodeIfPresent([AppTimeLimit].self, forKey: .appLimits) ?? AppSettings.defaultAppLimits
    }
    
    public static let defaultAppLimits: [AppTimeLimit] = [
        AppTimeLimit(targetType: "website", identifier: "facebook.com", name: "Facebook y m.facebook.com", limitMinutes: 15, isEnabled: false),
        AppTimeLimit(targetType: "website", identifier: "instagram.com", name: "instagram.com", limitMinutes: 15, isEnabled: false),
        AppTimeLimit(targetType: "website", identifier: "youtube.com", name: "youtube.com y m.youtube.com", limitMinutes: 30, isEnabled: false),
        AppTimeLimit(targetType: "website", identifier: "netflix.com", name: "netflix.com", limitMinutes: 45, isEnabled: false)
    ]
}

public struct DowntimeSchedule: Codable, Equatable {
    public var isEnabled: Bool
    public var startHour: Int // 0..23 (default: 22 / 10:00 PM)
    public var startMinute: Int // 0..59 (default: 0)
    public var endHour: Int // 0..23 (default: 7 / 07:00 AM)
    public var endMinute: Int // 0..59 (default: 0)
    public var scheduleType: Int // 0: Cada día, 1: Lunes a Viernes, 2: Fin de semana, 3: Personalizado
    public var activeDays: [Int] // 1=Dom, 2=Lun, 3=Mar, 4=Mie, 5=Jue, 6=Vie, 7=Sab
    public var blockDuringDowntime: Bool
    
    public init(
        isEnabled: Bool = false,
        startHour: Int = 22,
        startMinute: Int = 0,
        endHour: Int = 7,
        endMinute: Int = 0,
        scheduleType: Int = 0,
        activeDays: [Int] = [1, 2, 3, 4, 5, 6, 7],
        blockDuringDowntime: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.scheduleType = scheduleType
        self.activeDays = activeDays
        self.blockDuringDowntime = blockDuringDowntime
    }
}

public struct AppTimeLimit: Codable, Equatable, Identifiable {
    public var id: UUID
    public var targetType: String // "app" o "website"
    public var identifier: String // bundleIdentifier or domain
    public var name: String
    public var limitMinutes: Int // e.g. 15, 30, 60, 150
    public var isEnabled: Bool
    public var days: [Int] // 1..7
    
    public init(
        id: UUID = UUID(),
        targetType: String = "app",
        identifier: String,
        name: String,
        limitMinutes: Int = 15,
        isEnabled: Bool = true,
        days: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) {
        self.id = id
        self.targetType = targetType
        self.identifier = identifier
        self.name = name
        self.limitMinutes = limitMinutes
        self.isEnabled = isEnabled
        self.days = days
    }
}
