import SwiftUI

public struct WhitelistSettingsView: View {
    @ObservedObject var engine = FocusEngine.shared
    
    // Controles para Sitios Web
    @State private var webAddMode = 0 // 0: Individual, 1: Varios Sitios
    @State private var singleWebName = ""
    @State private var singleWebDomain = ""
    @State private var batchWebText = ""
    
    // Controles para Aplicaciones
    @State private var discoveredApps: [BlockedApp] = []
    @State private var isLoadingApps = false
    @State private var isShowingAddAppSheet = false
    @State private var appSearchText = ""
    @State private var sheetSearchText = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // MARK: - Encabezado
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("Lista Blanca (Sitios & Apps Permitidas)")
                    }
                    .font(.title2)
                    .fontWeight(.bold)
                    
                    Text("Los elementos en esta lista NUNCA serán bloqueados en ninguna sesión ni en el modo Bloqueo Total, garantizando acceso ininterrumpido a tus herramientas de trabajo y estudio.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // MARK: - Protección Esencial del Sistema
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#10B981"))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Protección de Estabilidad de macOS")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Servicios críticos de Apple (iCloud Sync, DNS del sistema, hora y localhost) se mantienen siempre protegidos y accesibles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(hex: "#10B981").opacity(0.08))
                .cornerRadius(10)
                
                // MARK: - SECCIÓN 1: Sitios Web Permitidos
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Sitios Web en Lista Blanca (\(engine.settings.allowedWebsites.filter { $0.isEnabled }.count) activos)", systemImage: "globe")
                            .font(.headline)
                        Spacer()
                        
                        let allAllowedWebs = engine.settings.allowedWebsites.allSatisfy { $0.isEnabled }
                        Button(action: {
                            engine.toggleAllAllowedWebsites(enabled: !allAllowedWebs)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allAllowedWebs ? "xmark.circle" : "checkmark.circle")
                                Text(allAllowedWebs ? "Desactivar Todos" : "Activar Todos")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    // Añadir Sitios (Individual / Varios Sitios)
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Modo de Adición", selection: $webAddMode) {
                            Text("Individual").tag(0)
                            Text("Varios Sitios").tag(1)
                        }
                        .pickerStyle(.segmented)
                        
                        if webAddMode == 0 {
                            HStack(spacing: 10) {
                                TextField("Nombre (ej. Meta Business)", text: $singleWebName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                
                                TextField("URL / Subdominio / Ruta (ej. business.facebook.com, reddit.com/r/swift)", text: $singleWebDomain)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: .infinity)
                                    .onSubmit { addSingleAllowedWeb() }
                                
                                Button(action: { addSingleAllowedWeb() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("Permitir")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: "#10B981"))
                                .disabled(singleWebDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Pega varios dominios, subdominios o URLs de trabajo (ej. business.facebook.com, music.youtube.com, facebook.com/ads):")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                TextEditor(text: $batchWebText)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(height: 70)
                                    .padding(4)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                
                                HStack {
                                    Spacer()
                                    Button(action: { processBatchAllowedWebs() }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.square.fill.on.square.fill")
                                            Text("Añadir Varios Sitios")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#10B981"))
                                    .disabled(batchWebText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(10)
                    
                    // Lista de Sitios Web Permitidos
                    VStack(spacing: 6) {
                        ForEach(engine.settings.allowedWebsites) { site in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(hex: site.category.colorHex).opacity(0.15))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: site.category.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: site.category.colorHex))
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(site.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(site.domain)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Toggle("", isOn: Binding(
                                        get: { site.isEnabled },
                                        set: { _ in engine.toggleAllowedWebsite(domain: site.domain) }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    
                                    if site.isCustom || !AppSettings.defaultAllowedWebsites.contains(where: { $0.domain == site.domain }) {
                                        Button(action: {
                                            engine.settings.allowedWebsites.removeAll { $0.id == site.id }
                                            engine.saveSettings()
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(site.isEnabled ? Color(hex: "#10B981").opacity(0.08) : Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
                
                // MARK: - SECCIÓN 2: Aplicaciones Permitidas
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Aplicaciones de Trabajo Permitidas (\(engine.settings.allowedApps.filter { $0.isEnabled }.count) activas)", systemImage: "app.badge.checkmark")
                            .font(.headline)
                        Spacer()
                        
                        let allAllowedApps = engine.settings.allowedApps.allSatisfy { $0.isEnabled }
                        Button(action: {
                            engine.toggleAllAllowedApps(enabled: !allAllowedApps)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: allAllowedApps ? "xmark.circle" : "checkmark.circle")
                                Text(allAllowedApps ? "Desactivar Todos" : "Activar Todos")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        // Botón Prominente para Abrir el Catálogo Completo de Apps
                        Button(action: {
                            if discoveredApps.isEmpty {
                                scanInstalledApps()
                            }
                            isShowingAddAppSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                Text("Añadir App (Catálogo)")
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#10B981"))
                        .controlSize(.small)
                    }
                    
                    // Buscador Rápido Integrado
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Buscar app permitida (ej. Slack, Figma, VS Code)...", text: $appSearchText)
                            .textFieldStyle(.plain)
                        if !appSearchText.isEmpty {
                            Button(action: { appSearchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                    
                    // Resultados de búsqueda si escribe en el buscador rápido
                    if !availableDiscoveredApps.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Sugerencias encontradas en tu Mac:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(availableDiscoveredApps.prefix(4)) { app in
                                HStack(spacing: 10) {
                                    AppIconView(app: app, size: 24)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(app.appName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Text(app.bundleIdentifier)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        engine.addAllowedApp(app: app)
                                        appSearchText = ""
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Permitir")
                                        }
                                        .font(.caption2)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#10B981"))
                                    .controlSize(.mini)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.04))
                                .cornerRadius(6)
                            }
                        }
                        .padding(8)
                        .background(Color(hex: "#10B981").opacity(0.05))
                        .cornerRadius(8)
                    }
                    
                    // Lista de Aplicaciones Actualmente Permitidas
                    VStack(spacing: 6) {
                        ForEach(filteredAllowedApps) { app in
                            HStack(spacing: 12) {
                                AppIconView(app: app, size: 28)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(app.appName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(app.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 12) {
                                    Toggle("", isOn: Binding(
                                        get: { app.isEnabled },
                                        set: { _ in engine.toggleAllowedApp(bundleId: app.bundleIdentifier) }
                                    ))
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    
                                    if !AppSettings.defaultAllowedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                                        Button(action: {
                                            engine.removeAllowedApp(bundleId: app.bundleIdentifier)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption)
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(app.isEnabled ? Color(hex: "#10B981").opacity(0.08) : Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(14)
                .background(Color.secondary.opacity(0.03))
                .cornerRadius(12)
            }
            .padding(24)
        }
        .onAppear {
            if discoveredApps.isEmpty {
                scanInstalledApps()
            }
        }
        .sheet(isPresented: $isShowingAddAppSheet) {
            allAppsLibrarySheet
        }
    }
    
    // MARK: - Hoja con Catálogo Completo de Todas las Apps de macOS
    private var allAppsLibrarySheet: some View {
        VStack(spacing: 16) {
            // Header del Sheet
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                        .font(.title3)
                    Text("Todas las Aplicaciones Instaladas en tu Mac")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Spacer()
                
                Button("Listo") {
                    isShowingAddAppSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Text("Selecciona cualquier aplicación para añadirla a tu Lista Blanca. Nunca será cerrada en ningún modo de enfoque.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Buscador del Sheet
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filtrar aplicaciones de tu Mac...", text: $sheetSearchText)
                    .textFieldStyle(.plain)
                if !sheetSearchText.isEmpty {
                    Button(action: { sheetSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            
            // Lista con Scroll de todas las aplicaciones
            if isLoadingApps {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Escaneando aplicaciones de tu Mac...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredSheetApps) { app in
                            let isAlreadyAllowed = engine.settings.allowedApps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier })
                            
                            HStack(spacing: 12) {
                                AppIconView(app: app, size: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.appName)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(app.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isAlreadyAllowed {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Permitida")
                                    }
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color(hex: "#10B981"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "#10B981").opacity(0.12))
                                    .cornerRadius(6)
                                } else {
                                    Button(action: {
                                        engine.addAllowedApp(app: app)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("Permitir")
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(Color(hex: "#10B981"))
                                    .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isAlreadyAllowed ? Color(hex: "#10B981").opacity(0.06) : Color.secondary.opacity(0.04))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .frame(width: 540, height: 480)
    }
    
    private var filteredAllowedApps: [BlockedApp] {
        if appSearchText.isEmpty {
            return engine.settings.allowedApps
        }
        return engine.settings.allowedApps.filter {
            $0.appName.localizedCaseInsensitiveContains(appSearchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(appSearchText)
        }
    }
    
    private var filteredSheetApps: [BlockedApp] {
        if sheetSearchText.isEmpty {
            return discoveredApps
        }
        return discoveredApps.filter {
            $0.appName.localizedCaseInsensitiveContains(sheetSearchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(sheetSearchText)
        }
    }
    
    private var availableDiscoveredApps: [BlockedApp] {
        let configuredIds = Set(engine.settings.allowedApps.map { $0.bundleIdentifier })
        return discoveredApps.filter { app in
            !configuredIds.contains(app.bundleIdentifier) &&
            (!appSearchText.isEmpty && app.appName.localizedCaseInsensitiveContains(appSearchText))
        }
    }
    
    private func addSingleAllowedWeb() {
        engine.addAllowedWebsite(domain: singleWebDomain, name: singleWebName)
        singleWebDomain = ""
        singleWebName = ""
    }
    
    private func processBatchAllowedWebs() {
        engine.processBatchAllowedWebsites(text: batchWebText)
        batchWebText = ""
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
