import SwiftUI

public struct AppBlockListView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var discoveredApps: [BlockedApp] = []
    @State private var isLoadingApps = false
    @State private var searchText = ""
    @State private var isWhatsAppExpanded: Bool = true
    @State private var showAllConfiguredApps = false
    @State private var showAllDiscoveredApps = false
    
    public var body: some View {
        let isEn = LocalizationService.shared.currentLanguage == .english
        VStack(alignment: .leading, spacing: 16) {
            // Encabezado
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("appblock.title"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                let activeCount = engine.settings.blockedApps.filter { $0.isEnabled }.count
                Text(isEn
                     ? "\(activeCount) of \(engine.settings.blockedApps.count) apps configured to intercept during focus sessions."
                     : "\(activeCount) de \(engine.settings.blockedApps.count) apps configuradas para interceptar durante tus sesiones de enfoque.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 50)
            
            // Buscador y Acción Masiva con altura y alineación homogénea
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(isEn ? "Search application by name..." : "Buscar aplicación por nombre...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                
                Button(action: { scanInstalledApps() }) {
                    HStack(spacing: 6) {
                        if isLoadingApps {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isEn ? "Scan" : "Escanear")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .help(isEn ? "Scan installed Mac applications" : "Escanear aplicaciones instaladas en la Mac")
                
                let allAppsActive = engine.settings.blockedApps.allSatisfy { $0.isEnabled }
                Button(action: {
                    engine.toggleAllBlockedApps(enabled: !allAppsActive)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: allAppsActive ? "xmark.circle" : "checkmark.circle")
                        Text(allAppsActive
                             ? (isEn ? "Disable All" : "Desactivar Todas")
                             : (isEn ? "Enable All" : "Activar Todas"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(height: 32)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            // Lista combinada (Apps configuradas + descubiertas)
            List {
                Section(header: configuredHeader) {
                    ForEach(displayedConfiguredApps) { app in
                        appRow(app: app, isConfigured: true)
                    }
                    
                    if configuredFilteredApps.count > 10 {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAllConfiguredApps.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showAllConfiguredApps ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                Text(showAllConfiguredApps
                                     ? (isEn ? "Show fewer apps" : "Ver menos aplicaciones")
                                     : (isEn ? "Show more apps (\(configuredFilteredApps.count - 10) additional)" : "Ver más aplicaciones (\(configuredFilteredApps.count - 10) adicionales)"))
                            }
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if !availableDiscoveredApps.isEmpty {
                    Section(header: Text(isEn
                                         ? "Other Apps Detected on your Mac (\(availableDiscoveredApps.count))"
                                         : "Otras Aplicaciones Detectadas en tu Mac (\(availableDiscoveredApps.count))")) {
                        ForEach(displayedDiscoveredApps) { app in
                            appRow(app: app, isConfigured: false)
                        }
                        
                        if availableDiscoveredApps.count > 10 {
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showAllDiscoveredApps.toggle()
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showAllDiscoveredApps ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    Text(showAllDiscoveredApps
                                         ? (isEn ? "Show fewer apps" : "Ver menos aplicaciones")
                                         : (isEn ? "Show more apps (\(availableDiscoveredApps.count - 10) additional)" : "Ver más aplicaciones (\(availableDiscoveredApps.count - 10) adicionales)"))
                                }
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .padding(20)
        .onAppear {
            if discoveredApps.isEmpty {
                scanInstalledApps()
            }
        }
    }
    
    private var configuredHeader: some View {
        let isEn = LocalizationService.shared.currentLanguage == .english
        return HStack {
            Text(isEn
                 ? "Apps Selected for Blocking (\(configuredFilteredApps.count))"
                 : "Apps Seleccionadas para Bloqueo (\(configuredFilteredApps.count))")
                .fontWeight(.bold)
            Spacer()
            
            let allActive = configuredFilteredApps.allSatisfy { $0.isEnabled }
            Button(allActive
                   ? (isEn ? "Disable All" : "Desactivar Todas")
                   : (isEn ? "Enable All" : "Activar Todas")) {
                engine.toggleAllBlockedApps(enabled: !allActive)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
        }
    }
    
    private var displayedConfiguredApps: [BlockedApp] {
        if showAllConfiguredApps || configuredFilteredApps.count <= 10 {
            return configuredFilteredApps
        }
        return Array(configuredFilteredApps.prefix(10))
    }
    
    private var configuredFilteredApps: [BlockedApp] {
        engine.settings.blockedApps
            .filter { app in
                // Solo mostrar aplicaciones que realmente existen en el sistema
                AppBlockerService.isAppInstalled(app) &&
                (searchText.isEmpty || app.appName.localizedCaseInsensitiveContains(searchText))
            }
            .sorted(by: { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending })
    }
    
    private var displayedDiscoveredApps: [BlockedApp] {
        if showAllDiscoveredApps || availableDiscoveredApps.count <= 10 {
            return availableDiscoveredApps
        }
        return Array(availableDiscoveredApps.prefix(10))
    }
    
    private var availableDiscoveredApps: [BlockedApp] {
        let configuredIds = Set(engine.settings.blockedApps.map { $0.bundleIdentifier })
        return discoveredApps
            .filter { app in
                !configuredIds.contains(app.bundleIdentifier) &&
                AppBlockerService.isAppInstalled(app) &&
                (searchText.isEmpty || app.appName.localizedCaseInsensitiveContains(searchText))
            }
            .sorted(by: { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending })
    }
    
    private func appRow(app: BlockedApp, isConfigured: Bool) -> some View {
        let isWhatsApp = app.bundleIdentifier == "net.whatsapp.WhatsApp" || app.appName.lowercased().contains("whatsapp")
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 14) {
                // Icono real nativo de la aplicación de macOS
                AppIconView(app: app, size: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.appName)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        if isWhatsApp {
                            Text("ESTADOS & CANALES")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Color(hex: "#25D366"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color(hex: "#25D366").opacity(0.15)))
                        }
                    }
                    
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isWhatsApp {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isWhatsAppExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isWhatsAppExpanded ? "Opciones" : "Ver Opciones")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Image(systemName: isWhatsAppExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(Color(hex: "#25D366"))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                }
                
                if isConfigured {
                    HStack(spacing: 8) {
                        Toggle("", isOn: Binding(
                            get: { app.isEnabled },
                            set: { newValue in
                                engine.toggleBlockedApp(id: app.id, isEnabled: newValue)
                            }
                        ))
                        .toggleStyle(.switch)
                        
                        Button(action: {
                            engine.removeBlockedApp(id: app.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Eliminar de la lista")
                    }
                } else {
                    Button(action: {
                        engine.addBlockedApp(app: app)
                        if isWhatsApp {
                            engine.updateWhatsAppStatusBlocker(enabled: true)
                            engine.updateWhatsAppChannelsBlocker(enabled: true)
                        }
                    }) {
                        Label("Añadir", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isWhatsApp ? Color(hex: "#25D366") : Color.accentColor)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 4)
            
            // Sub-panel desplegable exclusivo de WhatsApp (Estados y Canales)
            if isWhatsApp && isWhatsAppExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "circle.dashed.inset.filled")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#25D366"))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Bloquear Estados / Historias")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("Muestra popup nativo y cierra historias al abrirlas")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isWhatsAppStatusBlockerEnabled },
                            set: { engine.updateWhatsAppStatusBlocker(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(hex: "#25D366").opacity(0.08))
                    .cornerRadius(8)
                    
                    HStack {
                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#0284C7"))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Bloquear Canales / Novedades")
                                .font(.caption)
                                .fontWeight(.bold)
                            Text("Cierra la pestaña de canales para evitar lecturas infinitas")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { engine.settings.isWhatsAppChannelsBlockerEnabled },
                            set: { engine.updateWhatsAppChannelsBlocker(enabled: $0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color(hex: "#0284C7").opacity(0.08))
                    .cornerRadius(8)
                }
                .padding(.leading, 46)
                .padding(.bottom, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
}
