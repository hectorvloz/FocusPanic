import SwiftUI

public struct MainDashboardView: View {
    @ObservedObject var engine = FocusEngine.shared
    @ObservedObject var statsManager = FocusStatsManager.shared
    @ObservedObject var l10n = LocalizationService.shared
    @ObservedObject var updater = UpdateManager.shared
    @State private var selectedPreset: FocusPreset? = FocusPreset.defaultPresets[1] // Pomodoro por defecto
    @State private var customDurationMinutes: Int = 25
    @State private var isShowingSettings = false
    @State private var isShowingStats = false
    @State private var isShowingIronStreak = false
    
    public var body: some View {
        ZStack {
            LinearGradient(
                colors: engine.sessionStatus == .active
                    ? [Color.black.opacity(0.9), Color(red: 0.08, green: 0.04, blue: 0.12)]
                    : [Color(NSColor.windowBackgroundColor), Color(NSColor.controlBackgroundColor)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerBar
                
                if updater.isBannerVisible, let release = updater.latestRelease {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#3B82F6"))
                        
                        Text("¡Nueva versión de FocusPanic \(release.tagName) disponible!")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Ver y Actualizar") {
                            updater.isUpdateSheetPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#2563EB"))
                        .controlSize(.small)
                        
                        Button(action: { updater.dismissUpdate() }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#3B82F6").opacity(0.12))
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#3B82F6").opacity(0.2)), alignment: .bottom)
                }
                
                Divider()
                
                if engine.sessionStatus == .active {
                    activeSessionContent
                } else {
                    idleDashboardContent
                }
            }
            
            // Notificación Flotante de Subida de Nivel / Insignia
            if let tier = statsManager.newlyUnlockedTier {
                VStack {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: tier.colorHex).opacity(0.25)).frame(width: 38, height: 38)
                            Image(systemName: tier.icon).font(.headline).foregroundColor(Color(hex: tier.colorHex))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¡SUBISTE DE NIVEL! 🎉")
                                .font(.caption2).fontWeight(.heavy).foregroundColor(Color(hex: tier.colorHex))
                            Text("Ahora eres Nivel \(tier.level): \(tier.title)")
                                .font(.subheadline).fontWeight(.bold).foregroundColor(.primary)
                        }
                        Spacer()
                        Button("Ver") {
                            statsManager.newlyUnlockedTier = nil
                            isShowingIronStreak = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: tier.colorHex))
                        .controlSize(.small)
                        
                        Button(action: { statsManager.newlyUnlockedTier = nil }) {
                            Image(systemName: "xmark").font(.caption).foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(VisualEffectBackground())
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: tier.colorHex).opacity(0.5), lineWidth: 1.5))
                    .shadow(color: Color(hex: tier.colorHex).opacity(0.3), radius: 12)
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .frame(minWidth: 740, minHeight: 580)
        .sheet(isPresented: $engine.isSettingsPresented) {
            SettingsContainerView()
        }
        .sheet(isPresented: $isShowingStats) {
            StatsDashboardView()
        }
        .sheet(isPresented: $isShowingIronStreak) {
            IronStreakView()
        }
        .sheet(isPresented: $engine.isEmergencyModalPresented) {
            EmergencyUnlockModalView()
        }
        .sheet(isPresented: $engine.isShowingOnboarding) {
            OnboardingWizardView()
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $updater.isUpdateSheetPresented) {
            UpdateModalView()
        }
    }
    
    // MARK: - Barra Superior
    private var headerBar: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color(red: 1.0, green: 0.18, blue: 0.33), Color(red: 0.66, green: 0.33, blue: 0.97)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 36, height: 36)
                        .shadow(color: Color(red: 1.0, green: 0.18, blue: 0.33).opacity(0.4), radius: 8, x: 0, y: 3)
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("FocusPanic")
                        .font(.headline)
                        .fontWeight(.heavy)
                    Text("Enfoque Radical para TDAH")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 14) {
                // Botón Interactivo de Racha de Hierro y Nivel
                Button(action: { isShowingIronStreak = true }) {
                    let tier = statsManager.currentTier
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "#FDE047"), Color(hex: tier.colorHex)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Text("\(statsManager.stats.currentStreakDays)d racha")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .foregroundColor(Color(hex: tier.colorHex))
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: tier.icon)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: tier.colorHex))
                        
                        Text("Niv. \(tier.level)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: tier.colorHex).opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: tier.colorHex).opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Ver Racha de Hierro, Nivel y Logros")
                
                let allowedCount = engine.settings.allowedWebsites.filter { $0.isEnabled }.count
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                    Text("\(allowedCount) permitidas")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#10B981").opacity(0.12))
                .cornerRadius(6)
                
                // Botón Dedicado de Estadísticas de Redes Sociales & Distracciones
                Button(action: { isShowingStats = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#6366F1"))
                        Text("Estadísticas")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#6366F1"))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: "#6366F1").opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#6366F1").opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .help("Ver Estadísticas de Uso, Redes Sociales e Impulsos Interceptados")
                
                let isEn = LocalizationService.shared.currentLanguage == .english
                
                // Botón Seguro de Reinicio Atómico de la App
                Button(action: { engine.relaunchApp() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isEn ? "Restart FocusPanic (Cleans memory & refreshes all blocking engines)" : "Reiniciar FocusPanic (Limpia memoria y reactiva todos los motores)")
                
                Button(action: { engine.isSettingsPresented = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isEn ? "Settings" : "Configuración")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(VisualEffectBackground())
    }
    
    // MARK: - Vista en Reposo
    private var idleDashboardContent: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("¿Sientes el impulso de procrastinar?")
                        .font(.system(size: 26, weight: .heavy))
                    Text("Presiona el Botón de Pánico. Bloquearemos todas tus distracciones al instante.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Selector de Presets
                VStack(spacing: 12) {
                    Text("Selecciona tu objetivo de concentración:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 10) {
                        ForEach(FocusPreset.defaultPresets) { preset in
                            presetCard(preset: preset)
                        }
                    }
                    .frame(maxWidth: 680)
                }
                            // Slider Manual con Audio Feedback Táctil
                HStack(spacing: 14) {
                    Text("O ajusta manualmente:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        if customDurationMinutes > 5 {
                            customDurationMinutes -= 5
                            selectedPreset = nil
                            playDialFeedback()
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(
                        value: Binding(
                            get: { Double(customDurationMinutes) },
                            set: { val in
                                let rounded = Int(val)
                                if rounded != customDurationMinutes {
                                    customDurationMinutes = rounded
                                    selectedPreset = nil
                                    playDialFeedback()
                                }
                            }
                        ),
                        in: 5...180,
                        step: 5
                    )
                    .frame(width: 200)
                    
                    Button(action: {
                        if customDurationMinutes < 180 {
                            customDurationMinutes += 5
                            selectedPreset = nil
                            playDialFeedback()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(customDurationMinutes) min")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(width: 65, alignment: .leading)
                }
                .padding(.vertical, 4)
                
                // El Gran Botón de Activación
                let isTotalBlock = selectedPreset?.name == "Bloqueo Total"
                VStack(spacing: 10) {
                    Button(action: {
                        let duration = selectedPreset?.durationMinutes ?? customDurationMinutes
                        let name = selectedPreset?.name ?? "Personalizado"
                        engine.startFocusSession(durationMinutes: duration, presetName: name)
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: isTotalBlock ? "lock.shield.fill" : "bolt.shield.fill")
                                .font(.system(size: 26, weight: .bold))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isTotalBlock ? "ACTIVAR BLOQUEO TOTAL" : "ACTIVAR MODO ENFOQUE")
                                    .font(.title3)
                                    .fontWeight(.heavy)
                                    .tracking(0.5)
                                let minutes = selectedPreset?.durationMinutes ?? customDurationMinutes
                                Text(isTotalBlock
                                     ? "Aislamiento radical por \(minutes) min (Solo Lista Blanca)"
                                     : "Bloqueando distracciones por \(minutes) min")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .opacity(0.9)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 40)
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                        .background(
                            isTotalBlock
                                ? LinearGradient(
                                    colors: [Color(hex: "#059669"), Color(hex: "#10B981")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color(red: 0.85, green: 0.15, blue: 0.45)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .shadow(
                            color: isTotalBlock
                                ? Color.green.opacity(0.35)
                                : Color.red.opacity(0.35),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Text("🔒 Desbloqueable de inmediato con la clave secreta de tu compañero.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 700)
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private func presetCard(preset: FocusPreset) -> some View {
        let isSelected = selectedPreset?.id == preset.id
        
        return Button(action: {
            if selectedPreset?.id != preset.id {
                selectedPreset = preset
                customDurationMinutes = preset.durationMinutes
                playDialFeedback()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .white : Color(hex: preset.colorHex))
                
                Text(preset.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Text("\(preset.durationMinutes) min")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
            }
            .frame(width: 120, height: 96)
            .contentShape(RoundedRectangle(cornerRadius: 14)) // <--- ÁREA DE CLIC COMPLETA
            .background(
                isSelected
                    ? AnyView(LinearGradient(colors: [Color(red: 0.95, green: 0.25, blue: 0.45), Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyView(Color.secondary.opacity(0.08))
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isSelected ? Color.pink.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Vista de Sesión Activa
    private var activeSessionContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 16)
                    .frame(width: 240, height: 240)
                
                Circle()
                    .trim(from: 0, to: CGFloat(engine.progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.orange, .red, .purple, .pink]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 240, height: 240)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: engine.progress)
                
                VStack(spacing: 6) {
                    Text(engine.formattedRemainingTime)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text(engine.currentSession?.presetName ?? "Modo Enfoque")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(1)
                }
            }
            
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Bloqueo Activo en Todos los Navegadores")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("Respira hondo y enfócate en una sola cosa a la vez.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Group {
                if engine.settings.isMasterPasswordEnabled {
                    Button(action: {
                        engine.initiateEmergencyUnlock()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                            Text("Desbloqueo con Clave del Compañero / Emergencia")
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        withAnimation {
                            engine.endSession(didCompleteNormally: false)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(Color(hex: "#F43F5E"))
                            Text("Detener Modo Enfoque")
                                .fontWeight(.semibold)
                        }
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 22)
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                        .background(Color(hex: "#F43F5E").opacity(0.25))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#F43F5E").opacity(0.4), lineWidth: 1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 24)
        }
    }
    
    private func playDialFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
    }
}
