import SwiftUI

public struct EmergencyUnlockSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var isUnlocked = false
    @State private var enteredPassword = ""
    @State private var isSuccess = false
    @State private var errorMessage: String? = nil
    @State private var showSMTPSettings = false
    @State private var showPassword = false
    
    // Estados para el cambio profesional de clave del compañero
    @State private var isChangingPassword = false
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showNewPassword = false
    @State private var changePasswordError: String? = nil
    @State private var changePasswordSuccess = false
    
    // Estados para la prueba de envío de correos
    @State private var testRecipientEmail = ""
    @State private var isSendingTestEmail = false
    @State private var testEmailSuccessMessage: String? = nil
    @State private var testEmailErrorMessage: String? = nil
    
    // Estados para el reporte semanal al compañero
    @State private var isSendingWeeklyReport = false
    @State private var weeklyReportSuccessMessage: String? = nil
    @State private var weeklyReportErrorMessage: String? = nil
    
    public var body: some View {
        if isUnlocked || !engine.settings.isMasterPasswordEnabled {
            unlockedContent
        } else {
            lockedAccessView
        }
    }
    
    // MARK: - Vista de Acceso Bloqueado con PIN del Compañero
    private var lockedAccessView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 76, height: 76)
                
                Image(systemName: isSuccess ? "lock.open.fill" : "key.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 4) {
                Text(isSuccess ? "¡Acceso Concedido!" : "Sección de Seguridad Protegida")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundColor(isSuccess ? .green : .primary)
                
                Text("Esta sección contiene la clave del compañero y los métodos de rescate. Pídele a tu compañero que ingrese su PIN para acceder.")
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
                tintColor: .orange,
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
            .tint(isSuccess ? .green : .orange)
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
            errorMessage = "Clave incorrecta. Pídesela a tu compañero."
        }
    }
    
    // MARK: - Contenido Desbloqueado
    private var unlockedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Cabecera con botón de volver a bloquear
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .foregroundColor(.orange)
                            Text("Ajustes de Desbloqueo")
                        }
                        .font(.title2)
                        .fontWeight(.bold)
                        
                        Text("Configuración de la clave maestra y opciones de rescate del compañero.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if engine.settings.isMasterPasswordEnabled {
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
                }
                
                Divider()
                
                // 1. Clave Secreta del Compañero (PIN de Rescate)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.orange)
                            Text("1. Clave Secreta del Compañero (PIN)")
                                .font(.headline)
                        }
                        Spacer()
                        Toggle("", isOn: $engine.settings.isMasterPasswordEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: engine.settings.isMasterPasswordEnabled) { _ in engine.saveSettings() }
                    }
                    
                    Text("Permite apagar el bloqueo al instante si tu compañero escribe su PIN de 4 dígitos. Es la forma más segura y recomendada de rescate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if engine.settings.isMasterPasswordEnabled {
                        VStack(spacing: 14) {
                            // Tarjeta de estado actual de la clave
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.12))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: "key.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PIN de Rescate Activo")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("Protegido con \(max(4, engine.settings.masterCompanionPassword.count)) dígitos • Solo tu compañero debe saberlo")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        isChangingPassword.toggle()
                                        changePasswordError = nil
                                        changePasswordSuccess = false
                                        newPassword = ""
                                        confirmPassword = ""
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isChangingPassword ? "xmark.circle" : "square.and.pencil")
                                        Text(isChangingPassword ? "Cerrar" : "Cambiar Clave")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.15))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            .cornerRadius(10)
                            
                            // Formulario profesional para cambiar la clave
                            if isChangingPassword {
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack {
                                        Image(systemName: "lock.rotation")
                                            .foregroundColor(.orange)
                                        Text("Establecer Nueva Clave del Compañero")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                    }
                                    
                                    Text("Pídele a tu compañero que escriba aquí el nuevo PIN que utilizará para desbloquearte.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    VStack(spacing: 10) {
                                        // Campo Nueva Clave
                                        HStack {
                                            if showNewPassword {
                                                TextField("Nueva clave (mín. 4 dígitos)", text: $newPassword)
                                                    .textFieldStyle(.roundedBorder)
                                            } else {
                                                SecureField("Nueva clave (mín. 4 dígitos)", text: $newPassword)
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            
                                            Button(action: { showNewPassword.toggle() }) {
                                                Image(systemName: showNewPassword ? "eye.slash" : "eye")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        // Campo Confirmar Clave
                                        HStack {
                                            if showNewPassword {
                                                TextField("Confirmar nueva clave", text: $confirmPassword)
                                                    .textFieldStyle(.roundedBorder)
                                            } else {
                                                SecureField("Confirmar nueva clave", text: $confirmPassword)
                                                    .textFieldStyle(.roundedBorder)
                                            }
                                            
                                            // Indicador de coincidencia
                                            if !confirmPassword.isEmpty {
                                                let isMatch = (newPassword == confirmPassword && newPassword.count >= 4)
                                                Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                                    .foregroundColor(isMatch ? .green : .red)
                                            }
                                        }
                                    }
                                    
                                    if let err = changePasswordError {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text(err)
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                    }
                                    
                                    if changePasswordSuccess {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.seal.fill")
                                            Text("¡Nueva clave guardada exitosamente!")
                                        }
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    }
                                    
                                    HStack {
                                        Spacer()
                                        
                                        Button(action: {
                                            withAnimation {
                                                isChangingPassword = false
                                                newPassword = ""
                                                confirmPassword = ""
                                                changePasswordError = nil
                                            }
                                        }) {
                                            Text("Cancelar")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.secondary)
                                        .padding(.trailing, 8)
                                        
                                        Button(action: { saveNewMasterPassword() }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "checkmark")
                                                Text("Guardar Nueva Clave")
                                            }
                                            .font(.caption.weight(.bold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        .disabled(newPassword.isEmpty || confirmPassword.isEmpty || changePasswordSuccess)
                                    }
                                }
                                .padding(14)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                        )
                )
                
                // 2. Método de Recuperación de PIN del Compañero (En caso de olvido)
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("2. Método de Recuperación de PIN", systemImage: "key.horizontal.fill")
                            .font(.headline)
                        Text("Se utiliza exclusivamente para restablecer el PIN del compañero si se olvida tras 3 intentos.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Método de Recuperación", selection: $engine.settings.recoveryMethod) {
                        Text("Pregunta Secreta").tag("question")
                        Text("Correo Electrónico").tag("email")
                    }
                    .pickerStyle(.segmented)
                    
                    if engine.settings.recoveryMethod == "question" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pregunta de seguridad para restablecer el PIN:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Picker("", selection: $engine.settings.securityQuestion) {
                                Text("¿Cuál fue el nombre de tu primera mascota?").tag("¿Cuál fue el nombre de tu primera mascota?")
                                Text("¿Nombre de tu escuela primaria?").tag("¿Nombre de tu escuela primaria?")
                                Text("¿Ciudad donde se conocieron tú y tu compañero?").tag("¿Ciudad donde se conocieron tú y tu compañero?")
                                Text("¿Película o libro favorito de tu compañero?").tag("¿Película o libro favorito de tu compañero?")
                                Text("¿Cuál es tu comida favorita de la infancia?").tag("¿Cuál es tu comida favorita de la infancia?")
                            }
                            .pickerStyle(.menu)
                            
                            SecureField("Respuesta Secreta del Compañero", text: $engine.settings.securityAnswer)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Correo Electrónico de Respaldo:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            TextField("ej. compañero@gmail.com", text: $engine.settings.recoveryEmail)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: engine.settings.recoveryEmail) { newEmail in
                                    engine.settings.partnerEmail = newEmail
                                    engine.saveSettings()
                                }
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
                
                // 3. Reporte Semanal al Compañero de Responsabilidad (Accountability)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("3. Reportes Semanales al Compañero", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.headline)
                            .foregroundColor(.purple)
                        Spacer()
                        
                        Toggle("", isOn: $engine.settings.isWeeklyReportEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                            .onChange(of: engine.settings.isWeeklyReportEnabled) { _ in engine.saveSettings() }
                    }
                    
                    Text("Envía un informe automático con diseño visual a tu compañero cada semana con tus horas enfocadas, racha e impulsos bloqueados para mantener el compromiso.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.caption2)
                                .foregroundColor(.purple)
                            if !engine.settings.officialPartnerEmail.isEmpty {
                                Text("Destinatario oficial: \(engine.settings.officialPartnerEmail)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            } else {
                                Text("Configura el correo en el Paso 2 superior")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { runSendWeeklyReport() }) {
                            HStack(spacing: 6) {
                                if isSendingWeeklyReport {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "paperplane.circle.fill")
                                }
                                Text(isSendingWeeklyReport ? "Enviando..." : "Enviar Reporte Ahora")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(isSendingWeeklyReport || engine.settings.officialPartnerEmail.isEmpty)
                    }
                    .padding(.top, 2)
                    
                    if let success = weeklyReportSuccessMessage {
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
                    
                    if let error = weeklyReportErrorMessage {
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
                }
                .padding(16)
                .background(Color.purple.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.25), lineWidth: 1)
                )
                
                // 4. Alertas Inteligentes de Rendición de Cuentas (Accountability)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("4. Alertas Inteligentes al Compañero", systemImage: "bell.badge.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    
                    Text("FocusPanic enviará alertas automáticas e instantáneas a tu compañero en situaciones clave.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        // 1. Palabras prohibidas
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "text.magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Búsqueda de Palabras Prohibidas")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Notifica si intentas buscar un término bloqueado e incluye la palabra.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertKeywordsEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertKeywordsEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                        
                        Divider().opacity(0.35)
                        
                        // 2. Desinstalación / Forzar cierre
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "shield.slash.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Intentos de Desinstalación o Forzar Cierre")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Notifica si intentas borrar la app o forzar cierre sin el PIN.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertUninstallEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertUninstallEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                        
                        Divider().opacity(0.35)
                        
                        // 3. Cancelación anticipada de sesión
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.indigo.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "lock.open.trianglebadge.exclamationmark.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.indigo)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Cancelación Anticipada de Sesión")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Notifica si cancelas una sesión de enfoque y envía tu texto de reflexión.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertEmergencyUnlockEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertEmergencyUnlockEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                        
                        Divider().opacity(0.35)
                        
                        // 4. Modo incógnito repetido
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Intentos Repetidos de Modo Incógnito")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Notifica si abres 3+ ventanas privadas en menos de 5 minutos.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertIncognitoEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertIncognitoEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                        
                        Divider().opacity(0.35)
                        
                        // 5. Logros de Racha y Rango
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.yellow.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.yellow)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Celebración de Ascensos y Récords de Racha")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Invita a tu compañero a felicitarte cuando subes de rango o superas racha.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertAchievementsEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertAchievementsEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                        
                        Divider().opacity(0.35)
                        
                        // 6. Límite de Redes Sociales
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "hourglass.bottomhalf.filled")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Límite Diario de Tiempo en Redes Superado")
                                    .font(.system(size: 12.5, weight: .semibold))
                                Text("Notifica si agotas el tiempo diario configurado en Instagram, TikTok, etc.")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer(minLength: 8)
                            Toggle("", isOn: $engine.settings.isPartnerAlertSocialLimitEnabled)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .labelsHidden()
                                .onChange(of: engine.settings.isPartnerAlertSocialLimitEnabled) { _ in engine.saveSettings() }
                        }
                        .padding(.vertical, 3)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.04))
                    .cornerRadius(10)
                }
                .padding(16)
                .background(Color.orange.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                )
                
                // 5. Zona de Prueba de Envío de Correos
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("5. Zona de Prueba de Envío de Correos", systemImage: "paperplane.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    
                    Text("Verifica que el servicio de correo electrónico esté activo y enviando mensajes en tiempo real.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        TextField("Ingresa correo para recibir prueba...", text: $testRecipientEmail)
                            .textFieldStyle(.roundedBorder)
                            .onAppear {
                                if testRecipientEmail.isEmpty {
                                    if !engine.settings.recoveryEmail.isEmpty {
                                        testRecipientEmail = engine.settings.recoveryEmail
                                    } else if !engine.settings.partnerEmail.isEmpty {
                                        testRecipientEmail = engine.settings.partnerEmail
                                    }
                                }
                            }
                        
                        Button(action: { runTestEmailSend() }) {
                            HStack(spacing: 6) {
                                if isSendingTestEmail {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(isSendingTestEmail ? "Enviando..." : "Enviar Correo de Prueba")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(isSendingTestEmail || testRecipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    if let success = testEmailSuccessMessage {
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
                    
                    if let error = testEmailErrorMessage {
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
                }
                .padding(16)
                .background(Color.blue.opacity(0.06))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                )
                
                // 5. Seguridad de Desbloqueo & Reflexión Escrita (Fricción Consciente)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("5. Seguridad de Desbloqueo & Reflexión", systemImage: "hourglass")
                            .font(.headline)
                        Spacer()
                        
                        Toggle("", isOn: $engine.settings.isFrictionUnlockAllowed)
                            .toggleStyle(.switch)
                            .onChange(of: engine.settings.isFrictionUnlockAllowed) { _ in engine.saveSettings() }
                    }
                    
                    Text("Permite cancelar la sesión sin depender de tu compañero, exigiendo un tiempo de enfriamiento consciente y escribir un texto de compromiso.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if engine.settings.isFrictionUnlockAllowed {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Tiempo de Espera de Seguridad (Enfriamiento):")
                                    .font(.subheadline)
                                Spacer()
                                Stepper("\(engine.settings.unlockDelayMinutes) min", value: $engine.settings.unlockDelayMinutes, in: 1...30)
                                    .onChange(of: engine.settings.unlockDelayMinutes) { _ in engine.saveSettings() }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Texto Largo de Compromiso a Escribir:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                TextEditor(text: $engine.settings.reflectionPhrase)
                                    .font(.system(size: 13, design: .monospaced))
                                    .frame(height: 60)
                                    .padding(6)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                    )
                                    .onChange(of: engine.settings.reflectionPhrase) { _ in engine.saveSettings() }
                                
                                Text("El usuario deberá esperar el tiempo de seguridad y escribir este texto completo para poder cancelar la sesión.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.04))
                        .cornerRadius(8)
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
    
    private func runSendWeeklyReport() {
        let dest = engine.settings.partnerEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dest.isEmpty else {
            weeklyReportErrorMessage = "Por favor ingresa primero el correo de tu compañero."
            return
        }
        
        isSendingWeeklyReport = true
        weeklyReportSuccessMessage = nil
        weeklyReportErrorMessage = nil
        
        EmailService.shared.sendWeeklyPartnerReport(
            toEmail: dest,
            stats: FocusStatsManager.shared.stats,
            statsManager: FocusStatsManager.shared
        ) { result in
            isSendingWeeklyReport = false
            switch result {
            case .success:
                weeklyReportSuccessMessage = "¡Reporte semanal de rendimiento enviado exitosamente a \(dest)!"
                SoundService.shared.play("Hero")
            case .failure(let err):
                weeklyReportErrorMessage = "Error al enviar: \(err.localizedDescription)"
                SoundService.shared.play("Basso")
            }
        }
    }
    
    private func runTestEmailSend() {
        let dest = testRecipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dest.isEmpty else { return }
        
        isSendingTestEmail = true
        testEmailSuccessMessage = nil
        testEmailErrorMessage = nil
        
        EmailService.shared.sendTestEmail(toEmail: dest) { result in
            isSendingTestEmail = false
            switch result {
            case .success:
                testEmailSuccessMessage = "¡Correo de prueba enviado con éxito a \(dest)! Revisa tu bandeja de entrada o spam."
                SoundService.shared.play("Hero")
            case .failure(let err):
                testEmailErrorMessage = "Error al enviar: \(err.localizedDescription)"
                SoundService.shared.play("Basso")
            }
        }
    }
    
    private func saveNewMasterPassword() {
        let cleanNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanNew.count >= 4 else {
            changePasswordError = "La clave debe tener al menos 4 dígitos o caracteres."
            NSSound(named: "Basso")?.play()
            return
        }
        
        guard cleanNew == cleanConfirm else {
            changePasswordError = "Las claves no coinciden. Verifícalas."
            NSSound(named: "Basso")?.play()
            return
        }
        
        engine.settings.masterCompanionPassword = cleanNew
        engine.settings.isMasterPasswordEnabled = true
        engine.saveSettings()
        
        changePasswordError = nil
        changePasswordSuccess = true
        NSSound(named: "Hero")?.play()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring()) {
                isChangingPassword = false
                newPassword = ""
                confirmPassword = ""
                changePasswordSuccess = false
            }
        }
    }
}
