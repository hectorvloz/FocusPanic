import Foundation
import SwiftUI
import Combine

public enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case spanish = "es"
    case english = "en"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    public var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .english: return "🇺🇸"
        }
    }
}

public final class LocalizationService: ObservableObject {
    public static let shared = LocalizationService()
    
    @Published public var currentLanguage: AppLanguage = .spanish
    
    private init() {
        if let savedLang = UserDefaults.standard.string(forKey: "FocusPanic_AppLanguage"),
           let lang = AppLanguage(rawValue: savedLang) {
            self.currentLanguage = lang
        }
    }
    
    public func setLanguage(_ language: AppLanguage) {
        self.currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "FocusPanic_AppLanguage")
    }
    
    public func tr(_ key: String) -> String {
        if let dict = LocalizationData.strings[key] {
            return dict[currentLanguage] ?? dict[.spanish] ?? key
        }
        return key
    }
    
    public func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = tr(key)
        return String(format: format, arguments: args)
    }
}

public struct L10n {
    public static func tr(_ key: String) -> String {
        return LocalizationService.shared.tr(key)
    }
    
    public static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = LocalizationService.shared.tr(key)
        return String(format: format, arguments: args)
    }
}

// MARK: - Catálogo Completo de Traducciones
public struct LocalizationData {
    public static let strings: [String: [AppLanguage: String]] = [
        // MARK: - Elementos Comunes
        "common.active": [
            .spanish: "ACTIVO",
            .english: "ACTIVE"
        ],
        "common.inactive": [
            .spanish: "INACTIVO",
            .english: "INACTIVE"
        ],
        "common.verified": [
            .spanish: "Verificado ✓",
            .english: "Verified ✓"
        ],
        "common.all": [
            .spanish: "Todas",
            .english: "All"
        ],
        "common.hide": [
            .spanish: "Ocultar",
            .english: "Hide"
        ],
        "common.disableAll": [
            .spanish: "Desactivar Todos",
            .english: "Disable All"
        ],
        "common.enableAll": [
            .spanish: "Activar Todos",
            .english: "Enable All"
        ],
        "common.cancel": [
            .spanish: "Cancelar",
            .english: "Cancel"
        ],
        "common.save": [
            .spanish: "Guardar",
            .english: "Save"
        ],
        "common.add": [
            .spanish: "Añadir",
            .english: "Add"
        ],
        "common.delete": [
            .spanish: "Eliminar",
            .english: "Delete"
        ],
        "common.edit": [
            .spanish: "Editar",
            .english: "Edit"
        ],
        "common.reset": [
            .spanish: "Restablecer",
            .english: "Reset"
        ],
        
        // MARK: - Menú Lateral y Pestañas de Ajustes
        "settings.title": [
            .spanish: "Configuración",
            .english: "Settings"
        ],
        "settings.lock": [
            .spanish: "Bloquear",
            .english: "Lock"
        ],
        "settings.group.blocking": [
            .spanish: "REGLAS DE BLOQUEO",
            .english: "BLOCKING RULES"
        ],
        "settings.group.screenTime": [
            .spanish: "HORARIOS & TIEMPO",
            .english: "SCHEDULES & TIME"
        ],
        "settings.group.system": [
            .spanish: "SEGURIDAD & AJUSTES",
            .english: "SECURITY & SETTINGS"
        ],
        "section.websites": [
            .spanish: "Sitios Web",
            .english: "Websites"
        ],
        "section.apps": [
            .spanish: "Aplicaciones Mac",
            .english: "Mac Applications"
        ],
        "section.permanent": [
            .spanish: "Escudo Permanente",
            .english: "Permanent Shield"
        ],
        "section.downtime": [
            .spanish: "Tiempo Desactivado",
            .english: "Downtime Schedule"
        ],
        "section.appLimits": [
            .spanish: "Límites para apps",
            .english: "App Limits"
        ],
        "section.whitelist": [
            .spanish: "Lista Blanca (Permitidos)",
            .english: "Whitelist (Allowed)"
        ],
        "section.emergency": [
            .spanish: "Desbloqueo",
            .english: "Unlock & Recovery"
        ],
        "section.general": [
            .spanish: "General",
            .english: "General"
        ],

        // MARK: - Categorías de Sitios y Apps
        "cat.productivity": [
            .spanish: "Productividad & Estudio",
            .english: "Productivity & Study"
        ],
        "cat.social": [
            .spanish: "Redes Sociales",
            .english: "Social Media"
        ],
        "cat.video": [
            .spanish: "Streaming y Video",
            .english: "Streaming & Video"
        ],
        "cat.news": [
            .spanish: "Noticias y Foros",
            .english: "News & Forums"
        ],
        "cat.gaming": [
            .spanish: "Zona de Juegos",
            .english: "Gaming"
        ],
        "cat.shopping": [
            .spanish: "Compras",
            .english: "Shopping"
        ],
        "cat.custom": [
            .spanish: "Personalizados",
            .english: "Custom"
        ],

        // MARK: - Diagnóstico de Permisos de macOS
        "general.header.title": [
            .spanish: "Configuración General & Diagnóstico",
            .english: "General Settings & Diagnostics"
        ],
        "general.header.subtitle": [
            .spanish: "Supervisa y valida los permisos de macOS para asegurar el bloqueo al 100%.",
            .english: "Monitor and validate macOS permissions to ensure 100% blocking reliability."
        ],
        "general.diag.title": [
            .spanish: "Diagnóstico de Permisos de macOS",
            .english: "macOS Permissions Diagnostics"
        ],
        "general.diag.dns.title": [
            .spanish: "DNS Seguro Cloudflare Families (1.1.1.3)",
            .english: "Cloudflare Families Secure DNS (1.1.1.3)"
        ],
        "general.diag.dns.active": [
            .spanish: "Activo (1.1.1.3 / 1.0.0.3). Bloquea millones de sitios para adultos y malware 24/7.",
            .english: "Active (1.1.1.3 / 1.0.0.3). Blocks millions of adult and malware sites 24/7."
        ],
        "general.diag.dns.inactive": [
            .spanish: "Desconectado. Haz clic para activar el escudo de red global.",
            .english: "Disconnected. Click to enable the global network shield."
        ],
        "general.diag.connectDns": [
            .spanish: "Conectar DNS 🛡️",
            .english: "Connect DNS 🛡️"
        ],
        "general.diag.ax.title": [
            .spanish: "Accesibilidad de macOS (WhatsApp & Incógnito)",
            .english: "macOS Accessibility (WhatsApp & Incognito)"
        ],
        "general.diag.ax.active": [
            .spanish: "Permite interceptar historias de WhatsApp y cerrar ventanas de incógnito.",
            .english: "Allows intercepting WhatsApp stories and closing private windows."
        ],
        "general.diag.ax.inactive": [
            .spanish: "Inactivo. Haz clic para abrir Ajustes y conceder permiso.",
            .english: "Inactive. Click to open System Settings and grant permission."
        ],
        "general.diag.openSettings": [
            .spanish: "Abrir Ajustes",
            .english: "Open Settings"
        ],
        "general.diag.hosts.title": [
            .spanish: "Motor de Red (/etc/hosts)",
            .english: "Network Engine (/etc/hosts)"
        ],
        "general.diag.hosts.active": [
            .spanish: "Instalado con permisos de sistema (sin pedir contraseña).",
            .english: "Installed with system permissions (no password prompt)."
        ],
        "general.diag.hosts.inactive": [
            .spanish: "No instalado. Requiere ejecución inicial.",
            .english: "Not installed. Requires initial setup."
        ],
        "general.diag.verifyReinstall": [
            .spanish: "Verificar / Reinstalar",
            .english: "Verify / Reinstall"
        ],
        "general.diag.safari.title": [
            .spanish: "Automatización de Safari (AppleScript)",
            .english: "Safari Automation (AppleScript)"
        ],
        "general.diag.safari.desc": [
            .spanish: "Permite interceptar y cerrar pestañas distractoras al instante.",
            .english: "Allows intercepting and closing distracting tabs instantly."
        ],
        "general.diag.testPermission": [
            .spanish: "Probar Permiso",
            .english: "Test Permission"
        ],
        "general.diag.notif.title": [
            .spanish: "Notificaciones de macOS",
            .english: "macOS Notifications"
        ],
        "general.diag.notif.desc": [
            .spanish: "Envía avisos de inicio y fin de sesiones.",
            .english: "Sends alerts for session start, end, and intercepts."
        ],
        "general.diag.notif.sent": [
            .spanish: "¡Notificación de prueba enviada con éxito!",
            .english: "Test notification sent successfully!"
        ],
        "general.diag.sendTest": [
            .spanish: "Enviar Prueba",
            .english: "Send Test"
        ],
        "general.diag.apps.title": [
            .spanish: "Monitoreo de Aplicaciones (NSRunningApplication)",
            .english: "Application Monitoring (NSRunningApplication)"
        ],
        "general.diag.apps.desc": [
            .spanish: "Detecta y cierra las aplicaciones distractoras seleccionadas.",
            .english: "Detects and terminates selected distracting apps."
        ],
        "general.diag.verify": [
            .spanish: "Verificar",
            .english: "Verify"
        ],

        // MARK: - Idioma & Preferencias
        "general.lang.title": [
            .spanish: "Idioma de la Aplicación",
            .english: "App Language"
        ],
        "general.lang.desc": [
            .spanish: "Selecciona el idioma de visualización de FocusPanic.",
            .english: "Select the display language for FocusPanic."
        ],
        "general.preferences.title": [
            .spanish: "Preferencias de Uso & Enfoque",
            .english: "Usage & Focus Preferences"
        ],
        "general.pref.sounds": [
            .spanish: "Sonidos del Sistema",
            .english: "System Sounds"
        ],
        "general.pref.launchAtLogin": [
            .spanish: "Iniciar FocusPanic al encender el Mac",
            .english: "Launch FocusPanic at Mac startup"
        ],
        "general.pref.blockDevTools": [
            .spanish: "Bloquear Terminal y Monitor de Actividad durante Enfoque",
            .english: "Block Terminal and Activity Monitor during Focus"
        ],
        "general.pref.autoDND": [
            .spanish: "Activar Modo 'No Molestar' de macOS automáticamente",
            .english: "Enable macOS 'Do Not Disturb' automatically"
        ],

        // MARK: - Backup & Transferencia
        "backup.title": [
            .spanish: "Copia de Seguridad & Transferencia",
            .english: "Backup & Transfer"
        ],
        "backup.desc": [
            .spanish: "Exporta o restaura toda tu configuración (sitios web bloqueados, escudo permanente, palabras clave prohibidas, límites de aplicaciones, horarios y preferencias) en un archivo JSON seguro para respaldo o para transferir a otra Mac.",
            .english: "Export or restore your full custom configuration (blocked websites, permanent shield, forbidden keywords, app limits, schedules, and preferences) in a secure JSON file for backup or Mac migration."
        ],
        "backup.btn.export": [
            .spanish: "Exportar Ajustes (.json)",
            .english: "Export Settings (.json)"
        ],
        "backup.btn.import": [
            .spanish: "Importar Ajustes (.json)...",
            .english: "Import Settings (.json)..."
        ],

        // MARK: - Anti-Desinstalación
        "uninstall.title": [
            .spanish: "Protección Anti-Desinstalación",
            .english: "Anti-Uninstall Protection"
        ],
        "uninstall.desc": [
            .spanish: "Bloquea el archivo de FocusPanic en macOS (bandera inmutable del sistema) para evitar que sea arrastrado a la Papelera o eliminado sin la clave de tu compañero.",
            .english: "Locks the FocusPanic application file in macOS (system immutable flag) to prevent it from being moved to Trash or deleted without your partner's PIN."
        ],
        "uninstall.btn": [
            .spanish: "Desinstalar FocusPanic...",
            .english: "Uninstall FocusPanic..."
        ],

        // MARK: - Bloqueo de Sitios Web
        "webblock.title": [
            .spanish: "Bloqueo de Sitios Web",
            .english: "Website Blocking"
        ],
        "webblock.subtitle.withAdult": [
            .spanish: "%d sitios activos + Escudo Anti-Porn (+1,000 sitios)",
            .english: "%d active sites + Anti-Porn Shield (1,000+ sites)"
        ],
        "webblock.subtitle.normal": [
            .spanish: "%d sitios activos",
            .english: "%d active sites"
        ],
        "webblock.btn.add": [
            .spanish: "Añadir Sitios",
            .english: "Add Sites"
        ],
        "webblock.search.placeholder": [
            .spanish: "Buscar sitio...",
            .english: "Search website..."
        ],
        "webblock.category": [
            .spanish: "Categoría",
            .english: "Category"
        ],
        "webblock.reset.defaults": [
            .spanish: "Restablecer Sitios Predeterminados",
            .english: "Reset Default Websites"
        ],
        "webblock.add.single": [
            .spanish: "Individual",
            .english: "Single Domain"
        ],
        "webblock.add.batch": [
            .spanish: "Varios Sitios",
            .english: "Batch Import"
        ],
        "webblock.add.single.placeholder": [
            .spanish: "Escribe dominio a bloquear (ej. casino.com, apuestas.com)...",
            .english: "Enter domain to block (e.g. casino.com, gambling.com)..."
        ],
        "webblock.add.btn.block": [
            .spanish: "Bloquear",
            .english: "Block"
        ],
        "webblock.add.batch.hint": [
            .spanish: "Pega varios dominios (uno por línea o separados por comas):",
            .english: "Paste multiple domains (one per line or comma-separated):"
        ],
        "webblock.add.batch.btn": [
            .spanish: "Añadir Todos los Dominios",
            .english: "Add All Domains"
        ],

        // MARK: - Bloqueo de Aplicaciones Mac
        "appblock.title": [
            .spanish: "Bloqueo de Aplicaciones Mac",
            .english: "Mac Application Blocking"
        ],
        "appblock.subtitle": [
            .spanish: "%d aplicaciones configuradas para bloqueo",
            .english: "%d applications configured for blocking"
        ],
        "appblock.btn.add": [
            .spanish: "Añadir App...",
            .english: "Add App..."
        ],
        "appblock.search.placeholder": [
            .spanish: "Buscar aplicación...",
            .english: "Search application..."
        ],
        "appblock.reset.defaults": [
            .spanish: "Restablecer Aplicaciones Predeterminadas",
            .english: "Reset Default Applications"
        ],

        // MARK: - Escudo Permanente 24/7
        "permanent.header.title": [
            .spanish: "Escudo Permanente 24/7",
            .english: "24/7 Permanent Shield"
        ],
        "permanent.header.subtitle": [
            .spanish: "Protección continua en segundo plano sin importar si hay una sesión activa.",
            .english: "Continuous background protection regardless of active focus sessions."
        ],
        "permanent.adult.title": [
            .spanish: "Escudo Anti-Contenido Adulto (+18)",
            .english: "Anti-Adult Content Shield (+18)"
        ],
        "permanent.adult.desc": [
            .spanish: "Bloquea más de 1,000 sitios web para adultos, inspección estricta de TeraBox (páginas, buscadores y URLs) y bloqueo del navegador DuckDuckGo.",
            .english: "Blocks 1,000+ adult websites, strict TeraBox inspection (pages, search engines and URLs) and blocks DuckDuckGo browser."
        ],
        "permanent.safesearch.title": [
            .spanish: "Forzar SafeSearch Estricto",
            .english: "Enforce Strict SafeSearch"
        ],
        "permanent.safesearch.desc": [
            .spanish: "Filtra contenido explícito en Google, Bing y Yahoo, y bloquea DuckDuckGo y más de 120 buscadores alternativos.",
            .english: "Filters explicit results on Google, Bing and Yahoo, and blocks DuckDuckGo and 120+ alternative search engines."
        ],
        "permanent.incognito.title": [
            .spanish: "Bloqueador de Modo Incógnito / Ventana Privada",
            .english: "Block Incognito / Private Browsing"
        ],
        "permanent.incognito.desc": [
            .spanish: "Cierra automáticamente ventanas privadas en Safari, Chrome, Brave, Arc y Edge.",
            .english: "Automatically closes private/incognito windows in Safari, Chrome, Brave, Arc, and Edge."
        ],
        "permanent.keywords.title": [
            .spanish: "Filtro de Palabras y Búsquedas Prohibidas",
            .english: "Forbidden Search & Keyword Filter"
        ],
        "permanent.keywords.desc": [
            .spanish: "Intercepta búsquedas con términos prohibidos en buscadores y aplicaciones.",
            .english: "Intercepts searches with forbidden terms across browsers and apps."
        ],
        "permanent.whatsapp.status.title": [
            .spanish: "Bloquear Estados e Historias de WhatsApp",
            .english: "Block WhatsApp Stories & Status"
        ],
        "permanent.whatsapp.channels.title": [
            .spanish: "Bloquear Canales de WhatsApp",
            .english: "Block WhatsApp Channels"
        ],
        "permanent.custom.title": [
            .spanish: "Dominios y Apps Bloqueados 24/7",
            .english: "24/7 Blocked Domains & Apps"
        ],

        // MARK: - Horarios & Tiempo (Downtime & Límites)
        "downtime.title": [
            .spanish: "Tiempo Desactivado",
            .english: "Downtime Schedule"
        ],
        "downtime.desc": [
            .spanish: "Programa un horario diario donde las distracciones queden bloqueadas automáticamente.",
            .english: "Schedule a recurring window where distracting apps and sites are locked automatically."
        ],
        "downtime.enable": [
            .spanish: "Activar Horario de Tiempo Desactivado",
            .english: "Enable Downtime Schedule"
        ],
        "downtime.start": [
            .spanish: "Hora de Inicio",
            .english: "Start Time"
        ],
        "downtime.end": [
            .spanish: "Hora de Fin",
            .english: "End Time"
        ],
        "downtime.schedule.everyday": [
            .spanish: "Todos los Días",
            .english: "Every Day"
        ],
        "downtime.schedule.weekdays": [
            .spanish: "Lunes a Viernes",
            .english: "Monday to Friday"
        ],
        "downtime.schedule.weekends": [
            .spanish: "Fin de Semana",
            .english: "Weekends"
        ],
        "downtime.schedule.custom": [
            .spanish: "Personalizado",
            .english: "Custom"
        ],

        "limits.title": [
            .spanish: "Límites para Apps y Sitios",
            .english: "App & Website Limits"
        ],
        "limits.desc": [
            .spanish: "Establece un límite de tiempo diario tras el cual se bloqueará el acceso hasta mañana.",
            .english: "Set daily time limits after which access is blocked until tomorrow."
        ],
        "limits.enable": [
            .spanish: "Activar Límites Diarios de Tiempo",
            .english: "Enable Daily Time Limits"
        ],

        // MARK: - Lista Blanca
        "whitelist.title": [
            .spanish: "Lista Blanca (Permitidos)",
            .english: "Whitelist (Allowed)"
        ],
        "whitelist.desc": [
            .spanish: "Sitios web y aplicaciones autorizados durante el Modo Bloqueo Total.",
            .english: "Websites and applications authorized during Total Lockdown Mode."
        ],

        // MARK: - Desbloqueo & Compañero
        "emergency.title": [
            .spanish: "Desbloqueo & Compañero de Responsabilidad",
            .english: "Unlock & Accountability Partner"
        ],
        "emergency.desc": [
            .spanish: "Configura la protección anti-cancelación impulsiva y los datos de tu compañero.",
            .english: "Configure anti-impulsive safeguards and your accountability partner settings."
        ],
        "emergency.partner.email": [
            .spanish: "Correo del Compañero:",
            .english: "Partner Email:"
        ],
        "emergency.partner.pin": [
            .spanish: "Clave Maestra del Compañero (PIN):",
            .english: "Partner Master PIN:"
        ],
        "emergency.delay.title": [
            .spanish: "Tiempo de Fricción de Desbloqueo:",
            .english: "Unlock Friction Delay:"
        ],

        // MARK: - Dashboard Principal
        "dash.title": [
            .spanish: "Panel de Enfoque",
            .english: "Focus Dashboard"
        ],
        "dash.session.active": [
            .spanish: "Sesión de Enfoque Activa",
            .english: "Active Focus Session"
        ],
        "dash.session.paused": [
            .spanish: "Sesión Pausada",
            .english: "Session Paused"
        ],
        "dash.session.idle": [
            .spanish: "Elige tu Modo de Enfoque",
            .english: "Choose Your Focus Mode"
        ],
        "dash.btn.start": [
            .spanish: "Iniciar Sesión",
            .english: "Start Session"
        ],
        "dash.btn.stop": [
            .spanish: "Detener Enfoque",
            .english: "Stop Focus"
        ],
        "dash.btn.pause": [
            .spanish: "Pausar",
            .english: "Pause"
        ],
        "dash.btn.resume": [
            .spanish: "Reanudar",
            .english: "Resume"
        ],
        "dash.stats.streak": [
            .spanish: "Racha",
            .english: "Streak"
        ],
        "dash.stats.level": [
            .spanish: "Nivel",
            .english: "Level"
        ],
        "dash.stats.xp": [
            .spanish: "XP",
            .english: "XP"
        ],
        "dash.stats.days": [
            .spanish: "días",
            .english: "days"
        ],
        "dash.stats.intercepted": [
            .spanish: "Impulsos Evitados",
            .english: "Impulses Avoided"
        ],
        "dash.stats.focustime": [
            .spanish: "Tiempo Enfocado",
            .english: "Focus Time"
        ],
        "dash.radar.title": [
            .spanish: "Radar de Impulsos Evitados",
            .english: "Avoided Impulses Radar"
        ],
        "dash.radar.subtitle": [
            .spanish: "Top Distractores Interceptados",
            .english: "Top Intercepted Distractors"
        ],
        "dash.live.history": [
            .spanish: "Registro en Vivo de Intercepciones",
            .english: "Live Interception Log"
        ],

        // MARK: - Presets
        "preset.microsprint": [
            .spanish: "Micro-Sprint",
            .english: "Micro-Sprint"
        ],
        "preset.microsprint.sub": [
            .spanish: "Superar la inercia inicial",
            .english: "Overcome initial inertia"
        ],
        "preset.pomodoro": [
            .spanish: "Pomodoro TDAH",
            .english: "ADHD Pomodoro"
        ],
        "preset.pomodoro.sub": [
            .spanish: "Sprint de concentración óptimo",
            .english: "Optimal concentration sprint"
        ],
        "preset.deepfocus": [
            .spanish: "Enfoque Profundo",
            .english: "Deep Focus"
        ],
        "preset.deepfocus.sub": [
            .spanish: "Para tareas complejas",
            .english: "For complex deep work"
        ],
        "preset.hyperfocus": [
            .spanish: "Modo Hiperfoco",
            .english: "Hyperfocus Mode"
        ],
        "preset.hyperfocus.sub": [
            .spanish: "Inmersión total sin ruidos",
            .english: "Total immersion without noise"
        ],
        "preset.totalLockdown": [
            .spanish: "Bloqueo Total",
            .english: "Total Lockdown"
        ],
        "preset.totalLockdown.sub": [
            .spanish: "Aislamiento radical de emergencia",
            .english: "Radical emergency isolation"
        ],

        // MARK: - Popover de la Barra de Menús
        "popover.dashboard": [
            .spanish: "Dashboard",
            .english: "Dashboard"
        ],
        "popover.emergency": [
            .spanish: "Desbloqueo de Emergencia",
            .english: "Emergency Unlock"
        ],
        "popover.settings": [
            .spanish: "Ajustes",
            .english: "Settings"
        ],
        "popover.streak": [
            .spanish: "Racha",
            .english: "Streak"
        ],
        "popover.level": [
            .spanish: "Nivel",
            .english: "Level"
        ],
        "popover.quickstart": [
            .spanish: "Iniciar Rápido",
            .english: "Quick Start"
        ],

        // MARK: - Pantalla de Bloqueo Local
        "blockpage.title": [
            .spanish: "Acceso Bloqueado",
            .english: "Access Blocked"
        ],
        "blockpage.subtitle": [
            .spanish: "Has intentado acceder a un sitio bloqueado",
            .english: "You attempted to access a blocked destination"
        ],
        "blockpage.btn.close": [
            .spanish: "✓ Cerrar Pestaña y Volver al Enfoque",
            .english: "✓ Close Tab & Return to Focus"
        ],
        "blockpage.btn.partner": [
            .spanish: "🔑 Pedir Más Tiempo al Compañero",
            .english: "🔑 Request Extra Time from Partner"
        ],
        "blockpage.modal.title": [
            .spanish: "Desbloqueo de Compañero",
            .english: "Partner Authorization"
        ],
        "blockpage.modal.desc": [
            .spanish: "Pide a tu compañero que ingrese la clave maestra para otorgar tiempo extra hoy:",
            .english: "Ask your accountability partner to enter their master PIN to grant extra time today:"
        ],
        "blockpage.modal.pin": [
            .spanish: "Clave del Compañero:",
            .english: "Partner PIN:"
        ],
        "blockpage.modal.time": [
            .spanish: "Tiempo Adicional a Otorgar:",
            .english: "Additional Time to Grant:"
        ],
        "blockpage.modal.authorize": [
            .spanish: "✓ Autorizar y Desbloquear",
            .english: "✓ Authorize & Unlock"
        ],
        "blockpage.modal.cancel": [
            .spanish: "Cancelar",
            .english: "Cancel"
        ],

        // MARK: - Notificaciones macOS
        "notif.interception.title": [
            .spanish: "🛡️ Distracción / Búsqueda Interceptada",
            .english: "🛡️ Distraction / Search Intercepted"
        ],
        "notif.interception.body": [
            .spanish: "FocusPanic detuvo el acceso a '%@' para proteger tu enfoque.",
            .english: "FocusPanic blocked access to '%@' to safeguard your focus."
        ],
        "notif.whitelist.title": [
            .spanish: "🛡️ Sitio No Permitido (Modo Total)",
            .english: "🛡️ Restricted Destination (Total Mode)"
        ],
        "notif.whitelist.body": [
            .spanish: "El sitio '%@' no está en tu lista de permitidos.",
            .english: "The site '%@' is not on your allowed whitelist."
        ]
    ]
}
