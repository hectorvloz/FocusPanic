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
    public var masterCompanionPassword: String
    public var isMasterPasswordEnabled: Bool
    public var unlockDelayMinutes: Int
    public var reflectionPhrase: String
    public var isReflectionRequired: Bool
    public var isSoundEnabled: Bool
    public var launchAtLogin: Bool
    public var showMotivationalRedirect: Bool
    public var isAlwaysBlockAdultSites: Bool // Switch del Escudo Anti-Porn (+180 sitios)
    public var isForceSafeSearchEnabled: Bool // Forzar SafeSearch estricto en Google, Bing, DuckDuckGo
    public var permanentBlockedWebsites: [String] // Sitios bloqueados 24/7 permanentemente
    public var permanentBlockedApps: [String] // Apps bloqueadas 24/7 permanentemente
    public var blockedWebsites: [BlockedWebsite]
    public var blockedApps: [BlockedApp]
    public var smtpSettings: SMTPSettings
    public var lastEmergencyCode: String?
    public var lastEmergencyCodeExpiry: Date?

    public static let defaultReflectionPhrase = "Reconozco que este es un impulso de distracción y elijo respirar con calma antes de actuar."

    public static let defaultWebsites: [BlockedWebsite] = [
        // Redes Sociales
        BlockedWebsite(domain: "x.com", name: "X (Twitter)", category: .social),
        BlockedWebsite(domain: "twitter.com", name: "Twitter", category: .social),
        BlockedWebsite(domain: "instagram.com", name: "Instagram", category: .social),
        BlockedWebsite(domain: "facebook.com", name: "Facebook", category: .social),
        BlockedWebsite(domain: "tiktok.com", name: "TikTok", category: .social),
        BlockedWebsite(domain: "threads.net", name: "Threads", category: .social),
        BlockedWebsite(domain: "linkedin.com", name: "LinkedIn", category: .social),
        
        // Video y Streaming
        BlockedWebsite(domain: "youtube.com", name: "YouTube", category: .video),
        BlockedWebsite(domain: "netflix.com", name: "Netflix", category: .video),
        BlockedWebsite(domain: "twitch.tv", name: "Twitch", category: .video),
        BlockedWebsite(domain: "disneyplus.com", name: "Disney+", category: .video),
        BlockedWebsite(domain: "primevideo.com", name: "Prime Video", category: .video),
        
        // Noticias y Foros
        BlockedWebsite(domain: "reddit.com", name: "Reddit", category: .news),
        BlockedWebsite(domain: "news.ycombinator.com", name: "Hacker News", category: .news),
        BlockedWebsite(domain: "elmundo.es", name: "El Mundo", category: .news),
        BlockedWebsite(domain: "elpais.com", name: "El País", category: .news),
        BlockedWebsite(domain: "cnn.com", name: "CNN", category: .news),
        BlockedWebsite(domain: "bbc.com", name: "BBC", category: .news),
        
        // Zona de Juegos
        BlockedWebsite(domain: "roblox.com", name: "Roblox", category: .gaming),
        BlockedWebsite(domain: "chess.com", name: "Chess.com", category: .gaming),
        BlockedWebsite(domain: "steampowered.com", name: "Steam Store", category: .gaming),
        BlockedWebsite(domain: "epicgames.com", name: "Epic Games", category: .gaming),
        BlockedWebsite(domain: "poki.com", name: "Poki Games", category: .gaming),
        BlockedWebsite(domain: "friv.com", name: "Friv", category: .gaming),
        BlockedWebsite(domain: "ea.com", name: "EA Games", category: .gaming),
        BlockedWebsite(domain: "battle.net", name: "Battle.net", category: .gaming),
        BlockedWebsite(domain: "riotgames.com", name: "Riot Games", category: .gaming),
        
        // Compras
        BlockedWebsite(domain: "amazon.com", name: "Amazon", category: .shopping),
        BlockedWebsite(domain: "mercadolibre.com", name: "Mercado Libre", category: .shopping),
        BlockedWebsite(domain: "aliexpress.com", name: "AliExpress", category: .shopping),
        BlockedWebsite(domain: "ebay.com", name: "eBay", category: .shopping)
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

    public init(
        hasCompletedOnboarding: Bool = false,
        recoveryEmail: String = "",
        partnerEmail: String = "",
        isPartnerEmailEnabled: Bool = false,
        masterCompanionPassword: String = "1234",
        isMasterPasswordEnabled: Bool = true,
        unlockDelayMinutes: Int = 3,
        reflectionPhrase: String = defaultReflectionPhrase,
        isReflectionRequired: Bool = true,
        isSoundEnabled: Bool = true,
        launchAtLogin: Bool = true,
        showMotivationalRedirect: Bool = true,
        isAlwaysBlockAdultSites: Bool = true,
        isForceSafeSearchEnabled: Bool = true,
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
        isPermanentShieldActive: Bool = true
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.recoveryEmail = recoveryEmail
        self.partnerEmail = partnerEmail
        self.isPartnerEmailEnabled = isPartnerEmailEnabled
        self.masterCompanionPassword = masterCompanionPassword
        self.isMasterPasswordEnabled = isMasterPasswordEnabled
        self.unlockDelayMinutes = unlockDelayMinutes
        self.reflectionPhrase = reflectionPhrase
        self.isReflectionRequired = isReflectionRequired
        self.isSoundEnabled = isSoundEnabled
        self.launchAtLogin = launchAtLogin
        self.showMotivationalRedirect = showMotivationalRedirect
        self.isAlwaysBlockAdultSites = isAlwaysBlockAdultSites
        self.isForceSafeSearchEnabled = isForceSafeSearchEnabled
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
    }
}
