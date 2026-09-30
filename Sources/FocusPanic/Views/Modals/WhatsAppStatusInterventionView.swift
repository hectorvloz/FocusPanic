import SwiftUI
import AppKit

public enum WhatsAppBlockMode {
    case status
    case channels
    
    public var badgeTitle: String {
        switch self {
        case .status: return "ESTADOS DE WHATSAPP INTERCEPTADOS"
        case .channels: return "CANALES DE WHATSAPP INTERCEPTADOS"
        }
    }
    
    public var title: String {
        switch self {
        case .status: return "¡Pausa de Enfoque!"
        case .channels: return "¡Canales Bloqueados!"
        }
    }
    
    public var description: String {
        switch self {
        case .status:
            return "Los estados e historias de WhatsApp son una fuente de dopamina rápida que fragmenta tu concentración. FocusPanic protegió tu atención."
        case .channels:
            return "Los canales de difusión en WhatsApp están diseñados para atrapar tu tiempo con noticias y contenido infinito. FocusPanic detuvo la distracción."
        }
    }
    
    public var advice: String {
        switch self {
        case .status:
            return "Elige terminar tu tarea actual antes de consumir historias."
        case .channels:
            return "Mantén tu WhatsApp exclusivo para comunicación directa y productiva."
        }
    }
    
    public var buttonTitle: String {
        switch self {
        case .status: return "Cerrar Estados y Volver a Enfocarme"
        case .channels: return "Cerrar Canales y Volver a mis Chats"
        }
    }
}

public struct WhatsAppStatusInterventionView: View {
    public var mode: WhatsAppBlockMode
    public var onClose: () -> Void
    @State private var pulseGlow: Bool = false
    
    public init(mode: WhatsAppBlockMode = .status, onClose: @escaping () -> Void) {
        self.mode = mode
        self.onClose = onClose
    }
    
    public var body: some View {
        ZStack {
            // Fondo con efecto de cristal oscuro nativo macOS ultra pulido
            VisualEffectBackground(cornerRadius: 24)
            
            // Fondo glassmorphism oscuro
            Color(hex: "#0F111A").opacity(0.88)
            
            // Halo de luz de fondo
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(hex: "#F43F5E").opacity(pulseGlow ? 0.25 : 0.15),
                    Color(hex: "#25D366").opacity(0.1),
                    Color.clear
                ]),
                center: .top,
                startRadius: 20,
                endRadius: 260
            )
            
            VStack(spacing: 20) {
                // MARK: - Badge Superior Luminoso
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(hex: "#F43F5E"))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(hex: "#F43F5E"), radius: 4)
                    
                    Text(mode.badgeTitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#F43F5E"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(hex: "#F43F5E").opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(Color(hex: "#F43F5E").opacity(0.3), lineWidth: 1)
                        )
                )
                
                // MARK: - Icono Animado
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color(hex: "#F43F5E").opacity(0.3),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 45
                            )
                        )
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulseGlow ? 1.15 : 0.95)
                    
                    Circle()
                        .fill(Color(hex: "#1E1E2E"))
                        .frame(width: 68, height: 68)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "#F43F5E"), Color(hex: "#25D366")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 5)
                    
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Color(hex: "#F43F5E"))
                }
                
                // MARK: - Textos Principales
                VStack(spacing: 8) {
                    Text(mode.title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(mode.description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 10)
                }
                
                // MARK: - Consejo Motivacional
                HStack(spacing: 10) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#38BDF8"))
                    
                    Text(mode.advice)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#E0F2FE"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#0284C7").opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#38BDF8").opacity(0.25), lineWidth: 1)
                        )
                )
                
                // MARK: - Botones de Acción
                VStack(spacing: 10) {
                    Button(action: {
                        dismissAndCloseStatus()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 14, weight: .bold))
                            Text(mode.buttonTitle)
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E11D48"), Color(hex: "#BE123C")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(hex: "#E11D48").opacity(0.4), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    
                    Button(action: {
                        dismissAndCloseStatus()
                    }) {
                        Text("Volver a mis Chats")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.top, 4)
            }
            .padding(26)
        }
        .frame(width: 440, height: 420)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: "#F43F5E").opacity(0.5),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            NSSound(named: "Hero")?.play()
        }
    }
    
    private func dismissAndCloseStatus() {
        WhatsAppStatusWatcherService.shared.sendEscapeToWhatsApp()
        onClose()
    }
}
