import SwiftUI

public struct UpdateModalView: View {
    @ObservedObject var updater = UpdateManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#1D4ED8")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(hex: "#3B82F6").opacity(0.4), radius: 8, y: 4)
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Actualización de Software")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 8) {
                        Text("Versión actual: v\(updater.currentVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let release = updater.latestRelease {
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("Nueva: \(release.tagName)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    updater.isUpdateSheetPresented = false
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
            
            // Content Body based on state
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch updater.state {
                    case .checking:
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Buscando nuevas versiones en GitHub...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .upToDate(let version):
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#10B981").opacity(0.15))
                                    .frame(width: 60, height: 60)
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
                            
                            Text("¡FocusPanic está al día!")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("Tienes instalada la versión más reciente (v\(version)). Estás protegido contra las distracciones.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .updateAvailable(let release):
                        VStack(alignment: .leading, spacing: 14) {
                            // Badge destacada
                            HStack {
                                Label("Nueva versión disponible: \(release.name)", systemImage: "sparkles")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#2563EB"))
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(hex: "#3B82F6").opacity(0.12))
                            .cornerRadius(8)
                            
                            // Notas del release
                            Text("Novedades y Mejoras:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(release.body.isEmpty ? "Mejoras de rendimiento y optimizaciones en el motor de enfoque." : release.body)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 8)
                        
                    case .downloading(let progress):
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#3B82F6").opacity(0.12))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "#3B82F6"))
                            }
                            
                            Text("Descargando actualización...")
                                .font(.headline)
                            
                            VStack(spacing: 6) {
                                ProgressView(value: progress, total: 1.0)
                                    .progressViewStyle(.linear)
                                    .tint(Color(hex: "#3B82F6"))
                                
                                HStack {
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: "#3B82F6"))
                                    Spacer()
                                    if let size = updater.latestRelease?.dmgFileSize {
                                        Text("\(String(format: "%.1f", Double(size) / (1024 * 1024))) MB")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: 320)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .installing:
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Instalando nueva versión de FocusPanic...")
                                .font(.headline)
                            Text("Reemplazando aplicación en /Applications...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .readyToRestart:
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#10B981").opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "#10B981"))
                            }
                            
                            Text("¡Actualización instalada con éxito!")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("Reiniciando FocusPanic automáticamente en unos momentos...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .error(let message):
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.red)
                            }
                            
                            Text("No se pudo completar la actualización")
                                .font(.headline)
                            
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            Button("Reintentar") {
                                updater.checkForUpdates(isUserInitiated: true)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, minHeight: 220)
                        
                    case .idle:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 280)
            
            Divider()
            
            // Footer Action Buttons
            HStack(spacing: 12) {
                if let lastDate = updater.lastCheckDate {
                    Text("Última búsqueda: \(formattedDate(lastDate))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if case .updateAvailable = updater.state {
                    Button("Ver en GitHub") {
                        updater.openReleasePage()
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        updater.startDownloadAndInstall()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Actualizar e Instalar Ahora")
                        }
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#2563EB"))
                } else if case .upToDate = updater.state {
                    Button("Buscar de Nuevo") {
                        updater.checkForUpdates(isUserInitiated: true)
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Cerrar") {
                        updater.isUpdateSheetPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Cerrar") {
                        updater.isUpdateSheetPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.04))
        }
        .frame(width: 540)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
