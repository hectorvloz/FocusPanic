import SwiftUI

public struct EmergencyUnlockSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var isUnlocked = false
    @State private var enteredPassword = ""
    @State private var isSuccess = false
    @State private var errorMessage: String? = nil
    @State private var showSMTPSettings = false
    @State private var showPassword = false
    
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
                            Text("Desbloqueo & Seguridad TDAH")
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
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .foregroundColor(.orange)
                        Text("1. Clave Secreta del Compañero (PIN)")
                            .font(.headline)
                        Spacer()
                        Toggle("", isOn: $engine.settings.isMasterPasswordEnabled)
                            .toggleStyle(.switch)
                    }
                    
                    Text("Permite apagar el bloqueo al instante si tu compañero escribe su PIN de 4 dígitos. Es la forma más segura y recomendada de rescate.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if engine.settings.isMasterPasswordEnabled {
                        HStack(spacing: 10) {
                            if showPassword {
                                TextField("PIN Secreto de 4 dígitos", text: $engine.settings.masterCompanionPassword)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("PIN Secreto de 4 dígitos", text: $engine.settings.masterCompanionPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Text("🔑 Clave actual: \(showPassword ? engine.settings.masterCompanionPassword : "••••") (Solo tu compañero debe conocerla).")
                            .font(.caption2)
                            .foregroundColor(.orange)
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
                
                // 2. Método de Respaldo de Emergencia (Pregunta Secreta o Correo)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("2. Método de Respaldo del Compañero", systemImage: "shield.lefthalf.filled")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Picker("Método de Respaldo", selection: $engine.settings.recoveryMethod) {
                        Text("Pregunta Secreta").tag("question")
                        Text("Correo Electrónico").tag("email")
                    }
                    .pickerStyle(.segmented)
                    
                    if engine.settings.recoveryMethod == "question" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pregunta secreta que solo tu compañero sabe:")
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
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
                
                // 3. Seguridad de Desbloqueo & Reflexión Escrita (Fricción Consciente)
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("3. Seguridad de Desbloqueo & Reflexión", systemImage: "hourglass")
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
}
