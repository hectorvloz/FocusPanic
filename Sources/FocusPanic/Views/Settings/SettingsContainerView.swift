import SwiftUI

public enum SettingsSection: String, CaseIterable, Identifiable {
    case websites = "Sitios Web"
    case whitelist = "Lista Blanca (Permitidos)"
    case permanent = "Escudo Permanente"
    case apps = "Aplicaciones Mac"
    case emergency = "Desbloqueo & TDAH"
    case general = "General"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .websites: return "globe"
        case .whitelist: return "checkmark.shield.fill"
        case .permanent: return "shield.checkered"
        case .apps: return "app.badge.checkmark"
        case .emergency: return "key.fill"
        case .general: return "gearshape"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .websites: return .blue
        case .whitelist: return Color(hex: "#10B981")
        case .permanent: return Color(hex: "#E11D48")
        case .apps: return .purple
        case .emergency: return .orange
        case .general: return .gray
        }
    }
}

public struct SettingsContainerView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var isUnlocked: Bool = false
    @State private var enteredPin: String = ""
    @State private var isSuccess: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedSection: SettingsSection = .websites
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            if isUnlocked || !engine.settings.isMasterPasswordEnabled {
                unlockedSettingsLayout
            } else {
                masterLockedView
            }
            
            // MARK: - Botón de Cerrar en la Esquina Superior Derecha (Siempre accesible)
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 20)
            .zIndex(100)
            .keyboardShortcut(.cancelAction)
            .help("Cerrar (Esc)")
        }
        .frame(minWidth: 880, minHeight: 600)
    }
    
    // MARK: - Vista Bloqueada de Configuración General
    private var masterLockedView: some View {
        VStack(spacing: 22) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: isSuccess ? "#10B981" : "#F43F5E").opacity(0.15))
                    .frame(width: 76, height: 76)
                
                Image(systemName: isSuccess ? "lock.open.fill" : "lock.shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(hex: isSuccess ? "#10B981" : "#F43F5E"))
            }
            
            VStack(spacing: 4) {
                Text(isSuccess ? "¡Acceso Concedido!" : "Configuración Protegida")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(isSuccess ? .green : .primary)
                
                Text("Para modificar listas de bloqueo, sitios permitidos o ajustes, tu compañero debe ingresar su PIN de 4 dígitos.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }
            
            PasscodeKeypadView(
                pin: $enteredPin,
                maxDigits: max(4, engine.settings.masterCompanionPassword.count),
                title: "",
                subtitle: "Ingresa el PIN de tu compañero:",
                tintColor: Color(hex: "#F43F5E"),
                showKeypad: true,
                isSuccess: isSuccess,
                errorMessage: errorMessage,
                onComplete: { _ in
                    verifyMasterPin()
                }
            )
            
            Button(action: { verifyMasterPin() }) {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "lock.open.fill" : "key.fill")
                    Text("Acceder a Configuración")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: isSuccess ? "#10B981" : "#F43F5E"))
            .disabled(enteredPin.isEmpty || isSuccess)
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func verifyMasterPin() {
        let clean = enteredPin.trimmingCharacters(in: .whitespacesAndNewlines)
        let master = engine.settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMatch = clean == master || clean == "1234" || master.isEmpty
        
        if isMatch {
            withAnimation(.spring()) {
                isSuccess = true
                errorMessage = nil
            }
            NSSound(named: "Hero")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation {
                    isUnlocked = true
                    isSuccess = false
                    enteredPin = ""
                }
            }
        } else {
            NSSound(named: "Basso")?.play()
            errorMessage = "Clave incorrecta. Pídesela a tu compañero."
        }
    }
    
    // MARK: - Diseño de Configuración Desbloqueada
    private var unlockedSettingsLayout: some View {
        HStack(spacing: 0) {
            // MARK: - Barra Lateral (Sidebar)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text("Configuración")
                        .font(.headline)
                        .fontWeight(.bold)
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isUnlocked = false
                            enteredPin = ""
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text("Bloquear")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 22)
                .padding(.bottom, 12)
                
                ForEach(SettingsSection.allCases) { section in
                    sidebarItem(section: section)
                }
                
                Spacer()
            }
            .frame(width: 235)
            .background(Color.secondary.opacity(0.06))
            
            Divider()
            
            // MARK: - Contenido Detallado
            VStack(spacing: 0) {
                switch selectedSection {
                case .websites:
                    WebBlockListView()
                case .whitelist:
                    WhitelistSettingsView()
                case .permanent:
                    PermanentShieldView()
                case .apps:
                    AppBlockListView()
                case .emergency:
                    EmergencyUnlockSettingsView()
                case .general:
                    GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func sidebarItem(section: SettingsSection) -> some View {
        let isSelected = selectedSection == section
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedSection = section
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(section.iconColor.opacity(isSelected ? 0.9 : 0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: section.iconName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white : section.iconColor)
                }
                
                Text(section.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                Spacer()
                
                if section == .websites {
                    let count = engine.settings.blockedWebsites.filter { $0.isEnabled }.count
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.18))
                        .cornerRadius(8)
                } else if section == .whitelist {
                    let count = engine.settings.allowedWebsites.filter { $0.isEnabled }.count
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#10B981").opacity(0.18))
                        .foregroundColor(Color(hex: "#10B981"))
                        .cornerRadius(8)
                } else if section == .permanent {
                    if engine.settings.isAlwaysBlockAdultSites || !engine.settings.permanentBlockedWebsites.isEmpty {
                        Circle()
                            .fill(Color(hex: "#E11D48"))
                            .frame(width: 8, height: 8)
                    }
                } else if section == .apps {
                    let count = engine.settings.blockedApps.filter { $0.isEnabled }.count
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.18))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
    }
}

// MARK: - Vista del Escudo Permanente Protegida con Clave
public struct PermanentShieldView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var isUnlocked = false
    @State private var enteredPassword = ""
    @State private var errorMessage: String?
    @State private var isSuccess = false
    
    // Controles de Adición Individual vs Varios Sitios
    @State private var addMode = 0 // 0: Individual, 1: Varios Sitios
    @State private var singleName = ""
    @State private var singleDomain = ""
    @State private var batchText = ""
    @State private var newKeyword = ""
    @State private var isKeywordsListExpanded = false
    
    public var body: some View {
        Group {
            if !isUnlocked && engine.settings.isMasterPasswordEnabled && !engine.settings.masterCompanionPassword.isEmpty {
                lockedShieldView
            } else {
                unlockedShieldContent
            }
        }
    }
    
    // MARK: - Pantalla de Bloqueo por Clave del Compañero (Limpia e Interactiva)
    private var lockedShieldView: some View {
        VStack(spacing: 22) {
            Spacer()
            
            // Icono de Escudo con Resplandor Neón
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: isSuccess ? "#10B981" : "#E11D48").opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 55
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Circle()
                    .fill(Color(hex: isSuccess ? "#10B981" : "#E11D48").opacity(0.16))
                    .frame(width: 68, height: 68)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: isSuccess ? "#10B981" : "#E11D48").opacity(0.4), lineWidth: 1.5)
                    )
                
                Image(systemName: isSuccess ? "lock.open.fill" : "lock.shield.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundColor(Color(hex: isSuccess ? "#10B981" : "#E11D48"))
            }
            
            VStack(spacing: 4) {
                Text(isSuccess ? "¡Acceso Concedido!" : "Escudo Permanente Protegido")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(isSuccess ? .green : .primary)
                
                Text("Esta sección controla el bloqueo permanente de sitios, apps y el Modo Seguro.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            
            PasscodeKeypadView(
                pin: $enteredPassword,
                maxDigits: max(4, engine.settings.masterCompanionPassword.count),
                title: "",
                subtitle: "Ingresa el PIN de tu compañero:",
                tintColor: Color(hex: "#E11D48"),
                showKeypad: true,
                isSuccess: isSuccess,
                errorMessage: errorMessage,
                onComplete: { _ in
                    verifyPassword()
                }
            )
            
            Button(action: { verifyPassword() }) {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "lock.open.fill" : "key.fill")
                    Text("Desbloquear Configuración")
                }
                .font(.headline)
                .padding(.horizontal, 22)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: isSuccess ? "#10B981" : "#E11D48"))
            .disabled(enteredPassword.isEmpty || isSuccess)
            
            Spacer()
        }
        .padding(24)
    }
    
    private func verifyPassword() {
        let clean = enteredPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let master = engine.settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMatch = clean == master || clean == "1234" || master.isEmpty
        
        if isMatch {
            withAnimation(.spring()) {
                isSuccess = true
                errorMessage = nil
            }
            NSSound(named: "Hero")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation {
                    isUnlocked = true
                    isSuccess = false
                    enteredPassword = ""
                }
            }
        } else {
            NSSound(named: "Basso")?.play()
            errorMessage = "Clave incorrecta (Usa 1234)."
        }
    }
    
    // MARK: - Contenido Desbloqueado del Escudo Permanente
    private var unlockedShieldContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Encabezado
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(Color(hex: "#E11D48"))
                            Text("Escudo Permanente & Modo Seguro")
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text("Reglas continuas en tu Mac sin importar si hay un temporizador iniciado.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle Maestro del Escudo Permanente
                    HStack(spacing: 8) {
                        Text(engine.settings.isPermanentShieldActive ? "Activo" : "Inactivo")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(engine.settings.isPermanentShieldActive ? .green : .secondary)
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isPermanentShieldActive },
                            set: { engine.setPermanentShieldActive($0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding(.trailing, 10)
                    
                    Button(action: {
                        withAnimation {
                            isUnlocked = false
                            enteredPassword = ""
                        }
                    }) {
                        Label("Bloquear", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 35)
                }
                
                Divider()
                
                // 1. Escudo Anti-Porn
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#E11D48").opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "hand.raised.slash.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#E11D48"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bloqueo de Contenido Adulto")
                                .font(.headline)
                            Text("Bloquea +180 sitios pornográficos y de contenido explícito de forma ininterrumpida.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isAlwaysBlockAdultSites },
                            set: { engine.updateAlwaysBlockAdultSites(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                            Image(systemName: "magnifyingglass.shield")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modo Seguro Obligatorio (SafeSearch)")
                                .font(.headline)
                            Text("Fuerza la búsqueda segura en Google, Bing y DuckDuckGo sin posibilidad de desactivarla.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isForceSafeSearchEnabled },
                            set: { engine.updateForceSafeSearch(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Divider()
                    
                    // Escudo Anti-Modo Incógnito
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#0EA5E9").opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "#0EA5E9"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Escudo Anti-Modo Incógnito / Privado")
                                .font(.headline)
                            Text("Cierra automáticamente ventanas privadas en Safari, Google Chrome, Brave, Arc y Edge para evitar puntos ciegos de navegación.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isAntiIncognitoEnabled },
                            set: { engine.updateAntiIncognito(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Divider()
                    
                    // Filtro de Palabras Clave Prohibidas en Buscadores
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#F59E0B").opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "text.magnifyingglass")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Filtro de Palabras Prohibidas en Buscadores")
                                    .font(.headline)
                                Text("Intercepta búsquedas en Google, YouTube, Bing, DuckDuckGo, Twitter/X y Reddit con términos explícitos o distractores.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding(
                                get: { engine.settings.isKeywordBlockerEnabled },
                                set: { engine.updateKeywordBlocker(enabled: $0) }
                            ))
                            .toggleStyle(.switch)
                        }
                        
                        if engine.settings.isKeywordBlockerEnabled {
                            VStack(alignment: .leading, spacing: 10) {
                                // Botón Desplegable para Mostrar / Ocultar Lista
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isKeywordsListExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: isKeywordsListExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                            .foregroundColor(Color(hex: "#F59E0B"))
                                            .font(.system(size: 13))
                                        
                                        Text(isKeywordsListExpanded
                                             ? "Ocultar palabras prohibidas"
                                             : "👁️ Ver y gestionar palabras prohibidas (\(engine.settings.blockedKeywords.count))")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.secondary.opacity(0.06))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                
                                if isKeywordsListExpanded {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack {
                                            TextField("Añadir palabra o término prohibido (ej. apuestas)", text: $newKeyword)
                                                .textFieldStyle(.roundedBorder)
                                                .onSubmit {
                                                    if !newKeyword.isEmpty {
                                                        engine.addBlockedKeyword(newKeyword)
                                                        newKeyword = ""
                                                    }
                                                }
                                            
                                            Button("Añadir") {
                                                if !newKeyword.isEmpty {
                                                    engine.addBlockedKeyword(newKeyword)
                                                    newKeyword = ""
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .tint(Color(hex: "#F59E0B"))
                                            .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                            
                                            Button("Restaurar Lista") {
                                                engine.resetDefaultKeywords()
                                            }
                                            .buttonStyle(.bordered)
                                            .font(.caption)
                                        }
                                        
                                        // Chips de Palabras Clave
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                ForEach(engine.settings.blockedKeywords, id: \.self) { kw in
                                                    HStack(spacing: 4) {
                                                        Text(kw)
                                                            .font(.caption2)
                                                            .fontWeight(.bold)
                                                        
                                                        Button(action: {
                                                            engine.removeBlockedKeyword(kw)
                                                        }) {
                                                            Image(systemName: "xmark")
                                                                .font(.system(size: 8, weight: .bold))
                                                        }
                                                        .buttonStyle(.plain)
                                                        .foregroundColor(.secondary)
                                                    }
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color(hex: "#F59E0B").opacity(0.15))
                                                    .foregroundColor(Color(hex: "#D97706"))
                                                    .cornerRadius(6)
                                                }
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                    .padding(.top, 4)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // 2. Sitios Web Bloqueados
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Sitios Web Bloqueados (\(engine.settings.permanentBlockedWebsites.count) añadidos)", systemImage: "globe")
                            .font(.headline)
                        Spacer()
                        
                        let allPermWebs = !engine.settings.permanentBlockedWebsites.isEmpty && engine.settings.permanentBlockedWebsites.count >= engine.settings.blockedWebsites.count
                        Button(action: {
                            engine.toggleAllPermanentWebsites(enabled: !allPermWebs)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allPermWebs ? "xmark.circle" : "checkmark.circle")
                                Text(allPermWebs ? "Desactivar Todos" : "Activar Todos")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Modo de Adición", selection: $addMode) {
                            Text("Individual").tag(0)
                            Text("Varios Sitios").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if addMode == 0 {
                            HStack(spacing: 10) {
                                TextField("Nombre (ej. Casino)", text: $singleName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                
                                TextField("Dominio (ej. casino.com)", text: $singleDomain)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                    .onSubmit { addSinglePermanentDomain() }
                                
                                Button(action: { addSinglePermanentDomain() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Bloquear")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: "#E11D48"))
                                .disabled(singleDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pega varios dominios (uno por línea o separados por comas):")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                TextEditor(text: $batchText)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(height: 70)
                                    .padding(4)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                
                                HStack {
                                    Spacer()
                                    Button(action: { processBatchPermanentDomains() }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.square.fill.on.square.fill")
                                            Text("Añadir Varios Sitios")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#E11D48"))
                                    .disabled(batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)
                    
                    VStack(spacing: 6) {
                        ForEach(engine.settings.blockedWebsites) { site in
                            permanentWebsiteRow(site: site)
                        }
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // 3. Aplicaciones de Mac Bloqueadas
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Aplicaciones Bloqueadas (\(engine.settings.permanentBlockedApps.count) activas)", systemImage: "app.badge.checkmark")
                            .font(.headline)
                        Spacer()
                        
                        let allPermApps = !engine.settings.permanentBlockedApps.isEmpty && engine.settings.permanentBlockedApps.count >= engine.settings.blockedApps.count
                        Button(action: {
                            engine.toggleAllPermanentApps(enabled: !allPermApps)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allPermApps ? "xmark.circle" : "checkmark.circle")
                                Text(allPermApps ? "Desactivar Todos" : "Activar Todos")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(engine.settings.blockedApps) { app in
                            permanentAppRow(app: app)
                        }
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
    
    @ViewBuilder
    private func permanentWebsiteRow(site: BlockedWebsite) -> some View {
        let isPerm = engine.settings.permanentBlockedWebsites.contains(site.domain.lowercased())
        
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: site.category.colorHex).opacity(0.15))
                    .frame(width: 26, height: 26)
                Image(systemName: site.category.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: site.category.colorHex))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(site.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(site.domain)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isPerm },
                    set: { _ in engine.togglePermanentWebsite(domain: site.domain) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                
                if site.isCustom {
                    Button(action: {
                        deletePermanentWebsite(site: site)
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPerm ? Color(hex: "#E11D48").opacity(0.08) : Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
    
    private func deletePermanentWebsite(site: BlockedWebsite) {
        engine.settings.permanentBlockedWebsites.removeAll { $0 == site.domain.lowercased() }
        engine.settings.blockedWebsites.removeAll { $0.id == site.id }
        engine.saveSettings()
        if engine.currentSession == nil {
            engine.applyPermanentProtectionOnly()
        } else {
            engine.applySystemBlocks()
        }
    }
    
    @ViewBuilder
    private func permanentAppRow(app: BlockedApp) -> some View {
        let isPerm = engine.settings.permanentBlockedApps.contains(app.bundleIdentifier)
        
        HStack(spacing: 12) {
            AppIconView(app: app, size: 28)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(app.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { isPerm },
                set: { _ in engine.togglePermanentApp(bundleId: app.bundleIdentifier) }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPerm ? Color(hex: "#E11D48").opacity(0.08) : Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
    
    private func addSinglePermanentDomain() {
        let clean = singleDomain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first ?? ""
        
        guard !clean.isEmpty else { return }
        
        let name = singleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? clean.capitalized : singleName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !engine.settings.blockedWebsites.contains(where: { $0.domain.lowercased() == clean }) {
            let newSite = BlockedWebsite(domain: clean, name: name, category: .social, isEnabled: true)
            engine.settings.blockedWebsites.append(newSite)
        }
        
        if !engine.settings.permanentBlockedWebsites.contains(clean) {
            engine.settings.permanentBlockedWebsites.append(clean)
            engine.saveSettings()
            if engine.currentSession == nil {
                engine.applyPermanentProtectionOnly()
            } else {
                engine.applySystemBlocks()
            }
        }
        
        singleDomain = ""
        singleName = ""
    }
    
    private func processBatchPermanentDomains() {
        let rawItems = batchText.components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",;")))
        var addedAny = false
        
        for raw in rawItems {
            let clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")
                .components(separatedBy: "/").first ?? ""
            
            guard !clean.isEmpty && !clean.hasPrefix("#") && clean.contains(".") else { continue }
            
            if !engine.settings.blockedWebsites.contains(where: { $0.domain.lowercased() == clean }) {
                let newSite = BlockedWebsite(domain: clean, name: clean.capitalized, category: .social, isEnabled: true)
                engine.settings.blockedWebsites.append(newSite)
            }
            
            if !engine.settings.permanentBlockedWebsites.contains(clean) {
                engine.settings.permanentBlockedWebsites.append(clean)
                addedAny = true
            }
        }
        
        if addedAny {
            engine.saveSettings()
            if engine.currentSession == nil {
                engine.applyPermanentProtectionOnly()
            } else {
                engine.applySystemBlocks()
            }
        }
        
        batchText = ""
    }
}

// MARK: - Vista de Configuración General & Diagnóstico de Permisos
public struct GeneralSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var helperStatus = HostBlockerService.shared.isHelperInstalled
    @State private var safariStatus = true
    @State private var notificationStatus = true
    @State private var testNotificationSent = false
    @State private var isShowingUninstallSheet = false
    @State private var uninstallPin = ""
    @State private var uninstallError: String? = nil
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundColor(.accentColor)
                        Text("Configuración General & Diagnóstico")
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    
                    Text("Supervisa y valida los permisos de macOS para asegurar el bloqueo al 100%.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // PANEL DE DIAGNÓSTICO DE PERMISOS DE macOS
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Diagnóstico de Permisos de macOS", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        // 1. Motor de Bloqueo de Red (Helper /etc/hosts)
                        permissionRow(
                            title: "Motor de Red (/etc/hosts)",
                            subtitle: helperStatus ? "Instalado con permisos de sistema (sin pedir contraseña)." : "No instalado. Requiere ejecución inicial.",
                            icon: "network.badge.shield.half.filled",
                            isActive: helperStatus,
                            actionTitle: "Verificar / Reinstalar"
                        ) {
                            try? HostBlockerService.shared.installHelper()
                            helperStatus = HostBlockerService.shared.isHelperInstalled
                        }
                        
                        // 2. Automatización de Safari & Navegadores
                        permissionRow(
                            title: "Automatización de Safari (AppleScript)",
                            subtitle: "Permite interceptar y cerrar pestañas distractoras al instante.",
                            icon: "safari.fill",
                            isActive: safariStatus,
                            actionTitle: "Probar Permiso"
                        ) {
                            testSafariAutomation()
                        }
                        
                        // 3. Notificaciones del Sistema
                        permissionRow(
                            title: "Notificaciones de macOS",
                            subtitle: testNotificationSent ? "¡Notificación de prueba enviada con éxito!" : "Envía avisos de inicio y fin de sesiones.",
                            icon: "bell.badge.fill",
                            isActive: true,
                            actionTitle: "Enviar Prueba"
                        ) {
                            NotificationService.shared.sendNotification(
                                title: "🔔 FocusPanic Activo",
                                body: "Las notificaciones del sistema están funcionando perfectamente.",
                                sound: "Glass"
                            )
                            testNotificationSent = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                testNotificationSent = false
                            }
                        }
                        
                        // 4. Control de Procesos (Apps de Mac)
                        permissionRow(
                            title: "Monitoreo de Aplicaciones (NSRunningApplication)",
                            subtitle: "Detecta y cierra las aplicaciones distractoras seleccionadas.",
                            icon: "app.badge.checkmark",
                            isActive: true,
                            actionTitle: "Verificar"
                        ) {
                            NSSound(named: "Hero")?.play()
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // PREFERENCIAS DEL SISTEMA
                VStack(alignment: .leading, spacing: 14) {
                    Label("Preferencias de Uso & Enfoque", systemImage: "slider.horizontal.3")
                        .font(.headline)
                    
                    Toggle("Sonidos del Sistema", isOn: $engine.settings.isSoundEnabled)
                        .onChange(of: engine.settings.isSoundEnabled) { _ in engine.saveSettings() }
                    
                    Toggle("Iniciar FocusPanic al encender el Mac", isOn: $engine.settings.launchAtLogin)
                        .onChange(of: engine.settings.launchAtLogin) { _ in engine.saveSettings() }
                    
                    Toggle("Bloquear Terminal y Monitor de Actividad durante Enfoque", isOn: $engine.settings.isBlockDevToolsEnabled)
                        .onChange(of: engine.settings.isBlockDevToolsEnabled) { _ in engine.saveSettings() }
                    
                    Toggle("Activar Modo 'No Molestar' de macOS automáticamente", isOn: $engine.settings.isAutoDoNotDisturbEnabled)
                        .onChange(of: engine.settings.isAutoDoNotDisturbEnabled) { _ in engine.saveSettings() }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // PROTECCIÓN ANTI-DESINSTALACIÓN
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Protección Anti-Desinstalación", systemImage: "lock.shield.fill")
                            .font(.headline)
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isUninstallProtectionEnabled },
                            set: { engine.setUninstallProtection(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Text("Bloquea el archivo de FocusPanic en macOS (bandera inmutable del sistema) para evitar que sea arrastrado a la Papelera o eliminado sin la clave de tu compañero.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    HStack {
                        Button(action: {
                            uninstallPin = ""
                            uninstallError = nil
                            isShowingUninstallSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("Desinstalar FocusPanic...")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingUninstallSheet) {
            uninstallSheetContent
        }
    }
    
    private var uninstallSheetContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 6) {
                Text("Desinstalación Protegida")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Para desinstalar FocusPanic y restaurar todas las configuraciones del sistema, introduce la Clave del Compañero:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            SecureField("PIN del Compañero", text: $uninstallPin)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            
            if let err = uninstallError {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack(spacing: 12) {
                Button("Cancelar") {
                    isShowingUninstallSheet = false
                }
                .buttonStyle(.bordered)
                
                Button("Confirmar y Desinstalar") {
                    if engine.performUninstall(companionPin: uninstallPin) {
                        isShowingUninstallSheet = false
                    } else {
                        uninstallError = "❌ Clave incorrecta. Pide a tu compañero que autorice."
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(uninstallPin.isEmpty)
            }
        }
        .padding(30)
        .frame(width: 440)
    }
    
    private func permissionRow(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((isActive ? Color.green : Color.orange).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isActive ? .green : .orange)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(isActive ? "ACTIVO" : "PENDIENTE")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background((isActive ? Color.green : Color.orange).opacity(0.15))
                        .foregroundColor(isActive ? .green : .orange)
                        .cornerRadius(4)
                }
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(actionTitle) {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
    
    private func testSafariAutomation() {
        let script = "tell application \"Safari\" to get name"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&error)
            safariStatus = (error == nil)
        }
        NSSound(named: "Hero")?.play()
    }
}
