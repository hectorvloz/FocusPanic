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
                // Header Bar de Bienestar Digital
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#8B5CF6")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 40, height: 40)
                            .shadow(color: Color(hex: "#3B82F6").opacity(0.5), radius: 10, x: 0, y: 3)
                        
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bienestar Digital & Estadísticas")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                        
                        Text("Monitoreo en tiempo real de tiempo en redes sociales, apps y páginas interceptadas")
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
                        // 1. Gráfica de Dona Estilo Bienestar Digital de Android
                        digitalWellbeingDonutCard
                        
                        // 2. Grid de 4 Métricas Clave de Tiempo y Pantalla
                        metricsGrid
                        
                        // 3. Monitor Detallado de Tiempo & Visitas en Redes Sociales 24/7
                        socialScreenTimeCard
                        
                        // 4. Gráfico Semanal de Productividad
                        weeklyActivityCard
                        
                        // 5. Desglose de Distracciones Evitadas (Top Distractores)
                        topDistractionsCard
                        
                        // 6. Historial de Impulsos Interceptados Recientes
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
        .frame(minWidth: 780, minHeight: 640)
    }
    
    // MARK: - 1. Gráfica de Dona Estilo Bienestar Digital (Android Style - Centrada)
    private var digitalWellbeingDonutCard: some View {
        let socialList = statsManager.todaySocialUsageList
        let totalSeconds = statsManager.totalSocialTimeTodayMinutes * 60 + socialList.reduce(0) { $0 + ($1.seconds % 60) }
        let totalTimeDisplay = formatTotalTime(totalSeconds)
        
        return VStack(spacing: 24) {
            // Cabecera de la Tarjeta
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "circle.circle.fill")
                        .foregroundColor(Color(hex: "#3B82F6"))
                        .font(.headline)
                    Text("Bienestar Digital • Tiempo en Redes Sociales")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                Spacer()
                Text("Monitoreo 24/7")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#3B82F6").opacity(0.2))
                    .foregroundColor(Color(hex: "#60A5FA"))
                    .cornerRadius(6)
            }
            
            // DONUT CHART CENTRADO (ESTILO GOOGLE ANDROID)
            ZStack {
                if socialList.isEmpty || totalSeconds == 0 {
                    // Anillo vacío limpio
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 22)
                        .frame(width: 210, height: 210)
                } else {
                    // Fondo base del anillo
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 22)
                        .frame(width: 210, height: 210)
                    
                    // Segmentos de color con separación estilo Android
                    donutSegmentsView(items: socialList, totalSeconds: totalSeconds)
                        .frame(width: 210, height: 210)
                }
                
                // Texto Central de Tiempo
                VStack(spacing: 4) {
                    Text("HOY")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#94A3B8"))
                        .tracking(1.5)
                    
                    Text(totalTimeDisplay)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if totalSeconds > 0 {
                        Text("\(statsManager.totalSocialVisitsToday) \(statsManager.totalSocialVisitsToday == 1 ? "visita" : "visitas")")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#A855F7"))
                    } else {
                        Text("¡Día limpio!")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                    }
                }
            }
            .frame(width: 240, height: 240)
            .padding(.vertical, 4)
            
            // LEYENDA CENTRADA (CHIPS DE APLICACIONES CON COLORES)
            if socialList.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                    Text("0 minutos en redes sociales hoy. ¡Excelente control de atención!")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
                .padding(.vertical, 4)
            } else {
                // Fila de Chips Centrados
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 10)], spacing: 10) {
                    ForEach(socialList, id: \.source) { item in
                        let fraction = Double(item.seconds) / Double(max(1, totalSeconds))
                        let percentage = Int(round(fraction * 100))
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(socialColor(for: item.source))
                                .frame(width: 10, height: 10)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.source)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 4) {
                                    Text(formatSeconds(item.seconds))
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(socialColor(for: item.source))
                                    
                                    Text("(\(percentage)%)")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                }
                            }
                            
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(socialColor(for: item.source).opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .frame(maxWidth: 580)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "#181B28").opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(hex: "#3B82F6").opacity(0.3), lineWidth: 1.5)
                )
        )
    }
    
    private struct DonutSlice: Identifiable {
        let id = UUID()
        let source: String
        let color: Color
        let start: Double
        let end: Double
    }
    
    private func donutSegmentsView(items: [(source: String, visits: Int, minutes: Int, seconds: Int)], totalSeconds: Int) -> some View {
        let validItems = items.filter { $0.seconds > 0 }
        
        var slices: [DonutSlice] = []
        var accum: Double = 0.0
        
        if totalSeconds > 0 && !validItems.isEmpty {
            for item in validItems {
                let fraction = Double(item.seconds) / Double(totalSeconds)
                let start = accum
                let end = accum + fraction
                slices.append(DonutSlice(source: item.source, color: socialColor(for: item.source), start: start, end: end))
                accum = end
            }
        }
        
        return ZStack {
            // Anillo base sutil de fondo
            Circle()
                .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 22, lineCap: .round))
            
            // Segmentos continuos y limpios sin cortes negros
            ForEach(slices) { slice in
                Circle()
                    .trim(from: CGFloat(slice.start), to: CGFloat(slice.end))
                    .stroke(slice.color, style: StrokeStyle(lineWidth: 22, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
    }
    
    private func formatTotalTime(_ secs: Int) -> String {
        if secs == 0 { return "0 min" }
        if secs < 60 { return "\(secs) seg" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let remMins = mins % 60
        return remMins == 0 ? "\(hours) h" : "\(hours)h \(remMins)m"
    }
    
    // MARK: - 2. Grid de 4 Métricas Clave
    private var metricsGrid: some View {
        HStack(spacing: 14) {
            let socialMins = statsManager.totalSocialTimeTodayMinutes
            let socialTimeFormatted = socialMins >= 60 ? "\(socialMins / 60)h \(socialMins % 60)m" : "\(socialMins) min"
            metricCard(
                icon: "hourglass.badge.eye",
                color: Color(hex: "#3B82F6"),
                value: socialTimeFormatted,
                title: "Tiempo en Redes Hoy",
                subtitle: "\(statsManager.totalSocialVisitsToday) visitas registradas"
            )
            
            metricCard(
                icon: "eye.fill",
                color: Color(hex: "#A855F7"),
                value: "\(statsManager.totalSocialVisitsToday)",
                title: "Aperturas de Apps",
                subtitle: "Visitas pasivas 24/7"
            )
            
            metricCard(
                icon: "shield.lefthalf.filled.badge.checkmark",
                color: Color(hex: "#F43F5E"),
                value: "\(statsManager.todayInterceptionsCount)",
                title: "Impulsos Evitados",
                subtitle: "\(statsManager.stats.totalInterceptionsAllTime) bloqueos totales"
            )
            
            let focusMins = statsManager.todayFocusMinutes
            let focusFormatted = focusMins >= 60 ? String(format: "%.1f h", Double(focusMins) / 60.0) : "\(focusMins) min"
            metricCard(
                icon: "timer",
                color: Color(hex: "#10B981"),
                value: focusFormatted,
                title: "Tiempo Enfocado",
                subtitle: "Sesiones de hoy"
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
                .font(.system(size: 22, weight: .heavy, design: .rounded))
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
    
    // MARK: - 3. Monitor de Tiempo & Visitas en Redes Sociales 24/7
    private var socialScreenTimeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(Color(hex: "#A855F7"))
                    Text("Tiempo & Visitas en Redes Sociales (Monitoreo 24/7)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Tiempo real invertido hoy")
                    .font(.caption2)
                    .foregroundColor(Color(hex: "#94A3B8"))
            }
            
            let socialList = statsManager.todaySocialUsageList
            if socialList.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("No has entrado a redes sociales hoy. ¡Excelente control de dopamina!")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
            } else {
                let maxSeconds = max(1, socialList.first?.seconds ?? 1)
                VStack(spacing: 12) {
                    ForEach(socialList, id: \.source) { item in
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: socialIcon(for: item.source))
                                    .foregroundColor(socialColor(for: item.source))
                                    .font(.system(size: 13))
                                    .frame(width: 16)
                                
                                Text(item.source)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 140, alignment: .leading)
                            
                            // Barra de Tiempo Invertido
                            GeometryReader { geo in
                                let w = CGFloat(item.seconds) / CGFloat(maxSeconds) * geo.size.width
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 10)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(LinearGradient(
                                            colors: [socialColor(for: item.source), Color(hex: "#A855F7")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        ))
                                        .frame(width: max(8, w), height: 10)
                                }
                            }
                            .frame(height: 10)
                            
                            // Pastilla de Visitas
                            HStack(spacing: 3) {
                                Image(systemName: "eye.fill")
                                    .font(.system(size: 8))
                                Text("\(item.visits)x")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(Color(hex: "#E2E8F0"))
                            .cornerRadius(4)
                            
                            // Tiempo Formateado
                            let formattedTime = formatSeconds(item.seconds)
                            Text(formattedTime)
                                .font(.caption2)
                                .fontWeight(.heavy)
                                .foregroundColor(socialColor(for: item.source))
                                .frame(width: 65, alignment: .trailing)
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
                        .stroke(Color(hex: "#A855F7").opacity(0.25), lineWidth: 1)
                )
        )
    }
    
    private func socialIcon(for source: String) -> String {
        let s = source.lowercased()
        if s.contains("instagram") { return "camera.fill" }
        if s.contains("youtube") { return "play.rectangle.fill" }
        if s.contains("tiktok") { return "music.note" }
        if s.contains("twitter") || s.contains("x") { return "bubble.right.fill" }
        if s.contains("reddit") { return "bubble.left.and.bubble.right.fill" }
        if s.contains("facebook") { return "person.2.fill" }
        if s.contains("netflix") { return "tv.fill" }
        if s.contains("twitch") { return "gamecontroller.fill" }
        if s.contains("discord") { return "message.fill" }
        return "globe"
    }
    
    private func socialColor(for source: String) -> Color {
        let s = source.lowercased()
        if s.contains("instagram") { return Color(hex: "#EC4899") }
        if s.contains("youtube") { return Color(hex: "#EF4444") }
        if s.contains("tiktok") { return Color(hex: "#06B6D4") }
        if s.contains("twitter") || s.contains("x") { return Color(hex: "#38BDF8") }
        if s.contains("reddit") { return Color(hex: "#F97316") }
        if s.contains("facebook") { return Color(hex: "#3B82F6") }
        if s.contains("netflix") { return Color(hex: "#E11D48") }
        if s.contains("twitch") { return Color(hex: "#A855F7") }
        if s.contains("discord") { return Color(hex: "#6366F1") }
        return Color(hex: "#94A3B8")
    }
    
    private func formatSeconds(_ secs: Int) -> String {
        if secs < 60 { return "\(secs)s" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) min" }
        let hours = mins / 60
        let remMins = mins % 60
        return "\(hours)h \(remMins)m"
    }
    
    // MARK: - 4. Gráfico Semanal de Productividad
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
    
    // MARK: - 5. Desglose de Distracciones Evitadas (Dopamina Positiva)
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
    
    // MARK: - 6. Línea de Tiempo de Intercepciones Recientes
    private var recentActivityLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Registro en Vivo de Impulsos Interceptados", systemImage: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                let recents = statsManager.stats.recentInterceptions
                if !recents.isEmpty {
                    Text("\(recents.count) totales")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#64748B"))
                }
            }
            
            let recents = statsManager.stats.recentInterceptions
            if recents.isEmpty {
                Text("No hay intercepciones registradas aún.")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#94A3B8"))
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(recents.prefix(8)) { item in
                        HStack(spacing: 10) {
                            // Icono contextual por categoría y detalle
                            let iconConfig = iconConfigForSource(item.source, detail: item.detail)
                            ZStack {
                                Circle()
                                    .fill(iconConfig.color.opacity(0.15))
                                    .frame(width: 24, height: 24)
                                Image(systemName: iconConfig.icon)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(iconConfig.color)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.source)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    if !item.detail.isEmpty && item.detail.lowercased() != item.source.lowercased() {
                                        Text(item.detail)
                                            .font(.system(size: 10, weight: .semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(iconConfig.color.opacity(0.15))
                                            )
                                            .foregroundColor(iconConfig.color)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Text(timeAgo(date: item.timestamp))
                                .font(.caption2)
                                .foregroundColor(Color(hex: "#64748B"))
                        }
                        .padding(.vertical, 4)
                        
                        if item.id != recents.prefix(8).last?.id {
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
    
    private func iconConfigForSource(_ source: String, detail: String = "") -> (icon: String, color: Color) {
        let combined = (source + " " + detail).lowercased()
        if combined.contains("búsqueda") || combined.contains("busqueda") || combined.contains("palabra") {
            return ("text.magnifyingglass", Color(hex: "#F59E0B"))
        } else if combined.contains("whatsapp") {
            return ("circle.dashed.inset.filled", Color(hex: "#25D366"))
        } else if combined.contains("incógnito") || combined.contains("incognito") {
            return ("eyeglasses", Color(hex: "#8B5CF6"))
        } else if combined.contains("adulto") || combined.contains("+18") || combined.contains("porn") || combined.contains("terabox") {
            return ("hand.raised.fill", Color(hex: "#F43F5E"))
        } else if combined.contains("claude") || combined.contains("chatgpt") || combined.contains("gemini") {
            return ("sparkles", Color(hex: "#38BDF8"))
        } else {
            return ("shield.slash.fill", Color(hex: "#F43F5E"))
        }
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
