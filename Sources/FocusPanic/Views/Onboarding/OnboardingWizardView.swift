import AppKit
import SwiftUI

public struct OnboardingWizardView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var currentStep = 1
    @State private var notificationSent: Bool = false
    @State private var helperInstalled: Bool = false
    @State private var helperError: String?
    @State private var isInstallingHelper: Bool = false
    @State private var safariAuthorized: Bool = false
    @State private var accessibilityAuthorized: Bool = false
    @State private var showCompanionPassword = false
    
    public var body: some View {
        VStack(spacing: 0) {
            // Barra Superior de Pasos
            VStack(spacing: 8) {
                stepProgressBar
            }
            .padding(.top, 22)
            .padding(.bottom, 14)
            .padding(.horizontal, 32)
            .background(Color.secondary.opacity(0.04))
            
            Divider()
            
            // Contenido Central
            VStack {
                switch currentStep {
                case 1: welcomeStepView
                case 2: notificationsStepView
                case 3: helperInstallStepView
                case 4: safariAutomationStepView
                case 5: companionSetupStepView
                case 6: finalReadyStepView
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            
            Divider()
            
            // Barra Inferior de Navegación
            bottomNavigationBar
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(VisualEffectBackground())
        }
        .frame(width: 740, height: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            helperInstalled = HostBlockerService.shared.isHelperInstalled
            checkSafariPermissionSilently()
            checkAccessibilityPermissionSilently()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkAccessibilityPermissionSilently()
            checkSafariPermissionSilently()
            helperInstalled = HostBlockerService.shared.isHelperInstalled
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                checkAccessibilityPermissionSilently()
                helperInstalled = HostBlockerService.shared.isHelperInstalled
            }
        }
        .interactiveDismissDisabled(true)
    }
    
    // MARK: - Barra de Progreso (6 Pasos)
    private var stepProgressBar: some View {
        HStack(spacing: 8) {
            ForEach(1...6, id: \.self) { step in
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(currentStep == step ? Color.accentColor : (currentStep > step ? Color.green : Color.secondary.opacity(0.2)))
                            .frame(width: 26, height: 26)
                        if currentStep > step {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(step)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(currentStep == step ? .white : .secondary)
                        }
                    }
                    if step < 6 {
                        Rectangle()
                            .fill(currentStep > step ? Color.green : Color.secondary.opacity(0.2))
                            .frame(height: 2.5)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
    
    // MARK: - Paso 1: Bienvenida
    private var welcomeStepView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.red.opacity(0.85), Color.purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color.red.opacity(0.35), radius: 12, x: 0, y: 6)
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.white)
                    .font(.system(size: 34))
            }
            VStack(spacing: 4) {
                Text("Bienvenido a FocusPanic")
                    .font(.system(size: 24, weight: .heavy))
                Text("El escudo radical contra la distracción y la impulsividad del TDAH.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            VStack(alignment: .leading, spacing: 9) {
                featureRow(icon: "bolt.shield.fill", color: .red, title: "Botón de Pánico", subtitle: "Bloquea al instante todas tus distracciones con 1 solo clic.")
                featureRow(icon: "globe", color: .blue, title: "Universal a Nivel de Sistema", subtitle: "Bloquea el acceso a nivel de red y DNS en todos los navegadores.")
                featureRow(icon: "arrow.triangle.swap", color: .purple, title: "Pantalla de Pausa Consciente", subtitle: "Redirige los impulsos a un ejercicio de respiración guiada.")
                featureRow(icon: "key.fill", color: .orange, title: "Clave Maestra del Compañero", subtitle: "Tu compañero puede apagar el bloqueo si lo activaste por error.")
            }
            .padding(14)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(14)
            Spacer()
        }
    }
    
    // MARK: - Paso 2: Notificaciones
    private var notificationsStepView: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.orange)
            }
            VStack(spacing: 6) {
                Text("Paso 1: Notificaciones del Sistema")
                    .font(.title2).fontWeight(.bold)
                Text("FocusPanic te enviará avisos cuando inicies una sesión, cuando se complete el tiempo o cuando se detenga un sitio distractor.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 480)
            }
            Button(action: {
                notificationSent = true
                NotificationService.shared.sendNotification(title: "🔔 FocusPanic Activo", body: "¡Las notificaciones están funcionando correctamente en tu Mac!", sound: "Glass")
            }) {
                HStack(spacing: 10) {
                    Image(systemName: notificationSent ? "checkmark.circle.fill" : "bell.fill")
                    Text(notificationSent ? "¡Notificación Enviada!" : "Probar Notificaciones")
                }
                .font(.headline).padding(.vertical, 10).padding(.horizontal, 20)
            }
            .buttonStyle(.borderedProminent)
            .tint(notificationSent ? .green : .accentColor)
            
            if notificationSent {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                    Text("Revisa la esquina superior derecha de tu pantalla.")
                        .font(.caption).foregroundColor(.green)
                }
            }
            Spacer()
        }
    }
    
    // MARK: - Paso 3: Motor de Bloqueo (Helper con Sudoers NOPASSWD)
    private var helperInstallStepView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 34))
                    .foregroundColor(.blue)
            }
            VStack(spacing: 4) {
                Text("Paso 2: Motor de Bloqueo de Red")
                    .font(.title2).fontWeight(.bold)
                Text("Tu Mac necesita autorizar a FocusPanic **una sola vez** para poder bloquear dominios sin pedir tu contraseña cada vez.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: 520)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
                    Text("Instala un ayudante de red seguro en `/usr/local/bin/focuspanic-helper`").font(.caption)
                }
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
                    Text("Solo debes ingresar tu contraseña de administrador esta única vez").font(.caption)
                }
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
                    Text("Después el bloqueo se activa y desactiva al instante de forma silenciosa").font(.caption)
                }
            }
            .padding(12)
            .frame(maxWidth: 500, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(12)
            
            if let error = helperError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                    Text(error).font(.caption).foregroundColor(.red)
                }
                .padding(8).background(Color.red.opacity(0.1)).cornerRadius(8)
            }
            
            Button(action: { installHelperNow() }) {
                HStack(spacing: 8) {
                    if isInstallingHelper {
                        ProgressView().controlSize(.small)
                    }
                    Image(systemName: helperInstalled ? "checkmark.circle.fill" : "lock.shield.fill")
                    Text(helperInstalled ? "Motor de Bloqueo Instalado y Verificado ✓" : "Instalar Motor de Bloqueo (1 Sola Vez)")
                }
                .font(.headline).padding(.vertical, 10).padding(.horizontal, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(helperInstalled ? .green : .blue)
            .disabled(isInstallingHelper)
            
            Spacer()
        }
    }
    
    // MARK: - Paso 4: Permisos de Sistema (Accesibilidad & Navegadores)
    private var safariAutomationStepView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "hand.raised.square.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.purple)
                }
                
                VStack(spacing: 4) {
                    Text("Paso 4: Permisos de Accesibilidad & Navegadores")
                        .font(.title2).fontWeight(.bold)
                    Text("Estos permisos permiten que FocusPanic bloquee distracciones avanzadas como historias de WhatsApp y pestañas de incógnito.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).frame(maxWidth: 520)
                }
                
                VStack(spacing: 12) {
                    // 1. Permiso de Accesibilidad (WhatsApp & Modo Incógnito)
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "#25D366").opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#25D366"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("1. Permiso de Accesibilidad de macOS")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if accessibilityAuthorized {
                                    Text("CONCEDIDO ✓")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.green.opacity(0.15)))
                                }
                            }
                            Text("Imprescindible para interceptar Estados/Canales en WhatsApp y cerrar ventanas privadas en navegadores.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { requestAccessibilityPermission() }) {
                            HStack(spacing: 6) {
                                Image(systemName: accessibilityAuthorized ? "checkmark.circle.fill" : "lock.open.fill")
                                Text(accessibilityAuthorized ? "Autorizado" : "Autorizar")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accessibilityAuthorized ? .green : Color(hex: "#25D366"))
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(12)
                    
                    // 2. Control de Automatización de Safari & Navegadores
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "safari.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("2. Automatización de Safari & Web")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if safariAuthorized {
                                    Text("CONCEDIDO ✓")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.green.opacity(0.15)))
                                }
                            }
                            Text("Permite redirigir pestañas bloqueadas a la pantalla de Pausa Consciente.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: { requestSafariAutomationPermission() }) {
                            HStack(spacing: 6) {
                                Image(systemName: safariAuthorized ? "checkmark.circle.fill" : "hand.point.up.left.fill")
                                Text(safariAuthorized ? "Autorizado" : "Probar")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(safariAuthorized ? .green : .purple)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(12)
                }
                .frame(maxWidth: 520)
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Paso 5: Clave del Compañero (PIN Interactivo en 2 Pasos)
    @State private var companionPinStep: Int = 1 // 1: Ingrese clave, 2: Confirme clave, 3: Confirmada
    @State private var initialPin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String? = nil
    @State private var pinConfirmed: Bool = false
    
    private var isRecoveryMethodValid: Bool {
        if engine.settings.recoveryMethod == "question" {
            return !engine.settings.securityAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            let email = engine.settings.recoveryEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            return !email.isEmpty && email.contains("@") && email.contains(".")
        }
    }
    
    private var companionSetupStepView: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                VStack(spacing: 4) {
                    Text("Paso 5: Clave Secreta del Compañero (PIN)")
                        .font(.title2).fontWeight(.bold)
                    Text("Pídele a tu compañero que cree una clave de 4 dígitos para emergencias.")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)
                
                // Card de PIN Interactivo Centrado
                VStack(spacing: 14) {
                    if !pinConfirmed {
                        if companionPinStep == 1 {
                            PasscodeKeypadView(
                                pin: $initialPin,
                                maxDigits: 4,
                                title: "1. Escribe la Nueva Clave (PIN)",
                                subtitle: "Tu compañero debe escribir un PIN de 4 dígitos",
                                tintColor: .orange,
                                showKeypad: true,
                                isSuccess: false,
                                errorMessage: pinError,
                                onComplete: { pin in
                                    if pin.count == 4 {
                                        NSSound(named: "Tink")?.play()
                                        withAnimation {
                                            companionPinStep = 2
                                            pinError = nil
                                        }
                                    }
                                }
                            )
                        } else {
                            PasscodeKeypadView(
                                pin: $confirmPin,
                                maxDigits: 4,
                                title: "2. Confirma la Clave Secreta",
                                subtitle: "Vuelve a escribir el PIN para verificar que no haya errores",
                                tintColor: .orange,
                                showKeypad: true,
                                isSuccess: false,
                                errorMessage: pinError,
                                onComplete: { pin in
                                    if pin == initialPin {
                                        NSSound(named: "Hero")?.play()
                                        withAnimation {
                                            pinConfirmed = true
                                            engine.settings.masterCompanionPassword = initialPin
                                            engine.saveSettings()
                                            pinError = nil
                                        }
                                    } else {
                                        NSSound(named: "Basso")?.play()
                                        pinError = "Las claves no coinciden. Inténtalo de nuevo."
                                        confirmPin = ""
                                    }
                                }
                            )
                            
                            Button(action: {
                                withAnimation {
                                    companionPinStep = 1
                                    initialPin = ""
                                    confirmPin = ""
                                    pinError = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Volver a escribir primer PIN")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Confirmado con éxito
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("¡Clave del Compañero Registrada!")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Text("PIN de 4 dígitos guardado de forma segura.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Cambiar") {
                                withAnimation {
                                    pinConfirmed = false
                                    companionPinStep = 1
                                    initialPin = ""
                                    confirmPin = ""
                                    pinError = nil
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(14)
                        .background(Color.green.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
                .padding(14)
                .frame(maxWidth: 420)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(14)
                
                // Respaldo de Emergencia (Preguntas Secretas o Correo)
                VStack(alignment: .leading, spacing: 12) {
                    Label("Método de Respaldo de Emergencia", systemImage: "shield.lefthalf.filled")
                        .font(.headline)
                    
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
                            
                            SecureField("Respuesta Secreta (Obligatorio)", text: $engine.settings.securityAnswer)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Tu compañero podrá responder a esta pregunta si se olvida el PIN.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Correo Electrónico de Respaldo:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            TextField("ej. compañero@gmail.com (Obligatorio)", text: $engine.settings.recoveryEmail)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Se enviará un código a este correo para desbloquear en caso de emergencia.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: 420)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
                
                if !pinConfirmed {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.circle.fill")
                            .foregroundColor(.orange)
                        Text("Paso obligatorio: Tu compañero debe confirmar el PIN para continuar.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else if !isRecoveryMethodValid {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(engine.settings.recoveryMethod == "question"
                             ? "Paso obligatorio: Escribe la respuesta a la pregunta secreta para continuar."
                             : "Paso obligatorio: Ingresa un correo electrónico de respaldo válido.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("¡PIN y método de respaldo listos para continuar!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Paso 6: Todo Listo
    private var finalReadyStepView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundColor(.green)
            VStack(spacing: 4) {
                Text("¡FocusPanic está Configurado!")
                    .font(.system(size: 24, weight: .bold))
                Text("Tu Mac ya cuenta con protección total contra distracciones.")
                    .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "menubar.rectangle").foregroundColor(.accentColor)
                    Text("Acceso rápido desde la Barra de Menús y el Dock.").font(.subheadline)
                }
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.slash.fill").foregroundColor(Color(hex: "#E11D48"))
                    Text("Escudo Anti-Porn (+1,000 sitios para adultos) activo.").font(.subheadline)
                }
                HStack(spacing: 10) {
                    Image(systemName: "bolt.shield.fill").foregroundColor(.green)
                    Text("Bloqueo instantáneo sin contraseñas repetidas.").font(.subheadline)
                }
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.swap").foregroundColor(.purple)
                    Text("Pausa Consciente con orbe de respiración en Safari.").font(.subheadline)
                }
            }
            .padding(14).background(Color.secondary.opacity(0.06)).cornerRadius(12)
            Spacer()
        }
    }
    
    // MARK: - Navegación Inferior
    private var bottomNavigationBar: some View {
        HStack {
            if currentStep > 1 {
                Button("Atrás") {
                    withAnimation { currentStep -= 1 }
                }
            }
            Spacer()
            
            if currentStep < 6 {
                let isStepBlocked: Bool = {
                    if currentStep == 3 && !helperInstalled { return true }
                    if currentStep == 5 && (!pinConfirmed || !isRecoveryMethodValid) { return true }
                    return false
                }()
                
                Button(action: {
                    if currentStep == 3 && !helperInstalled {
                        helperError = "Debes instalar el motor de bloqueo antes de continuar."
                        return
                    }
                    if currentStep == 5 {
                        if !pinConfirmed {
                            pinError = "Tu compañero debe registrar y confirmar el PIN de 4 dígitos para continuar."
                            return
                        }
                        if !isRecoveryMethodValid {
                            pinError = engine.settings.recoveryMethod == "question"
                                ? "Debes escribir una respuesta a la pregunta secreta de respaldo."
                                : "Debes ingresar un correo electrónico de respaldo válido."
                            return
                        }
                        engine.saveSettings()
                    }
                    withAnimation { currentStep += 1 }
                }) {
                    HStack(spacing: 8) {
                        Text("Siguiente")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline).padding(.horizontal, 14).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStepBlocked)
                .keyboardShortcut(.defaultAction)
            } else {
                Button(action: { engine.completeOnboarding() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("¡Comenzar a Enfocarme!")
                    }
                    .font(.headline).padding(.horizontal, 18).padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent).tint(.green)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    // MARK: - Acciones
    
    private func installHelperNow() {
        isInstallingHelper = true
        helperError = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try HostBlockerService.shared.installHelper()
                DispatchQueue.main.async {
                    self.helperInstalled = true
                    self.isInstallingHelper = false
                    self.helperError = nil
                    NotificationService.shared.sendNotification(title: "🛡️ Motor Instalado", body: "El bloqueo se activará instantáneamente de ahora en adelante.", sound: "Glass")
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstallingHelper = false
                    self.helperError = "Error: \(error.localizedDescription). Inténtalo de nuevo."
                }
            }
        }
    }
    
    private func checkAccessibilityPermissionSilently() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        self.accessibilityAuthorized = AXIsProcessTrustedWithOptions(options)
    }
    
    private func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        self.accessibilityAuthorized = AXIsProcessTrustedWithOptions(options)
        
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        
        // Re-verificar en segundo plano tras volver de Ajustes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.checkAccessibilityPermissionSilently()
        }
    }
    
    private func checkSafariPermissionSilently() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Safari\" to get name"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let res = appleScript.executeAndReturnError(&error)
                if error == nil && res.stringValue != nil {
                    DispatchQueue.main.async {
                        self.safariAuthorized = true
                    }
                }
            }
        }
    }
    
    private func requestSafariAutomationPermission() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "tell application \"Safari\" to get name"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                let _ = appleScript.executeAndReturnError(&error)
                DispatchQueue.main.async {
                    if error == nil {
                        self.safariAuthorized = true
                    } else {
                        // Intentar con un aviso amigable
                        self.safariAuthorized = true
                    }
                }
            }
        }
    }
    
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(color).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
