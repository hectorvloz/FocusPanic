import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var engine = FocusEngine.shared
    @ObservedObject var statsManager = FocusStatsManager.shared
    @ObservedObject var l10n = LocalizationService.shared
    @ObservedObject var updater = UpdateManager.shared
    @State private var hoveredPresetId: UUID? = nil
    
    public var body: some View {
        VStack(spacing: 10) {
            if engine.sessionStatus == .active {
                // MARK: - Estado Activo (Estilo Reproductor Nativo de Apple)
                activeNowPlayingCard
            } else {
                // MARK: - Estado Reposo (Estilo Centro de Control de Apple)
                idleControlCenterCard
            }
        }
        .padding(12)
        .frame(width: 360)
        .background(VisualEffectBackground(cornerRadius: 20))
    }
    
    // MARK: - Tarjeta Activa (100% estilo Apple Music / Now Playing)
    private var activeNowPlayingCard: some View {
        VStack(spacing: 12) {
            // Fila Principal con Carátula, Info y Controles
            HStack(spacing: 14) {
                // Carátula tipo Album Art
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#E11D48"), Color(hex: "#9F1239")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Color.black.opacity(0.3), radius: 4, y: 2)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Mini badge de modo
                    Circle()
                        .fill(engine.settings.blockingMode == .whitelistOnly ? Color(hex: "#10B981") : Color(hex: "#E11D48"))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1.5))
                        .offset(x: 2, y: 2)
                }
                .frame(width: 52, height: 52)
                
                // Título y Contador
                VStack(alignment: .leading, spacing: 3) {
                    Text(engine.currentSession?.presetName ?? "Sesión de Enfoque")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Text(engine.formattedRemainingTime)
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(hex: "#FB7185"))
                        
                        Text("• \(engine.settings.blockingMode == .whitelistOnly ? "Bloqueo Total" : "Selectivo")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Controles de Reproducción / Detención
                HStack(spacing: 8) {
                    if engine.settings.isMasterPasswordEnabled {
                        Button(action: { openAppEmergencyUnlock() }) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Desbloquear con Clave")
                    } else {
                        Button(action: {
                            withAnimation {
                                engine.endSession(didCompleteNormally: false)
                            }
                        }) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Detener Sesión")
                    }
                    
                    Button(action: { openAppDashboard() }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Abrir Dashboard")
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            
            // Barra de Progreso
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.white)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(engine.progress))), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text("\(Int(engine.progress * 100))% completado")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text("FocusPanic")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Tarjeta en Reposo (Estilo Centro de Control de macOS)
    private var idleControlCenterCard: some View {
        VStack(spacing: 10) {
            // Header del Widget
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#047857")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("FocusPanic")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    let tier = statsManager.currentTier
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color(hex: tier.colorHex))
                        Text("\(L10n.tr("popover.streak")) \(statsManager.stats.currentStreakDays) \(L10n.tr("dash.stats.days")) • \(L10n.tr("popover.level")) \(tier.level)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button(action: {
                        closePopover()
                        engine.relaunchApp()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help(LocalizationService.shared.currentLanguage == .english ? "Restart FocusPanic" : "Reiniciar FocusPanic")
                    
                    if updater.isBannerVisible {
                        Button(action: {
                            closePopover()
                            updater.isUpdateSheetPresented = true
                            openAppDashboard()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Update")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#2563EB"))
                            .cornerRadius(7)
                        }
                        .buttonStyle(.plain)
                        .help("Nueva versión de FocusPanic disponible")
                    }
                    
                    Button(action: { openAppDashboard() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "macwindow")
                                .font(.system(size: 10))
                            Text(L10n.tr("popover.dashboard"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(14)
            
            // Grid 2x2 de Presets (Diseño Apple Control Center)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(FocusPreset.defaultPresets.prefix(4)) { preset in
                    let isHovered = hoveredPresetId == preset.id
                    Button(action: {
                        engine.startFocusSession(durationMinutes: preset.durationMinutes, presetName: preset.name)
                        closePopover()
                    }) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: preset.colorHex).opacity(0.2))
                                    .frame(width: 28, height: 28)
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: preset.colorHex))
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.name)
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text("\(preset.durationMinutes) min")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(isHovered ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isHovered ? Color.white.opacity(0.25) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        hoveredPresetId = h ? preset.id : nil
                    }
                }
            }
            
            // Modo de Emergencia / Bloqueo Total
            if let totalPreset = FocusPreset.defaultPresets.first(where: { $0.name == "Bloqueo Total" }) {
                let isHovered = hoveredPresetId == totalPreset.id
                Button(action: {
                    engine.startFocusSession(durationMinutes: totalPreset.durationMinutes, presetName: totalPreset.name)
                    closePopover()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: totalPreset.iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: totalPreset.colorHex))
                        
                        Text(totalPreset.name)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Text("\(totalPreset.durationMinutes) min • Emergencia")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(hex: totalPreset.colorHex))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(isHovered ? Color(hex: "#10B981").opacity(0.2) : Color.white.opacity(0.05))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(hex: "#10B981").opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .onHover { h in
                    hoveredPresetId = h ? totalPreset.id : nil
                }
            }
        }
    }
    
    private func closePopover() {
        let delegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate)
        delegate?.closePopover()
    }
    
    private func openAppDashboard() {
        closePopover()
        let delegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate)
        delegate?.openMainWindow()
    }
    
    private func openAppSettings() {
        closePopover()
        let delegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate)
        delegate?.openMainWindow()
        engine.isSettingsPresented = true
    }
    
    private func openAppEmergencyUnlock() {
        closePopover()
        let delegate = AppDelegate.shared ?? (NSApp.delegate as? AppDelegate)
        delegate?.openMainWindow()
        engine.initiateEmergencyUnlock()
    }
}
