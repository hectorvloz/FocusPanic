import SwiftUI

public struct EmergencyUnlockModalView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var isSuccess = false
    @State private var breathingPhase = false
    
    public var body: some View {
        VStack(spacing: 18) {
            // Cabecera
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "shield.lefthalf.filled.trianglebadge.exclamationmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Desbloqueo de Emergencia")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Cancelar la sesión activa antes de tiempo")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: {
                    engine.cancelEmergencyUnlock()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Selector de Método
            if engine.settings.isFrictionUnlockAllowed {
                HStack(spacing: 8) {
                    unlockModeTabButton(
                        mode: 1,
                        title: "Clave Compañero",
                        icon: "key.fill",
                        color: .orange
                    )
                    
                    unlockModeTabButton(
                        mode: 0,
                        title: "Espera & Reflexión",
                        icon: "hourglass",
                        color: .accentColor
                    )
                }
                .padding(4)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(10)
            }
            
            Divider()
            
            // Contenido según el modo
            if engine.unlockMode == 1 || !engine.settings.isFrictionUnlockAllowed {
                companionInstantUnlockView
            } else {
                frictionUnlockFlowView
            }
            
            // Mensajes de error o éxito
            if let error = engine.emergencyErrorMessage {
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
            
            if let success = engine.emergencySuccessMessage {
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
        }
        .padding(22)
        .frame(width: 500)
        .background(VisualEffectBackground())
        .cornerRadius(16)
        .shadow(radius: 20)
    }
    
    private func unlockModeTabButton(mode: Int, title: String, icon: String, color: Color) -> some View {
        let isSelected = engine.unlockMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                engine.unlockMode = mode
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? color.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? color : .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - MODO 1: Clave del Compañero (PIN Obligatorio)
    private var companionInstantUnlockView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Autorización del Compañero")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Tu compañero debe autorizar el desbloqueo ingresando su PIN.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(10)
            
            PasscodeKeypadView(
                pin: $engine.enteredMasterPassword,
                maxDigits: max(4, engine.settings.masterCompanionPassword.count),
                title: "",
                subtitle: "",
                tintColor: .orange,
                showKeypad: true,
                isSuccess: isSuccess,
                errorMessage: nil,
                onComplete: { _ in
                    verifyAndUnlock()
                }
            )
            
            HStack(spacing: 12) {
                Button("Cancelar") {
                    engine.cancelEmergencyUnlock()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: { verifyAndUnlock() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text("Desactivar Bloqueo")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(engine.enteredMasterPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private func verifyAndUnlock() {
        let clean = engine.enteredMasterPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let master = engine.settings.masterCompanionPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        if !master.isEmpty && clean == master {
            isSuccess = true
            NSSound(named: "Hero")?.play()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                engine.unlockInstantlyWithMasterPassword()
            }
        } else {
            NSSound(named: "Basso")?.play()
            engine.emergencyErrorMessage = "Clave incorrecta. Pídesela a tu compañero."
        }
    }
    
    // MARK: - MODO 0: Espera & Reflexión Escrita (Sin Correo)
    private var frictionUnlockFlowView: some View {
        VStack(spacing: 16) {
            // Stepper Visual
            HStack(spacing: 8) {
                stepperPill(step: 1, title: "1. Enfriamiento", icon: "timer")
                stepperConnector(step: 2)
                stepperPill(step: 2, title: "2. Reflexión Escrita", icon: "pencil.and.outline")
            }
            .padding(.horizontal, 10)
            
            Divider()
            
            if engine.emergencyStep == 1 {
                stepOneCooldownView
            } else {
                stepTwoLongReflectionView
            }
        }
    }
    
    private func stepperPill(step: Int, title: String, icon: String) -> some View {
        let isCurrent = engine.emergencyStep == step
        let isPast = engine.emergencyStep > step
        let color: Color = isCurrent ? .accentColor : (isPast ? .green : .secondary)
        
        return HStack(spacing: 5) {
            Image(systemName: isPast ? "checkmark.circle.fill" : icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.caption2)
                .fontWeight(isCurrent ? .bold : .medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(isCurrent ? 0.18 : (isPast ? 0.12 : 0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(isCurrent ? 0.5 : 0.15), lineWidth: 1)
        )
        .foregroundColor(color)
    }
    
    private func stepperConnector(step: Int) -> some View {
        Rectangle()
            .fill(engine.emergencyStep >= step ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Paso 1: Enfriamiento con Temporizador y Respiración
    private var stepOneCooldownView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 3) {
                Text("Tiempo de Espera de Seguridad")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Pausa el impulso de distracción. Al terminar el temporizador podrás escribir la reflexión.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(breathingPhase ? 0.2 : 0.05))
                    .frame(width: breathingPhase ? 140 : 115, height: breathingPhase ? 140 : 115)
                    .animation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true), value: breathingPhase)
                
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 115, height: 115)
                
                let progress = engine.settings.unlockDelayMinutes > 0 ? (1.0 - (engine.unlockDelayRemainingSeconds / Double(engine.settings.unlockDelayMinutes * 60))) : 1.0
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, progress))))
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 115, height: 115)
                
                VStack(spacing: 2) {
                    Text(engine.formattedDelayRemainingTime)
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    
                    Text("Respira...")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .onAppear {
                breathingPhase = true
                if engine.unlockDelayRemainingSeconds <= 0 {
                    engine.startFrictionCooldown()
                }
            }
            .padding(.vertical, 4)
            
            Button("Cancelar y Seguir Enfocado") {
                engine.cancelEmergencyUnlock()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - Paso 2: Reflexión Escrita de Compromiso Largo
    private var stepTwoLongReflectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 13))
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Paso 2: Compromiso de Reflexión")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Escribe el texto de compromiso completo para confirmar que no estás actuando por impulso.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Texto Requerido
            VStack(alignment: .leading, spacing: 4) {
                Text("Texto a escribir:")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("\"\(engine.settings.reflectionPhrase)\"")
                    .font(.caption)
                    .italic()
                    .foregroundColor(.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    )
            }
            
            // Campo de Escritura con Feedback en Tiempo Real
            VStack(alignment: .leading, spacing: 6) {
                TextField("Escribe aquí el texto exacto...", text: $engine.enteredReflectionText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                
                let match = isReflectionMatching
                HStack {
                    ProgressView(value: reflectionMatchProgress)
                        .progressViewStyle(.linear)
                        .tint(match ? .green : .accentColor)
                    
                    Text(match ? "¡Completado! ✓" : "\(Int(reflectionMatchProgress * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(match ? .green : .secondary)
                        .frame(width: 90, alignment: .trailing)
                }
            }
            
            HStack {
                Button("Cancelar") {
                    engine.cancelEmergencyUnlock()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    engine.submitFrictionReflection()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Desactivar Bloqueo y Reanudar")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(isReflectionMatching ? .green : .gray)
                .disabled(!isReflectionMatching)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }
    
    private var isReflectionMatching: Bool {
        let clean = engine.enteredReflectionText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = engine.settings.reflectionPhrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !clean.isEmpty && (clean == target || clean.count >= target.count)
    }
    
    private var reflectionMatchProgress: Double {
        let clean = engine.enteredReflectionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = engine.settings.reflectionPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return 0 }
        return min(1.0, Double(clean.count) / Double(target.count))
    }
}
