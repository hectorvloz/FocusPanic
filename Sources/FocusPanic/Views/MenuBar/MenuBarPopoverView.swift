import SwiftUI

public struct MenuBarPopoverView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var timerRotation: Double = 0
    
    public var body: some View {
        VStack(spacing: 14) {
            // MARK: - Cabecera Premium
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill((engine.sessionStatus == .active ? Color(hex: "#E11D48") : Color(hex: "#10B981")).opacity(0.25))
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(engine.sessionStatus == .active ? Color(hex: "#E11D48") : Color(hex: "#10B981"))
                        .frame(width: 8, height: 8)
                }
                
                Text(engine.sessionStatus == .active ? "Sesión Activa" : "FocusPanic")
                    .font(.system(size: 14, weight: .heavy))
                
                if engine.sessionStatus == .active {
                    Text(engine.settings.blockingMode == .whitelistOnly ? "TOTAL" : "SELECTIVO")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            engine.settings.blockingMode == .whitelistOnly
                                ? Color(hex: "#10B981").opacity(0.18)
                                : Color(hex: "#E11D48").opacity(0.18)
                        )
                        .foregroundColor(
                            engine.settings.blockingMode == .whitelistOnly
                                ? Color(hex: "#10B981")
                                : Color(hex: "#E11D48")
                        )
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button(action: { openAppDashboard() }) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Abrir Ventana Principal")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            
            Divider()
            
            // MARK: - Contenido: Temporizador Dinámico en Movimiento o Selector de Modos
            if engine.sessionStatus == .active {
                activeAnimatedTimerView
            } else {
                idleModeLauncherView
            }
            
            Divider()
            
            // MARK: - Barra Inferior con Ajustes Directos
            HStack {
                Button(action: { openAppSettings() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                        Text("Ajustes")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { openAppDashboard() }) {
                    Text("Abrir Dashboard")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.accentColor.opacity(0.12))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Menu {
                    Button("Ocultar este menú") {
                        closePopover()
                    }
                    
                    if engine.sessionStatus == .active {
                        Divider()
                        if engine.settings.isMasterPasswordEnabled {
                            Button("Desbloquear con Clave...") {
                                openAppEmergencyUnlock()
                            }
                        } else {
                            Button("Detener Modo Enfoque") {
                                engine.endSession(didCompleteNormally: false)
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: {
                        quitApplication()
                    }) {
                        Text("Cerrar FocusPanic (Salir)")
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: 310)
        .background(VisualEffectBackground())
    }
    
    // MARK: - Temporizador Animado en Movimiento
    private var activeAnimatedTimerView: some View {
        VStack(spacing: 16) {
            ZStack {
                // Anillo de fondo
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 9)
                    .frame(width: 130, height: 130)
                
                // Anillo de progreso dinámico
                Circle()
                    .trim(from: 0.0, to: CGFloat(engine.progress))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                engine.settings.blockingMode == .whitelistOnly ? Color(hex: "#10B981") : Color(red: 1.0, green: 0.25, blue: 0.4),
                                engine.settings.blockingMode == .whitelistOnly ? Color(hex: "#059669") : Color(red: 0.9, green: 0.1, blue: 0.3)
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                    .shadow(
                        color: (engine.settings.blockingMode == .whitelistOnly ? Color.green : Color.red).opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 0
                    )
                
                // Efecto de pulso / brillo continuo
                Circle()
                    .trim(from: 0, to: 0.15)
                    .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(timerRotation))
                    .frame(width: 130, height: 130)
                
                // Números del temporizador en tiempo real
                VStack(spacing: 2) {
                    Text(engine.formattedRemainingTime)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Text(engine.currentSession?.presetName ?? "Enfoque")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.top, 6)
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    timerRotation = 360
                }
            }
            
            // Botón de Desbloqueo / Detener según configuración
            Group {
                if engine.settings.isMasterPasswordEnabled {
                    Button(action: {
                        openAppEmergencyUnlock()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                                .font(.caption)
                            Text("Desbloquear con Clave")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.95, green: 0.25, blue: 0.35), Color(red: 0.85, green: 0.15, blue: 0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                        .shadow(color: Color.red.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: {
                        withAnimation {
                            engine.endSession(didCompleteNormally: false)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.circle.fill")
                                .font(.caption)
                            Text("Detener Sesión")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(Color(hex: "#F43F5E"))
                        .cornerRadius(8)
                        .shadow(color: Color.red.opacity(0.25), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 2)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Vista de Presets de Concentración (Sin Selector Redundante)
    private var idleModeLauncherView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Iniciar Sesión de Concentración:")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
            
            VStack(spacing: 6) {
                ForEach(FocusPreset.defaultPresets) { preset in
                    let isTotal = preset.name == "Bloqueo Total"
                    Button(action: {
                        engine.startFocusSession(durationMinutes: preset.durationMinutes, presetName: preset.name)
                        closePopover()
                    }) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: preset.colorHex).opacity(isTotal ? 0.25 : 0.15))
                                    .frame(width: 26, height: 26)
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: preset.colorHex))
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(preset.name)
                                    .font(.subheadline)
                                    .fontWeight(isTotal ? .bold : .medium)
                                    .foregroundColor(isTotal ? Color(hex: "#10B981") : .primary)
                                Text(preset.subtitle)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(preset.durationMinutes) min")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color(hex: preset.colorHex).opacity(0.12))
                                .cornerRadius(5)
                                .foregroundColor(Color(hex: preset.colorHex))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                        .background(isTotal ? Color(hex: "#10B981").opacity(0.08) : Color.secondary.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTotal ? Color(hex: "#10B981").opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
    }
    
    private func closePopover() {
        AppDelegate.shared?.closePopover()
    }
    
    private func openAppDashboard() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        AppDelegate.shared?.openMainWindow()
    }
    
    private func openAppSettings() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        AppDelegate.shared?.openMainWindow()
        engine.isSettingsPresented = true
    }
    
    private func openAppEmergencyUnlock() {
        closePopover()
        NSApp.activate(ignoringOtherApps: true)
        AppDelegate.shared?.openMainWindow()
        engine.initiateEmergencyUnlock()
    }
    
    private func quitApplication() {
        closePopover()
        if engine.settings.isMasterPasswordEnabled && !engine.settings.masterCompanionPassword.isEmpty {
            let alert = NSAlert()
            alert.messageText = "FocusPanic Protegido"
            alert.informativeText = "No está permitido cerrar FocusPanic para evitar burlar los bloqueos. Tu compañero debe autorizar el cierre con su PIN."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Ingresar Clave del Compañero")
            alert.addButton(withTitle: "Cancelar")
            let res = alert.runModal()
            if res == .alertFirstButtonReturn {
                openAppEmergencyUnlock()
            }
            return
        }
        
        if engine.sessionStatus == .active {
            let alert = NSAlert()
            alert.messageText = "¿Detener sesión y salir?"
            alert.informativeText = "Al salir de FocusPanic se desactivará el temporizador y se desbloquearán las distracciones."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Detener y Salir")
            alert.addButton(withTitle: "Seguir Enfocado")
            let res = alert.runModal()
            if res == .alertFirstButtonReturn {
                engine.endSession(didCompleteNormally: false)
                NSApplication.shared.terminate(nil)
            }
            return
        }
        NSApplication.shared.terminate(nil)
    }
}
