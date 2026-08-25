import SwiftUI

public struct StatsDashboardView: View {
    @ObservedObject var statsManager = FocusStatsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Fondo Degradado Deep Indigo con resplandor neón
            LinearGradient(
                colors: [Color(hex: "#0F111A"), Color(hex: "#1A1028"), Color(hex: "#090A10")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#F97316"), Color(hex: "#EF4444")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: "#F97316").opacity(0.5), radius: 10, x: 0, y: 3)
                        
                        Image(systemName: "flame.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Racha & Dopamina Positiva")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        
                        Text("Métricas de concentración y registro de impulsos salvados por FocusPanic")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 16)
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                ScrollView {
                    VStack(spacing: 22) {
                        // 1. Banner Principal de Racha de Fuego
                        streakHeroCard
                        
                        // 2. Grid de 4 Métricas Clave
                        metricsGrid
                        
                        // 3. Gráfico Semanal de Productividad
                        weeklyActivityCard
                        
                        // 4. Desglose de Distracciones Evitadas (Top Distractores)
                        topDistractionsCard
                        
                        // 5. Historial de Impulsos Interceptados Recientes
                        recentActivityLogCard
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                }
            }
            
            // Botón de Cerrar
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 22)
            .padding(.trailing, 26)
            .keyboardShortcut(.cancelAction)
        }
        .frame(minWidth: 780, minHeight: 620)
    }
    
    // MARK: - 1. Hero Card de Racha
    private var streakHeroCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#F97316").opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 90, height: 90)
                
                Circle()
                    .fill(Color(hex: "#F97316").opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#F97316").opacity(0.6), lineWidth: 2)
                    )
                
                Text("\(statsManager.stats.currentStreakDays)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#F97316"))
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("RACHA DE DISCIPLINA")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .tracking(1.2)
                        .foregroundColor(Color(hex: "#F97316"))
                    
                    if statsManager.stats.currentStreakDays >= 3 {
                        Text("🔥 IMPARABLE")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#F97316").opacity(0.2))
                            .foregroundColor(Color(hex: "#F97316"))
                            .cornerRadius(4)
                    }
                }
                
                Text(statsManager.stats.currentStreakDays == 1
                     ? "1 Día Enfocado Consecutivo"
                     : "\(statsManager.stats.currentStreakDays) Días Enfocados Consecutivos")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(statsManager.stats.currentStreakDays == 0
                     ? "Inicia tu primera sesión hoy para encender tu llama de disciplina."
                     : "Récord histórico: \(statsManager.stats.bestStreakDays) días. Tu cerebro está reforzando el circuito del enfoque.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            
            Spacer()
            
            // Medidor Circular de Meta Diaria
            let target = statsManager.stats.dailyTargetMinutes
            let todayMins = statsManager.todayFocusMinutes
            let progress = min(1.0, Double(todayMins) / Double(max(1, target)))
            
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 58, height: 58)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#10B981"), Color(hex: "#34D399")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 58, height: 58)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Meta Diaria")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            .padding(.trailing, 10)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1E2235").opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#F97316").opacity(0.3), lineWidth: 1.5)
                )
        )
    }
    
    // MARK: - 2. Grid de 4 Métricas Clave
    private var metricsGrid: some View {
        HStack(spacing: 14) {
            let totalHours = Double(statsManager.stats.totalFocusMinutesAllTime) / 60.0
            metricCard(
                icon: "timer",
                color: Color(hex: "#38BDF8"),
                value: String(format: "%.1f h", totalHours),
                title: "Tiempo Ganado",
                subtitle: "\(statsManager.stats.totalFocusMinutesAllTime) min totales"
            )
            
            metricCard(
                icon: "shield.lefthalf.filled.badge.checkmark",
                color: Color(hex: "#F43F5E"),
                value: "\(statsManager.todayInterceptionsCount)",
                title: "Impulsos Salvados Hoy",
                subtitle: "\(statsManager.stats.totalInterceptionsAllTime) históricos"
            )
            
            metricCard(
                icon: "checkmark.circle.fill",
                color: Color(hex: "#10B981"),
                value: "\(statsManager.todaySessionsCount)",
                title: "Sesiones Hoy",
                subtitle: "\(statsManager.todayFocusMinutes) min acumulados"
            )
            
            metricCard(
                icon: "trophy.fill",
                color: Color(hex: "#FBBF24"),
                value: "\(statsManager.stats.bestStreakDays) d",
                title: "Mejor Racha",
                subtitle: "Días seguidos"
            )
        }
    }
    
    private func metricCard(icon: String, color: Color, value: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#E2E8F0"))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#181B28").opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 3. Gráfico Semanal de Productividad
    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Actividad de Concentración (Últimos 7 Días)", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Minutos por día")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            
            let history = statsManager.last7DaysHistory()
            let maxMins = max(60, history.map { $0.minutes }.max() ?? 60)
            
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(history, id: \.dayLabel) { item in
                    VStack(spacing: 8) {
                        Text("\(item.minutes)m")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(item.minutes > 0 ? Color(hex: "#38BDF8") : Color(hex: "#64748B"))
                        
                        // Barra animada
                        let barHeight = max(8.0, CGFloat(item.minutes) / CGFloat(maxMins) * 110.0)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                item.isToday
                                    ? LinearGradient(
                                        colors: [Color(hex: "#F97316"), Color(hex: "#EF4444")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : (item.minutes > 0
                                       ? LinearGradient(
                                            colors: [Color(hex: "#38BDF8"), Color(hex: "#6366F1")],
                                            startPoint: .top,
                                            endPoint: .bottom
                                         )
                                       : LinearGradient(
                                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                         ))
                            )
                            .frame(height: barHeight)
                            .frame(maxWidth: .infinity)
                        
                        Text(item.dayLabel)
                            .font(.caption2)
                            .fontWeight(item.isToday ? .heavy : .medium)
                            .foregroundColor(item.isToday ? Color(hex: "#F97316") : Color(hex: "#94A3B8"))
                    }
                }
            }
            .frame(height: 160, alignment: .bottom)
            .padding(.top, 6)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#181B28").opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 4. Desglose de Distracciones Evitadas (Dopamina Positiva)
    private var topDistractionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Radar de Impulsos Evitados (Top Distractores)", systemImage: "hand.raised.slash.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(statsManager.todayInterceptionsCount) bloqueos hoy")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#F43F5E"))
            }
            
            let topList = statsManager.topDistractionsToday
            if topList.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("¡Cero intentos de distracción hoy! Tu mente ha estado en total control.")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                let maxCount = max(1, topList.first?.count ?? 1)
                VStack(spacing: 10) {
                    ForEach(topList.prefix(6), id: \.source) { item in
                        HStack(spacing: 12) {
                            Text(item.source)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 140, alignment: .leading)
                            
                            // Barra de Progreso
                            GeometryReader { geo in
                                let w = CGFloat(item.count) / CGFloat(maxCount) * geo.size.width
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 10)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [Color(hex: "#F43F5E"), Color(hex: "#A855F7")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: max(8, w), height: 10)
                                }
                            }
                            .frame(height: 10)
                            
                            Text("\(item.count) veces")
                                .font(.caption2)
                                .fontWeight(.heavy)
                                .foregroundColor(Color(hex: "#F43F5E"))
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#181B28").opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 5. Línea de Tiempo de Intercepciones Recientes
    private var recentActivityLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Registro en Vivo de Impulsos Interceptados", systemImage: "clock.arrow.circlepath")
                .font(.headline)
                .foregroundColor(.white)
            
            let recents = statsManager.stats.recentInterceptions
            if recents.isEmpty {
                Text("No hay intercepciones registradas aún.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(recents.prefix(5)) { item in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: "#F43F5E"))
                                .frame(width: 7, height: 7)
                            
                            Text(item.source)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text(timeAgo(date: item.timestamp))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#64748B"))
                        }
                        .padding(.vertical, 4)
                        
                        if item.id != recents.prefix(5).last?.id {
                            Divider().background(Color.white.opacity(0.05))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(hex: "#181B28").opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
    
    private func timeAgo(date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "hace \(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "hace \(minutes) min" }
        let hours = minutes / 60
        return "hace \(hours) h"
    }
}
