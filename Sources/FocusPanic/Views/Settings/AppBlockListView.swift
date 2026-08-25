import SwiftUI

public struct AppBlockListView: View {
    @ObservedObject var engine = FocusEngine.shared
    @State private var discoveredApps: [BlockedApp] = []
    @State private var isLoadingApps = false
    @State private var searchText = ""
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Encabezado
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aplicaciones de Mac Bloqueadas")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    let activeCount = engine.settings.blockedApps.filter { $0.isEnabled }.count
                    Text("\(activeCount) de \(engine.settings.blockedApps.count) apps se cerrarán e interceptarán durante tus sesiones de enfoque.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { scanInstalledApps() }) {
                    if isLoadingApps {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Escanear Apps", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // Buscador y Acción Masiva
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar aplicación por nombre...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                
                let allAppsActive = engine.settings.blockedApps.allSatisfy { $0.isEnabled }
                Button(action: {
                    engine.toggleAllBlockedApps(enabled: !allAppsActive)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: allAppsActive ? "xmark.circle" : "checkmark.circle")
                        Text(allAppsActive ? "Desactivar Todas" : "Activar Todas")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
            }
            
            // Lista combinada (Apps configuradas + descubiertas)
            List {
                Section(header: configuredHeader) {
                    ForEach(configuredFilteredApps) { app in
                        appRow(app: app, isConfigured: true)
                    }
                }
                
                if !availableDiscoveredApps.isEmpty {
                    Section(header: Text("Otras Aplicaciones Detectadas en tu Mac (\(availableDiscoveredApps.count))")) {
                        ForEach(availableDiscoveredApps) { app in
                            appRow(app: app, isConfigured: false)
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
        HStack {
            Text("Apps Seleccionadas para Bloqueo (\(configuredFilteredApps.count))")
                .fontWeight(.bold)
            Spacer()
            
            let allActive = configuredFilteredApps.allSatisfy { $0.isEnabled }
            Button(allActive ? "Desactivar Todas" : "Activar Todas") {
                engine.toggleAllBlockedApps(enabled: !allActive)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.accentColor)
        }
    }
    
    private var configuredFilteredApps: [BlockedApp] {
        engine.settings.blockedApps.filter { app in
            searchText.isEmpty || app.appName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var availableDiscoveredApps: [BlockedApp] {
        let configuredIds = Set(engine.settings.blockedApps.map { $0.bundleIdentifier })
        return discoveredApps.filter { app in
            !configuredIds.contains(app.bundleIdentifier) &&
            (searchText.isEmpty || app.appName.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    private func appRow(app: BlockedApp, isConfigured: Bool) -> some View {
        HStack(spacing: 14) {
            // Icono real nativo de la aplicación de macOS
            AppIconView(app: app, size: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
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
                }) {
                    Label("Añadir", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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
