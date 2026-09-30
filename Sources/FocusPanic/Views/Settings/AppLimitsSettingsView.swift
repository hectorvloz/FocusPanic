import SwiftUI

public struct AppLimitsSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    
    @State private var isShowingAddSheet = false
    @State private var discoveredApps: [BlockedApp] = []
    @State private var isLoadingApps = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "hourglass")
                            .foregroundColor(Color(hex: "#F59E0B"))
                        Text("Límites para Apps y Sitios")
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    
                    Text("Define límites de tiempo diarios para aplicaciones o sitios web. Cuando se agota el tiempo, FocusPanic bloquea su acceso por el resto del día.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // MARK: - Tarjeta 1: Interruptor Maestro
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: "#F59E0B").opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: "hourglass.badge.plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#F59E0B"))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Límites para apps")
                                .font(.headline)
                            Text("Define límites de tiempo diarios para las apps o sitios web que quieres administrar. Los límites se restablecen a medianoche.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isAppLimitsEnabled },
                            set: { newValue in
                                engine.settings.isAppLimitsEnabled = newValue
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
                
                // MARK: - Tarjeta 2: Listado de Límites Configurados
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Límites Activos (\(engine.settings.appLimits.count))", systemImage: "list.bullet.rectangle.portrait")
                            .font(.headline)
                        Spacer()
                        
                        Button(action: {
                            scanInstalledApps()
                            isShowingAddSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Agregar límite...")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#F59E0B"))
                        .controlSize(.small)
                    }
                    
                    if engine.settings.appLimits.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "hourglass.bottomhalf.filled")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                            Text("No tienes límites de tiempo configurados.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Haz clic en 'Agregar límite...' para definir un tiempo máximo diario para tus apps o sitios web.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(Color.secondary.opacity(0.02))
                        .cornerRadius(10)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(engine.settings.appLimits) { limit in
                                limitRow(limit: limit)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.secondary.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .sheet(isPresented: $isShowingAddSheet) {
            addLimitSheetContent
        }
    }
    
    @ViewBuilder
    private func limitRow(limit: AppTimeLimit) -> some View {
        HStack(spacing: 12) {
            // Icono
            if limit.targetType == "app" {
                if let installedApp = engine.settings.blockedApps.first(where: { $0.bundleIdentifier == limit.identifier }) {
                    AppIconView(app: installedApp, size: 28)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "app.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.purple)
                    }
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "globe")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(limit.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(formattedDuration(minutes: limit.limitMinutes)), todos los días")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { limit.isEnabled },
                    set: { newValue in
                        if let idx = engine.settings.appLimits.firstIndex(where: { $0.id == limit.id }) {
                            engine.settings.appLimits[idx].isEnabled = newValue
                            engine.saveSettings()
                            engine.evaluateDowntimeAndLimits()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                
                Button(action: {
                    engine.settings.appLimits.removeAll { $0.id == limit.id }
                    engine.saveSettings()
                    engine.evaluateDowntimeAndLimits()
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(limit.isEnabled ? Color(hex: "#F59E0B").opacity(0.08) : Color.secondary.opacity(0.04))
        .cornerRadius(8)
    }
    
    // MARK: - Hoja para Añadir Nuevo Límite
    @State private var newTargetType = 0 // 0: App, 1: Sitio Web
    @State private var selectedAppBundleId: String = ""
    @State private var selectedAppName: String = ""
    
    // Lista de sitios web agregados para el nuevo límite
    @State private var webDomainInput: String = ""
    @State private var addedWebDomains: [String] = []
    
    @State private var limitHours: Int = 0
    @State private var limitMinutes: Int = 15
    @State private var sheetSearchText: String = ""
    
    private var addLimitSheetContent: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Nuevo Límite de Tiempo")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Button("Cancelar") {
                    isShowingAddSheet = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Picker("Tipo de Objetivo", selection: $newTargetType) {
                Text("Aplicación").tag(0)
                Text("Sitio Web").tag(1)
            }
            .pickerStyle(.segmented)
            
            if newTargetType == 0 {
                // Selector de Aplicación
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar aplicación instalada...", text: $sheetSearchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            let apps = discoveredApps.filter { app in
                                sheetSearchText.isEmpty || app.appName.localizedCaseInsensitiveContains(sheetSearchText)
                            }
                            
                            ForEach(apps) { app in
                                let isSelected = selectedAppBundleId == app.bundleIdentifier
                                Button(action: {
                                    selectedAppBundleId = app.bundleIdentifier
                                    selectedAppName = app.appName
                                }) {
                                    HStack(spacing: 10) {
                                        AppIconView(app: app, size: 24)
                                        Text(app.appName)
                                            .font(.subheadline)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color(hex: "#F59E0B"))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? Color(hex: "#F59E0B").opacity(0.12) : Color.clear)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 160)
                }
            } else {
                // Selector de Sitio Web (con soporte de pulsar Enter y agregar múltiples)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.secondary)
                        TextField("Escribe el dominio (ej. youtube.com) y presiona Enter...", text: $webDomainInput)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                addDomainToLimitList()
                            }
                        
                        Button(action: {
                            addDomainToLimitList()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Añadir")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#F59E0B"))
                        .controlSize(.small)
                        .disabled(webDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                    
                    // Lista de Dominios Agregados para este límite
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sitios Web en este límite (\(addedWebDomains.count)):")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        if addedWebDomains.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.dashed")
                                    .font(.system(size: 24))
                                    .foregroundColor(.secondary.opacity(0.6))
                                Text("Escribe un dominio arriba y pulsa Enter para añadirlo.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.secondary.opacity(0.03))
                            .cornerRadius(8)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(addedWebDomains, id: \.self) { domain in
                                        HStack(spacing: 8) {
                                            Image(systemName: "globe")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            Text(domain)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Button(action: {
                                                withAnimation {
                                                    addedWebDomains.removeAll { $0 == domain }
                                                }
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.caption)
                                                    .foregroundColor(.red.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.06))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 130)
                }
            }
            
            Divider()
            
            // Selector de Tiempo Diario (Espacioso y con etiquetas claras)
            HStack(alignment: .center, spacing: 14) {
                Text("Límite Diario:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text("Horas:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $limitHours) {
                            ForEach(0..<24) { h in
                                Text("\(h) h").tag(h)
                            }
                        }
                        .frame(width: 80)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                    
                    HStack(spacing: 4) {
                        Text("Minutos:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $limitMinutes) {
                            ForEach([0, 1, 5, 10, 15, 20, 25, 30, 45, 50], id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                        .frame(width: 90)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 2)
            
            Spacer()
            
            Button(action: {
                saveNewLimit()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Guardar Límite de Tiempo")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#F59E0B"))
            .disabled(!isNewLimitValid)
        }
        .padding(22)
        .frame(width: 530, height: 500)
    }
    
    private func addDomainToLimitList() {
        let clean = webDomainInput.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        guard !clean.isEmpty else { return }
        
        if !addedWebDomains.contains(clean) {
            withAnimation {
                addedWebDomains.append(clean)
            }
        }
        webDomainInput = ""
    }
    
    private var isNewLimitValid: Bool {
        let totalMins = limitHours * 60 + limitMinutes
        guard totalMins > 0 else { return false }
        
        if newTargetType == 0 {
            return !selectedAppBundleId.isEmpty
        } else {
            return !addedWebDomains.isEmpty || !webDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func saveNewLimit() {
        let totalMins = limitHours * 60 + limitMinutes
        
        if newTargetType == 0 {
            let newLimit = AppTimeLimit(
                targetType: "app",
                identifier: selectedAppBundleId,
                name: selectedAppName.isEmpty ? selectedAppBundleId : selectedAppName,
                limitMinutes: totalMins
            )
            engine.settings.appLimits.append(newLimit)
        } else {
            // Si el usuario escribió un dominio y no le dio enter antes de guardar, lo agregamos
            if !webDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                addDomainToLimitList()
            }
            
            guard !addedWebDomains.isEmpty else { return }
            
            // Generar nombre descriptivo como Apple Screen Time (ej. "Facebook y m.facebook.com")
            let displayName: String
            if addedWebDomains.count == 1 {
                displayName = addedWebDomains[0]
            } else if addedWebDomains.count == 2 {
                displayName = "\(addedWebDomains[0]) y \(addedWebDomains[1])"
            } else {
                displayName = "\(addedWebDomains[0]), \(addedWebDomains[1]) y \(addedWebDomains.count - 2) más"
            }
            
            let joinedIdentifiers = addedWebDomains.joined(separator: ",")
            let newLimit = AppTimeLimit(
                targetType: "website",
                identifier: joinedIdentifiers,
                name: displayName,
                limitMinutes: totalMins
            )
            engine.settings.appLimits.append(newLimit)
        }
        
        engine.saveSettings()
        engine.evaluateDowntimeAndLimits()
        isShowingAddSheet = false
        selectedAppBundleId = ""
        selectedAppName = ""
        webDomainInput = ""
        addedWebDomains.removeAll()
    }
    
    private func scanInstalledApps() {
        isLoadingApps = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = AppBlockerService.discoverInstalledApplications()
            DispatchQueue.main.async {
                self.discoveredApps = apps
                self.isLoadingApps = false
            }
        }
    }
    
    private func formattedDuration(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 {
            return "\(h) h \(m) min"
        } else if h > 0 {
            return "\(h) h"
        } else {
            return "\(m) min"
        }
    }
}

