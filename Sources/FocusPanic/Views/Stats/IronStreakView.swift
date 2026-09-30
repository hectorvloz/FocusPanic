import SwiftUI

public struct IronStreakView: View {
    @ObservedObject var statsManager = FocusStatsManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Tarjeta Principal de Racha de Hierro
                    ironStreakHeroCard
                    
                    // MARK: - Barra de Nivel & Progreso de XP
                    xpLevelProgressCard
                    
                    // MARK: - Insignias de Logros Desbloqueables
                    badgesSectionCard
                    
                    // MARK: - Historial de los Últimos 7 Días
                    recentStreakDaysCard
                    
                    // MARK: - Reglas de Dopamina & XP
                    xpRulesCard
                }
                .padding(24)
            }
            
            // Botón de Cerrar
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.trailing, 20)
        }
        .frame(width: 680, height: 600)
        .background(VisualEffectBackground())
    }
    
    // MARK: - Hero Card: Racha de Hierro
    private var ironStreakHeroCard: some View {
        let streak = statsManager.stats.currentStreakDays
        let tier = statsManager.currentTier
        
        return ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: tier.colorHex).opacity(0.25),
                            Color(hex: "#1E1E24").opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: tier.colorHex).opacity(0.4), lineWidth: 1.5)
                )
            
            HStack(spacing: 24) {
                // Llama Gigante Animada
                ZStack {
                    Circle()
                        .fill(Color(hex: tier.colorHex).opacity(0.2))
                        .frame(width: 90, height: 90)
                    
                    Circle()
                        .stroke(Color(hex: tier.colorHex).opacity(0.5), lineWidth: 2)
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#FDE047"), Color(hex: tier.colorHex)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(hex: tier.colorHex).opacity(0.6), radius: 10)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("\(streak) \(streak == 1 ? "DÍA" : "DÍAS")")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("RACHA ACTIVA")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: tier.colorHex).opacity(0.25))
                            .foregroundColor(Color(hex: tier.colorHex))
                            .cornerRadius(6)
                    }
                    
                    Text("Mejor racha histórica: \(statsManager.stats.bestStreakDays) días consecutivos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("¡Cada día sin caer en distracciones fortalece tu circuito de enfoque!")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(20)
        }
    }
    
    // MARK: - Barra de Progreso de Nivel de XP
    private var xpLevelProgressCard: some View {
        let tier = statsManager.currentTier
        let next = statsManager.nextTier
        let progress = statsManager.tierProgressFraction
        let xpNeeded = statsManager.xpNeededForNextTier
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: tier.icon)
                        .foregroundColor(Color(hex: tier.colorHex))
                        .font(.headline)
                    
                    Text("Nivel \(tier.level): \(tier.title)")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Text("\(statsManager.stats.totalXP) XP Totales")
                    .font(.subheadline)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(hex: tier.colorHex))
            }
            
            // Barra de progreso personalizada
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 14)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: tier.colorHex), Color(hex: next?.colorHex ?? tier.colorHex)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(14, geo.size.width * CGFloat(progress)), height: 14)
                            .shadow(color: Color(hex: tier.colorHex).opacity(0.5), radius: 4)
                    }
                }
                .frame(height: 14)
                
                HStack {
                    Text("\(Int(progress * 100))% al siguiente rango")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let nextTier = next {
                        Text("Faltan \(xpNeeded) XP para \(nextTier.title)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(Color(hex: nextTier.colorHex))
                    } else {
                        Text("¡Rango Máximo Alcanzado!")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Insignias de Logros
    private var badgesSectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Insignias & Logros", systemImage: "trophy.fill")
                    .font(.headline)
                    .foregroundColor(.yellow)
                Spacer()
                Text("\(statsManager.stats.unlockedBadgeIds.count) de \(FocusBadge.allBadges.count) desbloqueadas")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(FocusBadge.allBadges) { badge in
                    let isUnlocked = statsManager.stats.unlockedBadgeIds.contains(badge.id)
                    badgeItemView(badge: badge, isUnlocked: isUnlocked)
                }
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    private func badgeItemView(badge: FocusBadge, isUnlocked: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color(hex: badge.colorHex).opacity(0.2) : Color.secondary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: isUnlocked ? badge.icon : "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(isUnlocked ? Color(hex: badge.colorHex) : .secondary.opacity(0.6))
            }
            
            VStack(spacing: 2) {
                Text(badge.name)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
                
                Text(badge.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 24)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(isUnlocked ? Color(hex: badge.colorHex).opacity(0.08) : Color.secondary.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isUnlocked ? Color(hex: badge.colorHex).opacity(0.35) : Color.clear, lineWidth: 1)
        )
    }
    
    // MARK: - Historial de los Últimos 7 Días
    private var recentStreakDaysCard: some View {
        let history = statsManager.last7DaysHistory()
        
        return VStack(alignment: .leading, spacing: 14) {
            Label("Consistencia de los Últimos 7 Días", systemImage: "calendar")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(history, id: \.dayLabel) { item in
                    let isCompleted = item.minutes > 0
                    
                    VStack(spacing: 8) {
                        Text(item.dayLabel)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(item.isToday ? .accentColor : .secondary)
                        
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Color(hex: "#10B981").opacity(0.2) : Color.secondary.opacity(0.08))
                                .frame(width: 36, height: 36)
                            
                            if isCompleted {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "#10B981"))
                            } else {
                                Circle()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(item.isToday ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                        
                        Text(isCompleted ? "\(item.minutes)m" : "-")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isCompleted ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(item.isToday ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(8)
                }
            }
        }
        .padding(18)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - Reglas de XP
    private var xpRulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("¿Cómo ganar Focus XP?")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                rulePill(title: "+10 XP", subtitle: "Por cada minuto enfocado", icon: "timer")
                rulePill(title: "+100 XP", subtitle: "Bono por día de racha", icon: "flame.fill")
                rulePill(title: "+5 XP", subtitle: "Por impulso interceptado", icon: "shield.checkered")
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.04))
        .cornerRadius(12)
    }
    
    private func rulePill(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.heavy)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}
