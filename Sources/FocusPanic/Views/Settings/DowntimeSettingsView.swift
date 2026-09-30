import SwiftUI

public struct DowntimeSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    
    @State private var startTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @State private var endTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    
    public init() {}
    
    private var isDowntimeCurrentlyActive: Bool {
        guard engine.settings.downtimeSchedule.isEnabled else { return false }
        
        let now = Date()
        let calendar = Calendar.current
        let currentDay = calendar.component(.weekday, from: now) // 1=Dom, 2=Lun, ...
        
        guard engine.settings.downtimeSchedule.activeDays.contains(currentDay) else {
            return false
        }
        
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTotalMins = currentHour * 60 + currentMinute
        
        let startTotalMins = engine.settings.downtimeSchedule.startHour * 60 + engine.settings.downtimeSchedule.startMinute
        let endTotalMins = engine.settings.downtimeSchedule.endHour * 60 + engine.settings.downtimeSchedule.endMinute
        
        if startTotalMins <= endTotalMins {
            return currentTotalMins >= startTotalMins && currentTotalMins < endTotalMins
        } else {
            // Cruza la medianoche (ej. 22:00 a 07:00)
            return currentTotalMins >= startTotalMins || currentTotalMins < endTotalMins
        }
    }
    
    public var body: some View {
        let isEn = LocalizationService.shared.currentLanguage == .english
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .foregroundColor(Color(hex: "#6366F1"))
                        Text(L10n.tr("downtime.title"))
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    
                    Text(L10n.tr("downtime.desc"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // MARK: - Banner de Estado en Vivo (Si está activo ahora)
                if isDowntimeCurrentlyActive {
                    HStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "#6366F1"))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEn ? "Downtime Schedule in Progress" : "Tiempo Desactivado en Curso")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: "#6366F1"))
                            Text(isEn
                                 ? "Scheduled block is active until \(formattedTime(hour: engine.settings.downtimeSchedule.endHour, minute: engine.settings.downtimeSchedule.endMinute))."
                                 : "El bloqueo programado está activo hasta las \(formattedTime(hour: engine.settings.downtimeSchedule.endHour, minute: engine.settings.downtimeSchedule.endMinute)).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(hex: "#6366F1").opacity(0.12))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#6366F1").opacity(0.3), lineWidth: 1)
                    )
                }
                
                // MARK: - Tarjeta 1: Interruptor Maestro
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#6366F1").opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "timer")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#6366F1"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.tr("downtime.enable"))
                                .font(.headline)
                            Text(isEn
                                 ? "During downtime only allowed apps and websites on your Whitelist will be available."
                                 : "Durante el tiempo desactivado sólo estarán disponibles las apps permitidas. Se activará el bloqueo hasta que se reanude el horario.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.downtimeSchedule.isEnabled },
                            set: { newValue in
                                engine.settings.downtimeSchedule.isEnabled = newValue
                                engine.saveSettings()
                                engine.evaluateDowntimeAndLimits()
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // MARK: - Tarjeta 2: Horario y Días
                VStack(alignment: .leading, spacing: 16) {
                    // Selector de tipo de horario
                    HStack {
                        Text(isEn ? "Schedule:" : "Horario:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        
                        Picker("", selection: Binding(
                            get: { engine.settings.downtimeSchedule.scheduleType },
                            set: { newValue in
                                engine.settings.downtimeSchedule.scheduleType = newValue
                                updateActiveDaysForType(newValue)
                                engine.saveSettings()
                                engine.evaluateDowntimeAndLimits()
                            }
                        )) {
                            Text(L10n.tr("downtime.schedule.everyday")).tag(0)
                            Text(L10n.tr("downtime.schedule.weekdays")).tag(1)
                            Text(L10n.tr("downtime.schedule.weekends")).tag(2)
                            Text(L10n.tr("downtime.schedule.custom")).tag(3)
                        }
                        .frame(width: 170)
                    }
                    
                    // Selector de Días si es Personalizado
                    if engine.settings.downtimeSchedule.scheduleType == 3 {
                        HStack(spacing: 8) {
                            ForEach(daysOfWeek, id: \.day) { item in
                                let isSelected = engine.settings.downtimeSchedule.activeDays.contains(item.day)
                                Button(action: {
                                    toggleDay(item.day)
                                }) {
                                    Text(item.name)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 7)
                                        .background(isSelected ? Color(hex: "#6366F1") : Color.secondary.opacity(0.08))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Divider()
                    
                    // Hora de Inicio
                    HStack {
                        Text(L10n.tr("downtime.start") + ":")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        
                        DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: startTime) { newDate in
                                let cal = Calendar.current
                                engine.settings.downtimeSchedule.startHour = cal.component(.hour, from: newDate)
                                engine.settings.downtimeSchedule.startMinute = cal.component(.minute, from: newDate)
                                engine.saveSettings()
                                engine.evaluateDowntimeAndLimits()
                            }
                    }
                    
                    Divider()
                    
                    // Hora de Fin
                    HStack {
                        Text(L10n.tr("downtime.end") + ":")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        
                        DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: endTime) { newDate in
                                let cal = Calendar.current
                                engine.settings.downtimeSchedule.endHour = cal.component(.hour, from: newDate)
                                engine.settings.downtimeSchedule.endMinute = cal.component(.minute, from: newDate)
                                engine.saveSettings()
                                engine.evaluateDowntimeAndLimits()
                            }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
                
                // MARK: - Tarjeta 3: Bloquear durante el intervalo
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEn ? "Block during downtime window" : "Bloquear durante el intervalo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(isEn
                                 ? "When active, websites and apps not on your Whitelist will be restricted during this period."
                                 : "Si se activa, se bloquearán las aplicaciones y sitios web fuera de la Lista Blanca durante el periodo.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.downtimeSchedule.blockDuringDowntime },
                            set: { newValue in
                                engine.settings.downtimeSchedule.blockDuringDowntime = newValue
                                engine.saveSettings()
                                engine.evaluateDowntimeAndLimits()
                            }
                        ))
                        .toggleStyle(.switch)
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .onAppear {
            loadInitialDates()
        }
    }
    
    private var daysOfWeek: [(day: Int, name: String)] {
        let isEn = LocalizationService.shared.currentLanguage == .english
        return [
            (2, isEn ? "M" : "L"),
            (3, isEn ? "T" : "M"),
            (4, isEn ? "W" : "X"),
            (5, isEn ? "T" : "J"),
            (6, isEn ? "F" : "V"),
            (7, isEn ? "S" : "S"),
            (1, isEn ? "S" : "D")
        ]
    }
    
    private func loadInitialDates() {
        var startComp = DateComponents()
        startComp.hour = engine.settings.downtimeSchedule.startHour
        startComp.minute = engine.settings.downtimeSchedule.startMinute
        if let d = Calendar.current.date(from: startComp) {
            self.startTime = d
        }
        
        var endComp = DateComponents()
        endComp.hour = engine.settings.downtimeSchedule.endHour
        endComp.minute = engine.settings.downtimeSchedule.endMinute
        if let d = Calendar.current.date(from: endComp) {
            self.endTime = d
        }
    }
    
    private func updateActiveDaysForType(_ type: Int) {
        switch type {
        case 0: // Cada día
            engine.settings.downtimeSchedule.activeDays = [1, 2, 3, 4, 5, 6, 7]
        case 1: // Lunes a Viernes
            engine.settings.downtimeSchedule.activeDays = [2, 3, 4, 5, 6]
        case 2: // Fin de semana
            engine.settings.downtimeSchedule.activeDays = [1, 7]
        default:
            break
        }
    }
    
    private func toggleDay(_ day: Int) {
        if engine.settings.downtimeSchedule.activeDays.contains(day) {
            if engine.settings.downtimeSchedule.activeDays.count > 1 {
                engine.settings.downtimeSchedule.activeDays.removeAll { $0 == day }
            }
        } else {
            engine.settings.downtimeSchedule.activeDays.append(day)
        }
        engine.saveSettings()
        engine.evaluateDowntimeAndLimits()
    }
    
    private func formattedTime(hour: Int, minute: Int) -> String {
        let isPM = hour >= 12
        let h12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%02d:%02d %@", h12, minute, isPM ? "p.m." : "a.m.")
    }
}
