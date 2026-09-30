import SwiftUI

public enum SettingsGroup: String, CaseIterable {
    case blocking = "REGLAS DE BLOQUEO"
    case screenTime = "HORARIOS & TIEMPO"
    case system = "SEGURIDAD & AJUSTES"
    
    public var localizedTitle: String {
        switch self {
        case .blocking: return L10n.tr("settings.group.blocking")
        case .screenTime: return L10n.tr("settings.group.screenTime")
        case .system: return L10n.tr("settings.group.system")
        }
    }
    
    public var sections: [SettingsSection] {
        switch self {
        case .blocking:
            return [.websites, .apps, .permanent]
        case .screenTime:
            return [.downtime, .appLimits, .whitelist]
        case .system:
            return [.emergency, .general]
        }
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable {
    case websites = "Sitios Web"
    case apps = "Aplicaciones Mac"
    case permanent = "Escudo Permanente"
    case downtime = "Tiempo Desactivado"
    case appLimits = "Límites para apps"
    case whitelist = "Lista Blanca (Permitidos)"
    case emergency = "Desbloqueo"
    case general = "General"
    
    public var id: String { rawValue }
    
    public var localizedTitle: String {
        switch self {
        case .websites: return L10n.tr("section.websites")
        case .apps: return L10n.tr("section.apps")
        case .permanent: return L10n.tr("section.permanent")
        case .downtime: return L10n.tr("section.downtime")
        case .appLimits: return L10n.tr("section.appLimits")
        case .whitelist: return L10n.tr("section.whitelist")
        case .emergency: return L10n.tr("section.emergency")
        case .general: return L10n.tr("section.general")
        }
    }
    
    public var iconName: String {
        switch self {
        case .websites: return "globe"
        case .apps: return "app.badge.checkmark"
        case .permanent: return "shield.checkered"
        case .downtime: return "clock.badge.checkmark.fill"
        case .appLimits: return "hourglass"
        case .whitelist: return "checkmark.shield.fill"
        case .emergency: return "key.fill"
        case .general: return "gearshape"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .websites: return .blue
        case .apps: return .purple
        case .permanent: return Color(hex: "#E11D48")
        case .downtime: return Color(hex: "#6366F1")
        case .appLimits: return Color(hex: "#F59E0B")
        case .whitelist: return Color(hex: "#10B981")
        case .emergency: return .orange
        case .general: return .gray
        }
    }
}

public struct SettingsContainerView: View {
    @ObservedObject var engine = FocusEngine.shared
    @ObservedObject var l10n = LocalizationService.shared
    @State private var isUnlocked: Bool = false
    @State private var enteredPin: String = ""
    @State private var isSuccess: Bool = false
    @State private var errorMessage: String? = nil
    @State private var selectedSection: SettingsSection = .websites
    @Environment(\.dismiss) private var dismiss
    
    // Estados para la recuperación de contraseña tras 3 intentos fallidos
    @State private var failedPinAttempts: Int = 0
    @State private var isShowingForgotModal: Bool = false
    
    @State private var recoveryMethodIndex: Int = 0 // 0: Pregunta Secreta, 1: Correo Electrónico
    @State private var recoverySecurityAnswer: String = ""
    @State private var recoveryNewPin: String = ""
    @State private var recoveryConfirmPin: String = ""
    @State private var recoveryEmailCode: String = ""
    @State private var sentRecoveryCode: String = ""
    @State private var isSendingEmailCode: Bool = false
    @State private var emailCodeSentMessage: String? = nil
    @State private var recoveryErrorMessage: String? = nil
    @State private var recoverySuccessMessage: String? = nil
    
    // Estados para la Copia de Seguridad & Transferencia
    @State private var backupMessage: String? = nil
    @State private var isBackupSuccess: Bool = true
    
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
        .frame(width: 900, height: 620)
        .sheet(isPresented: $isShowingForgotModal) {
            companionRecoverySheetContent
        }
    }
    
    // MARK: - Vista Bloqueada de Configuración General
    private var masterLockedView: some View {
        VStack(spacing: 20) {
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
            
            VStack(spacing: 12) {
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
                
                // Enlace de Recuperación tras 3 Intentos Fallidos
                if failedPinAttempts >= 3 {
                    Button(action: {
                        resetRecoveryForm()
                        isShowingForgotModal = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "questionmark.circle.fill")
                            Text("¿Olvidaste la contraseña del compañero?")
                                .underline()
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#F43F5E"))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func verifyMasterPin() {
        let clean = enteredPin.trimmingCharacters(in: .whitespacesAndNewlines)
        let master = engine.settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let isMatch = (!master.isEmpty && clean == master) || master.isEmpty
        
        if isMatch {
            withAnimation(.spring()) {
                isSuccess = true
                errorMessage = nil
                failedPinAttempts = 0
            }
            SoundService.shared.play("Hero")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation {
                    isUnlocked = true
                    isSuccess = false
                    enteredPin = ""
                }
            }
        } else {
            SoundService.shared.play("Basso")
            failedPinAttempts += 1
            if failedPinAttempts >= 3 {
                errorMessage = "Clave incorrecta (Intento \(failedPinAttempts)). Puedes recuperar el acceso abajo."
            } else {
                errorMessage = "Clave incorrecta (Intento \(failedPinAttempts) de 3). Pídesela a tu compañero."
            }
        }
    }
    
    // MARK: - Modal Profesional de Recuperación de Contraseña
    private var companionRecoverySheetContent: some View {
        VStack(spacing: 18) {
            // Encabezado
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F43F5E").opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#F43F5E"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recuperar Clave de Compañero")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Restablece el PIN maestro utilizando tu método de seguridad configurado.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cerrar") {
                    isShowingForgotModal = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Divider()
            
            // Selector de Método de Recuperación
            let hasEmail = !availableRecoveryEmail.isEmpty
            Picker("Método de Recuperación", selection: $recoveryMethodIndex) {
                Text("Pregunta Secreta").tag(0)
                if hasEmail {
                    Text("Correo Electrónico").tag(1)
                }
            }
            .pickerStyle(.segmented)
            
            // Mensajes de Estado
            if let error = recoveryErrorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.red)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let success = recoverySuccessMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text(success)
                        .font(.caption)
                }
                .foregroundColor(.green)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Formulario según el Método
            if recoveryMethodIndex == 0 {
                // MARK: Método 1 - Pregunta Secreta
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pregunta de Seguridad:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        Text("\"\(engine.settings.securityQuestion)\"")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Respuesta Secreta:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        SecureField("Escribe la respuesta exacta...", text: $recoverySecurityAnswer)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    pinResetInputFields
                }
            } else {
                // MARK: Método 2 - Correo Electrónico
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Correo de Recuperación Registrado:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text(obfuscateEmail(availableRecoveryEmail))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            
                            Button(action: { sendRecoveryEmailCode() }) {
                                HStack(spacing: 4) {
                                    if isSendingEmailCode {
                                        ProgressView().controlSize(.small)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(sentRecoveryCode.isEmpty ? "Enviar Código" : "Reenviar")
                                }
                                .font(.caption)
                                .fontWeight(.semibold)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .controlSize(.small)
                            .disabled(isSendingEmailCode)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(8)
                    }
                    
                    if let msg = emailCodeSentMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                            Text(msg)
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Código de 6 dígitos recibido:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                        
                        TextField("ej. 123456", text: $recoveryEmailCode)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    pinResetInputFields
                }
            }
            
            Spacer()
            
            // Botón de Acción Principal
            Button(action: { submitPasswordRecovery() }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Restablecer PIN y Acceder a Configuración")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#F43F5E"))
            .disabled(!isRecoveryFormValid)
        }
        .padding(24)
        .frame(width: 520, height: 530)
    }
    
    private var pinResetInputFields: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nuevo PIN (4 dígitos):")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                SecureField("••••", text: $recoveryNewPin)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Confirmar PIN:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                
                SecureField("••••", text: $recoveryConfirmPin)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
    
    private var availableRecoveryEmail: String {
        if !engine.settings.recoveryEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return engine.settings.recoveryEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !engine.settings.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return engine.settings.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }
    
    private func obfuscateEmail(_ email: String) -> String {
        let parts = email.components(separatedBy: "@")
        guard parts.count == 2, let first = parts.first, let domain = parts.last else { return email }
        if first.count <= 2 {
            return "\(first.prefix(1))***@\(domain)"
        }
        return "\(first.prefix(2))***\(first.suffix(1))@\(domain)"
    }
    
    private var isRecoveryFormValid: Bool {
        guard recoveryNewPin.count >= 4 && recoveryNewPin == recoveryConfirmPin else { return false }
        if recoveryMethodIndex == 0 {
            return !recoverySecurityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !recoveryEmailCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func resetRecoveryForm() {
        recoverySecurityAnswer = ""
        recoveryNewPin = ""
        recoveryConfirmPin = ""
        recoveryEmailCode = ""
        sentRecoveryCode = ""
        isSendingEmailCode = false
        emailCodeSentMessage = nil
        recoveryErrorMessage = nil
        recoverySuccessMessage = nil
        recoveryMethodIndex = 0
    }
    
    private func sendRecoveryEmailCode() {
        let email = availableRecoveryEmail
        guard !email.isEmpty else {
            recoveryErrorMessage = "No hay un correo de recuperación configurado."
            return
        }
        
        isSendingEmailCode = true
        recoveryErrorMessage = nil
        let code = EmailService.shared.generateEmergencyCode()
        sentRecoveryCode = code
        
        EmailService.shared.sendEmergencyCode(
            code: code,
            toEmail: email,
            reflectionText: "Recuperación de clave maestra de FocusPanic",
            smtpSettings: engine.settings.smtpSettings
        ) { result in
            isSendingEmailCode = false
            switch result {
            case .success(let msg):
                emailCodeSentMessage = "Código de 6 dígitos enviado exitosamente a \(obfuscateEmail(email)). Revisa tu bandeja de entrada."
                SoundService.shared.play("Hero")
            case .failure(let err):
                recoveryErrorMessage = "Error al enviar correo: \(err.localizedDescription)"
                SoundService.shared.play("Basso")
            }
        }
    }
    
    private func submitPasswordRecovery() {
        recoveryErrorMessage = nil
        
        // 1. Validar PIN
        guard recoveryNewPin.count >= 4 else {
            recoveryErrorMessage = "El PIN debe tener al menos 4 dígitos."
            SoundService.shared.play("Basso")
            return
        }
        guard recoveryNewPin == recoveryConfirmPin else {
            recoveryErrorMessage = "Los dos campos de PIN no coinciden."
            SoundService.shared.play("Basso")
            return
        }
        
        // 2. Validar según método
        if recoveryMethodIndex == 0 {
            let cleanAnswer = recoverySecurityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let expectedAnswer = engine.settings.securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            let isCorrect = !expectedAnswer.isEmpty && cleanAnswer == expectedAnswer
            guard isCorrect else {
                recoveryErrorMessage = "Respuesta de seguridad incorrecta."
                SoundService.shared.play("Basso")
                return
            }
        } else {
            let cleanCode = recoveryEmailCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanCode == sentRecoveryCode && !cleanCode.isEmpty else {
                recoveryErrorMessage = "El código de verificación del correo no es válido."
                SoundService.shared.play("Basso")
                return
            }
        }
        
        // 3. Aplicar nuevo PIN y desbloquear
        engine.settings.masterCompanionPassword = recoveryNewPin
        engine.settings.isMasterPasswordEnabled = true
        engine.saveSettings()
        
        failedPinAttempts = 0
        recoverySuccessMessage = "¡Clave restablecida exitosamente! Accediendo..."
        SoundService.shared.play("Hero")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isShowingForgotModal = false
            isUnlocked = true
            enteredPin = ""
        }
    }
    
    // MARK: - Diseño de Configuración Desbloqueada
    private var unlockedSettingsLayout: some View {
        HStack(spacing: 0) {
            // MARK: - Barra Lateral (Sidebar)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Text(L10n.tr("settings.title"))
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
                            Text(L10n.tr("settings.lock"))
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(SettingsGroup.allCases, id: \.self) { group in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.localizedTitle)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.horizontal, 14)
                                    .padding(.bottom, 2)
                                
                                ForEach(group.sections) { section in
                                    sidebarItem(section: section)
                                }
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(width: 245)
            .background(Color.secondary.opacity(0.06))
            
            Divider()
            
            // MARK: - Contenido Detallado
            VStack(spacing: 0) {
                switch selectedSection {
                case .websites:
                    WebBlockListView()
                case .apps:
                    AppBlockListView()
                case .permanent:
                    PermanentShieldView()
                case .downtime:
                    DowntimeSettingsView()
                case .appLimits:
                    AppLimitsSettingsView()
                case .whitelist:
                    WhitelistSettingsView()
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
                
                Text(section.localizedTitle)
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
                } else if section == .downtime {
                    if engine.settings.downtimeSchedule.isEnabled {
                        Circle()
                            .fill(Color(hex: "#6366F1"))
                            .frame(width: 8, height: 8)
                    }
                } else if section == .appLimits {
                    let count = engine.settings.appLimits.filter { $0.isEnabled }.count
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#F59E0B").opacity(0.18))
                            .foregroundColor(Color(hex: "#F59E0B"))
                            .cornerRadius(8)
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
    @State private var isAddingPermanentDomain = false
    @State private var addMode = 0 // 0: Individual, 1: Varios Sitios
    @State private var singleDomain = ""
    @State private var batchText = ""
    @State private var permWebSearchText = ""
    @State private var newKeyword = ""
    @State private var isKeywordsListExpanded = false
    @State private var isWhatsAppShieldExpanded = false
    @State private var isShowingAppCatalogSheet = false
    @State private var discoveredApps: [BlockedApp] = []
    @State private var appSheetSearchText = ""
    @State private var isLoadingApps = false
    @State private var showAllPermanentWebsites = false
    @State private var showAllPermanentApps = false
    
    private var whatsAppActiveCount: Int {
        (engine.settings.isWhatsAppStatusBlockerEnabled ? 1 : 0) + (engine.settings.isWhatsAppChannelsBlockerEnabled ? 1 : 0)
    }
    
    private var permanentFilteredApps: [BlockedApp] {
        engine.settings.blockedApps
            .filter { AppBlockerService.isAppInstalled($0) }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }
    
    private var displayedPermanentApps: [BlockedApp] {
        if showAllPermanentApps || permanentFilteredApps.count <= 10 {
            return permanentFilteredApps
        }
        return Array(permanentFilteredApps.prefix(10))
    }
    
    private var permanentFilteredWebsites: [BlockedWebsite] {
        engine.settings.blockedWebsites
            .filter {
                permWebSearchText.isEmpty ||
                $0.name.localizedCaseInsensitiveContains(permWebSearchText) ||
                $0.domain.localizedCaseInsensitiveContains(permWebSearchText)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var displayedPermanentWebsites: [BlockedWebsite] {
        if !permWebSearchText.isEmpty || showAllPermanentWebsites || permanentFilteredWebsites.count <= 10 {
            return permanentFilteredWebsites
        }
        return Array(permanentFilteredWebsites.prefix(10))
    }
    
    private var filteredSheetApps: [BlockedApp] {
        let installed = discoveredApps.filter { AppBlockerService.isAppInstalled($0) }
        if appSheetSearchText.isEmpty {
            return installed.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        }
        return installed
            .filter {
                $0.appName.localizedCaseInsensitiveContains(appSheetSearchText) ||
                $0.bundleIdentifier.localizedCaseInsensitiveContains(appSheetSearchText)
            }
            .sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
    }
    
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
        let isMatch = (!master.isEmpty && clean == master) || master.isEmpty
        
        if isMatch {
            withAnimation(.spring()) {
                isSuccess = true
                errorMessage = nil
            }
            SoundService.shared.play("Hero")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation {
                    isUnlocked = true
                    isSuccess = false
                    enteredPassword = ""
                }
            }
        } else {
            SoundService.shared.play("Basso")
            errorMessage = "Clave incorrecta. Pídesela a tu compañero."
        }
    }
    
    // MARK: - Contenido Desbloqueado del Escudo Permanente
    private var unlockedShieldContent: some View {
        let isEn = LocalizationService.shared.currentLanguage == .english
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Encabezado
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(Color(hex: "#E11D48"))
                            Text(L10n.tr("permanent.header.title"))
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text(L10n.tr("permanent.header.subtitle"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle Maestro del Escudo Permanente
                    HStack(spacing: 8) {
                        Text(engine.settings.isPermanentShieldActive
                             ? (isEn ? "Active" : "Activo")
                             : (isEn ? "Inactive" : "Inactivo"))
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
                        Label(L10n.tr("settings.lock"), systemImage: "lock.fill")
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
                            Text(L10n.tr("permanent.adult.title"))
                                .font(.headline)
                            Text(L10n.tr("permanent.adult.desc"))
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
                    
                    if engine.settings.isAlwaysBlockAdultSites {
                        HStack(spacing: 8) {
                            Label("TeraBox Estricto (Páginas y Buscadores)", systemImage: "bolt.shield.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "#E11D48").opacity(0.12))
                                .foregroundColor(Color(hex: "#E11D48"))
                                .cornerRadius(6)
                            
                            Label("Navegador DuckDuckGo Bloqueado", systemImage: "xmark.app.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(6)
                        }
                        .padding(.leading, 58)
                        .transition(.opacity)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("permanent.safesearch.title"))
                                .font(.headline)
                            Text(L10n.tr("permanent.safesearch.desc"))
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
                            Text(L10n.tr("permanent.incognito.title"))
                                .font(.headline)
                            Text(L10n.tr("permanent.incognito.desc"))
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
                    
                    Divider()
                    
                    // Escudo para WhatsApp (Estados & Canales)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#25D366").opacity(0.15))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "circle.dashed.inset.filled")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#25D366"))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Escudo para WhatsApp (Estados & Canales)")
                                    .font(.headline)
                                Text("Permite usar WhatsApp para chats de trabajo, pero bloquea las distracciones de contenido infinito.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Botón / Indicador de Estado
                            HStack(spacing: 6) {
                                Text(whatsAppActiveCount > 0 ? "\(whatsAppActiveCount) ACTIVAS" : "DESACTIVADO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(whatsAppActiveCount > 0 ? Color(hex: "#25D366") : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill((whatsAppActiveCount > 0 ? Color(hex: "#25D366") : Color.secondary).opacity(0.15)))
                                
                                Image(systemName: isWhatsAppShieldExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(hex: "#25D366"))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isWhatsAppShieldExpanded.toggle()
                            }
                        }
                        
                        // Sub-opciones de WhatsApp (Desplegables)
                        if isWhatsAppShieldExpanded {
                            VStack(spacing: 8) {
                                // 1. Bloqueo de Estados / Historias
                                HStack(spacing: 12) {
                                    Image(systemName: "circle.dashed")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "#25D366"))
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Bloquear Estados / Historias")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Cierra automáticamente el visor de historias para no perder el tiempo")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { engine.settings.isWhatsAppStatusBlockerEnabled },
                                        set: { engine.updateWhatsAppStatusBlocker(enabled: $0) }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                }
                                .padding(8)
                                .background(Color(hex: "#25D366").opacity(0.06))
                                .cornerRadius(8)
                                
                                // 2. Bloqueo de Canales / Novedades
                                HStack(spacing: 12) {
                                    Image(systemName: "megaphone.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "#0284C7"))
                                        .frame(width: 20)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Bloquear Canales / Novedades")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Cierra la pestaña de canales para evitar lecturas infinitas")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Toggle("", isOn: Binding(
                                        get: { engine.settings.isWhatsAppChannelsBlockerEnabled },
                                        set: { engine.updateWhatsAppChannelsBlocker(enabled: $0) }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                }
                                .padding(8)
                                .background(Color(hex: "#0284C7").opacity(0.06))
                                .cornerRadius(8)
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // 2. Sitios Web Bloqueados
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(isEn ? "Websites in Permanent Shield (\(engine.settings.permanentBlockedWebsites.count) added)" : "Sitios Web en Escudo Permanente (\(engine.settings.permanentBlockedWebsites.count) añadidos)", systemImage: "globe")
                            .font(.headline)
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                isAddingPermanentDomain.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isAddingPermanentDomain ? "chevron.up" : "plus")
                                Text(isAddingPermanentDomain ? L10n.tr("common.hide") : L10n.tr("webblock.btn.add"))
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#E11D48"))
                        .controlSize(.small)
                        
                        let allPermWebs = !engine.settings.permanentBlockedWebsites.isEmpty && engine.settings.permanentBlockedWebsites.count >= engine.settings.blockedWebsites.count
                        Button(action: {
                            engine.toggleAllPermanentWebsites(enabled: !allPermWebs)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allPermWebs ? "xmark.circle" : "checkmark.circle")
                                Text(allPermWebs ? L10n.tr("common.disableAll") : L10n.tr("common.enableAll"))
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Panel de Añadir Sitios (Colapsable)
                    if isAddingPermanentDomain {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("", selection: $addMode) {
                                Text(L10n.tr("webblock.add.single")).tag(0)
                                Text(L10n.tr("webblock.add.batch")).tag(1)
                            }
                            .pickerStyle(.segmented)
                            
                            if addMode == 0 {
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "globe")
                                            .foregroundColor(.secondary)
                                        TextField(L10n.tr("webblock.add.single.placeholder"), text: $singleDomain)
                                            .textFieldStyle(.plain)
                                            .onSubmit { addSinglePermanentDomain() }
                                    }
                                    .frame(height: 32)
                                    .padding(.horizontal, 10)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    
                                    Button(action: { addSinglePermanentDomain() }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text(L10n.tr("webblock.add.btn.block"))
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(height: 32)
                                        .padding(.horizontal, 12)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#E11D48"))
                                    .controlSize(.small)
                                    .disabled(singleDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(L10n.tr("webblock.add.batch.hint"))
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
                                                Text(L10n.tr("webblock.add.batch.btn"))
                                            }
                                            .font(.caption)
                                            .fontWeight(.bold)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color(hex: "#E11D48"))
                                        .controlSize(.small)
                                        .disabled(batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Buscador de Sitios del Escudo Permanente (Homogéneo 32px)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar sitio en el escudo permanente...", text: $permWebSearchText)
                            .textFieldStyle(.plain)
                        if !permWebSearchText.isEmpty {
                            Button(action: { permWebSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 32)
                    .padding(.horizontal, 10)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    
                    if displayedPermanentWebsites.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Text("No se encontraron sitios con \"\(permWebSearchText)\"")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button(action: {
                                    singleDomain = permWebSearchText
                                    addSinglePermanentDomain()
                                    permWebSearchText = ""
                                }) {
                                    Label("Añadir \"\(permWebSearchText)\" al Escudo", systemImage: "plus.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(displayedPermanentWebsites) { site in
                                permanentWebsiteRow(site: site)
                            }
                        }
                    }
                    
                    if permanentFilteredWebsites.count > 10 {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAllPermanentWebsites.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showAllPermanentWebsites ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                Text(showAllPermanentWebsites
                                     ? "Ver menos sitios"
                                     : "Ver más sitios (\(permanentFilteredWebsites.count - 10) adicionales)")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#E11D48"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#E11D48").opacity(0.08))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // 3. Aplicaciones de Mac Bloqueadas
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        let activeCount = permanentFilteredApps.filter { engine.settings.permanentBlockedApps.contains($0.bundleIdentifier) }.count
                        Label(isEn ? "Blocked Applications (\(activeCount) active)" : "Aplicaciones Bloqueadas (\(activeCount) activas)", systemImage: "app.badge.checkmark")
                            .font(.headline)
                        Spacer()
                        
                        Button(action: {
                            scanInstalledApps()
                            isShowingAppCatalogSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.app.fill")
                                Text(L10n.tr("appblock.btn.add"))
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#E11D48"))
                        .controlSize(.small)
                        
                        let allPermApps = !permanentFilteredApps.isEmpty && permanentFilteredApps.allSatisfy { engine.settings.permanentBlockedApps.contains($0.bundleIdentifier) }
                        Button(action: {
                            engine.toggleAllPermanentApps(enabled: !allPermApps)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allPermApps ? "xmark.circle" : "checkmark.circle")
                                Text(allPermApps ? L10n.tr("common.disableAll") : L10n.tr("common.enableAll"))
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    VStack(spacing: 6) {
                        ForEach(displayedPermanentApps) { app in
                            permanentAppRow(app: app)
                        }
                    }
                    
                    if permanentFilteredApps.count > 10 {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAllPermanentApps.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showAllPermanentApps ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                Text(showAllPermanentApps
                                     ? "Ver menos aplicaciones"
                                     : "Ver más aplicaciones (\(permanentFilteredApps.count - 10) adicionales)")
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#E11D48"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#E11D48").opacity(0.08))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingAppCatalogSheet) {
            appCatalogSheetContent
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
                
                Button(action: {
                    engine.removeBlockedWebsite(id: site.id)
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Eliminar este sitio del listado")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isPerm ? Color(hex: "#E11D48").opacity(0.08) : Color.secondary.opacity(0.04))
        .cornerRadius(8)
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
    
    private var appCatalogSheetContent: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Añadir Aplicación a Bloqueo Permanente")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Selecciona cualquier aplicación instalada en tu Mac para bloquearla continuamente.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cerrar") {
                    isShowingAppCatalogSheet = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Buscar app instalada en tu Mac...", text: $appSheetSearchText)
                    .textFieldStyle(.plain)
                if !appSheetSearchText.isEmpty {
                    Button(action: { appSheetSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(8)
            
            if isLoadingApps {
                Spacer()
                ProgressView("Escaneando aplicaciones instaladas...")
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredSheetApps) { app in
                            let isAlreadyPerm = engine.settings.permanentBlockedApps.contains(app.bundleIdentifier)
                            
                            HStack(spacing: 12) {
                                AppIconView(app: app, size: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.appName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(app.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isAlreadyPerm {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                        Text("Bloqueada")
                                    }
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#E11D48"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "#E11D48").opacity(0.12))
                                    .cornerRadius(6)
                                } else {
                                    Button(action: {
                                        engine.addBlockedApp(app: app)
                                        if !engine.settings.permanentBlockedApps.contains(app.bundleIdentifier) {
                                            engine.togglePermanentApp(bundleId: app.bundleIdentifier)
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("Bloquear")
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#E11D48"))
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isAlreadyPerm ? Color(hex: "#E11D48").opacity(0.06) : Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(width: 540, height: 480)
    }
    
    private func scanInstalledApps() {
        isLoadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppBlockerService.discoverInstalledApplications()
            DispatchQueue.main.async {
                self.discoveredApps = apps
                self.isLoadingApps = false
            }
        }
    }
    
    private func addSinglePermanentDomain() {
        let clean = singleDomain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .components(separatedBy: "/").first ?? ""
        
        guard !clean.isEmpty else { return }
        
        let name = FocusEngine.cleanDomainToName(clean)
        
        if !engine.settings.blockedWebsites.contains(where: { $0.domain.lowercased() == clean }) {
            let newSite = BlockedWebsite(domain: clean, name: name, category: .custom, isEnabled: true)
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
    @State private var dnsFamilyStatus = HostBlockerService.shared.isFamilyDNSActive()
    @State private var safariStatus = true
    @State private var notificationStatus = true
    @State private var testNotificationSent = false
    @State private var isShowingUninstallSheet = false
    @State private var uninstallPin = ""
    @State private var uninstallError: String? = nil
    @State private var backupMessage: String? = nil
    @State private var isBackupSuccess: Bool = true
    
    private var isAccessibilityActive: Bool {
        engine.isAccessibilityTrusted || AXIsProcessTrusted()
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape.2.fill")
                            .foregroundColor(.accentColor)
                        Text(L10n.tr("general.header.title"))
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    
                    Text(L10n.tr("general.header.subtitle"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // PANEL DE DIAGNÓSTICO DE PERMISOS DE macOS
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(L10n.tr("general.diag.title"), systemImage: "checkmark.seal.fill")
                            .font(.headline)
                        Spacer()
                    }
                    
                    VStack(spacing: 8) {
                        // 1. DNS Seguro Cloudflare Families (1.1.1.3)
                        permissionRow(
                            title: L10n.tr("general.diag.dns.title"),
                            subtitle: dnsFamilyStatus ? L10n.tr("general.diag.dns.active") : L10n.tr("general.diag.dns.inactive"),
                            icon: "shield.lefthalf.filled.badge.checkmark",
                            isActive: dnsFamilyStatus,
                            actionTitle: dnsFamilyStatus ? L10n.tr("common.verified") : L10n.tr("general.diag.connectDns")
                        ) {
                            HostBlockerService.shared.applyFamilyDNS()
                            dnsFamilyStatus = HostBlockerService.shared.isFamilyDNSActive()
                            if dnsFamilyStatus {
                                SoundService.shared.play("Hero")
                            }
                        }
                        
                        // 2. Permiso de Accesibilidad de macOS (WhatsApp & Incógnito)
                        permissionRow(
                            title: L10n.tr("general.diag.ax.title"),
                            subtitle: isAccessibilityActive ? L10n.tr("general.diag.ax.active") : L10n.tr("general.diag.ax.inactive"),
                            icon: "figure.walk.motion",
                            isActive: isAccessibilityActive,
                            actionTitle: isAccessibilityActive ? L10n.tr("common.verified") : L10n.tr("general.diag.openSettings")
                        ) {
                            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                            _ = AXIsProcessTrustedWithOptions(options)
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                            engine.refreshPermissions()
                        }
                        
                        // 3. Motor de Bloqueo de Red (Helper /etc/hosts)
                        permissionRow(
                            title: L10n.tr("general.diag.hosts.title"),
                            subtitle: helperStatus ? L10n.tr("general.diag.hosts.active") : L10n.tr("general.diag.hosts.inactive"),
                            icon: "network.badge.shield.half.filled",
                            isActive: helperStatus,
                            actionTitle: L10n.tr("general.diag.verifyReinstall")
                        ) {
                            try? HostBlockerService.shared.installHelper()
                            helperStatus = HostBlockerService.shared.isHelperInstalled
                        }
                        
                        // 4. Automatización de Safari & Navegadores
                        permissionRow(
                            title: L10n.tr("general.diag.safari.title"),
                            subtitle: L10n.tr("general.diag.safari.desc"),
                            icon: "safari.fill",
                            isActive: safariStatus,
                            actionTitle: L10n.tr("general.diag.testPermission")
                        ) {
                            testSafariAutomation()
                        }
                        
                        // 5. Notificaciones del Sistema
                        permissionRow(
                            title: L10n.tr("general.diag.notif.title"),
                            subtitle: testNotificationSent ? L10n.tr("general.diag.notif.sent") : L10n.tr("general.diag.notif.desc"),
                            icon: "bell.badge.fill",
                            isActive: true,
                            actionTitle: L10n.tr("general.diag.sendTest")
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
                        
                        // 6. Control de Procesos (Apps de Mac)
                        permissionRow(
                            title: L10n.tr("general.diag.apps.title"),
                            subtitle: L10n.tr("general.diag.apps.desc"),
                            icon: "app.badge.checkmark",
                            isActive: true,
                            actionTitle: L10n.tr("general.diag.verify")
                        ) {
                            NSSound(named: "Hero")?.play()
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // IDIOMA DE LA APLICACIÓN
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(L10n.tr("general.lang.title"), systemImage: "globe")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text(L10n.tr("general.lang.desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { engine.settings.appLanguage },
                        set: { engine.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text("\(lang.flag)  \(lang.displayName)").tag(lang)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // PREFERENCIAS DEL SISTEMA
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.tr("general.preferences.title"), systemImage: "slider.horizontal.3")
                        .font(.headline)
                    
                    Toggle(L10n.tr("general.pref.sounds"), isOn: $engine.settings.isSoundEnabled)
                        .onChange(of: engine.settings.isSoundEnabled) { _ in engine.saveSettings() }
                    
                    Toggle(L10n.tr("general.pref.launchAtLogin"), isOn: $engine.settings.launchAtLogin)
                        .onChange(of: engine.settings.launchAtLogin) { newValue in
                            engine.saveSettings()
                            LaunchAtLoginService.shared.updateLaunchAtLogin(enabled: newValue)
                        }
                    
                    Toggle(L10n.tr("general.pref.blockDevTools"), isOn: $engine.settings.isBlockDevToolsEnabled)
                        .onChange(of: engine.settings.isBlockDevToolsEnabled) { _ in engine.saveSettings() }
                    
                    Toggle(L10n.tr("general.pref.autoDND"), isOn: $engine.settings.isAutoDoNotDisturbEnabled)
                        .onChange(of: engine.settings.isAutoDoNotDisturbEnabled) { _ in engine.saveSettings() }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // COPIA DE SEGURIDAD & TRANSFERENCIA (IMPORTAR / EXPORTAR)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(L10n.tr("backup.title"), systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text(L10n.tr("backup.desc"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let msg = backupMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isBackupSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isBackupSuccess ? .green : .orange)
                            Text(msg)
                                .font(.caption)
                                .foregroundColor(isBackupSuccess ? .green : .orange)
                            Spacer()
                            Button(action: { backupMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(isBackupSuccess ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            engine.exportSettingsToFile { success, message in
                                isBackupSuccess = success
                                backupMessage = message
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text(L10n.tr("backup.btn.export"))
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#6366F1"))
                        
                        Button(action: {
                            engine.importSettingsFromFile { success, message in
                                isBackupSuccess = success
                                backupMessage = message
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text(L10n.tr("backup.btn.import"))
                            }
                            .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // PROTECCIÓN ANTI-DESINSTALACIÓN
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(L10n.tr("uninstall.title"), systemImage: "lock.shield.fill")
                            .font(.headline)
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isUninstallProtectionEnabled },
                            set: { engine.setUninstallProtection(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    
                    Text(L10n.tr("uninstall.desc"))
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
                                Text(L10n.tr("uninstall.btn"))
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
        .onAppear {
            engine.refreshPermissions()
            self.helperStatus = HostBlockerService.shared.isHelperInstalled
            self.dnsFamilyStatus = HostBlockerService.shared.isFamilyDNSActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            engine.refreshPermissions()
            self.helperStatus = HostBlockerService.shared.isHelperInstalled
            self.dnsFamilyStatus = HostBlockerService.shared.isFamilyDNSActive()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                engine.refreshPermissions()
                self.helperStatus = HostBlockerService.shared.isHelperInstalled
                self.dnsFamilyStatus = HostBlockerService.shared.isFamilyDNSActive()
            }
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
                    
                    Text(isActive ? L10n.tr("common.active") : (LocalizationService.shared.currentLanguage == .english ? "PENDING" : "PENDIENTE"))
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
