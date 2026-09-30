import SwiftUI

public struct WebBlockListView: View {
    @ObservedObject var engine = FocusEngine.shared
    
    @State private var isAddingDomain = false
    @State private var addMode = 0 // 0: Individual, 1: En Lote
    
    // Individual
    @State private var newDomain = ""
    @State private var selectedCategory: WebsiteCategory = .custom
    
    // En Lote
    @State private var batchText = ""
    @State private var batchCategory: WebsiteCategory = .custom
    
    // Filtros y búsqueda
    @State private var searchText = ""
    @State private var selectedCategoryFilter: WebsiteCategory? = nil
    @State private var expandedCategories: Set<WebsiteCategory> = []
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cabecera
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("webblock.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    let activeCount = engine.settings.blockedWebsites.filter { $0.isEnabled }.count
                    if engine.settings.isAlwaysBlockAdultSites {
                        Text(String(format: L10n.tr("webblock.subtitle.withAdult"), activeCount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: L10n.tr("webblock.subtitle.normal"), activeCount))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isAddingDomain.toggle()
                    }
                }) {
                    Label(isAddingDomain ? L10n.tr("common.hide") : L10n.tr("webblock.btn.add"), systemImage: isAddingDomain ? "chevron.up" : "plus")
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.trailing, 36) // Espacio para el botón X de la esquina
            
            // Panel de añadir sitios (Individual o Lote)
            if isAddingDomain {
                addWebsitesCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Barra de búsqueda y filtro con altura y alineación homogénea
            HStack(spacing: 10) {
                // 1. Campo de Búsqueda
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(L10n.tr("webblock.search.placeholder"), text: $searchText)
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
                
                // 2. Selector de Categoría (con fondo y altura idéntica)
                HStack(spacing: 6) {
                    Text(L10n.tr("webblock.category"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $selectedCategoryFilter) {
                        Text(L10n.tr("common.all")).tag(WebsiteCategory?.none)
                        ForEach(WebsiteCategory.allCases) { cat in
                            Text(cat.localizedName).tag(WebsiteCategory?.some(cat))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                .frame(height: 32)
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                
                // 3. Botón Desactivar / Activar Todos (con fondo y altura idéntica)
                let allEnabled = engine.settings.blockedWebsites.allSatisfy { $0.isEnabled }
                Button(action: {
                    engine.toggleAllWebsites(enabled: !allEnabled)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: allEnabled ? "xmark.circle" : "checkmark.circle")
                        Text(allEnabled ? L10n.tr("common.disableAll") : L10n.tr("common.enableAll"))
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
            
            // Listado de Sitios Web con ScrollView y LazyVStack de Ultra-Alto Rendimiento (Sin Lag)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(visibleCategories) { category in
                        let items = filteredItems(for: category)
                        if !items.isEmpty {
                            let isExpanded = expandedCategories.contains(category) || items.count <= 10
                            let displayedItems = isExpanded ? items : Array(items.prefix(10))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                categoryHeader(category: category, items: items)
                                
                                VStack(spacing: 4) {
                                    ForEach(displayedItems) { site in
                                        siteRow(site: site)
                                    }
                                }
                                .padding(8)
                                .background(Color.secondary.opacity(0.04))
                                .cornerRadius(10)
                                
                                if items.count > 10 {
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            if expandedCategories.contains(category) {
                                                expandedCategories.remove(category)
                                            } else {
                                                expandedCategories.insert(category)
                                            }
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                            Text(isExpanded
                                                 ? (LocalizationService.shared.currentLanguage == .english ? "Show less" : "Ver menos sitios")
                                                 : (LocalizationService.shared.currentLanguage == .english ? "Show more (\(items.count - 10) additional)" : "Ver más sitios (\(items.count - 10) adicionales)"))
                                        }
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: category.colorHex))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: category.colorHex).opacity(0.08))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Pie de página
            HStack {
                Button(L10n.tr("webblock.reset.defaults")) {
                    engine.settings.blockedWebsites = AppSettings.defaultWebsites
                    engine.saveSettings()
                }
                .buttonStyle(.link)
                .foregroundColor(.secondary)
                .font(.caption)
                
                Spacer()
            }
        }
        .padding(20)
    }
    
    private var addWebsitesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $addMode) {
                Text(L10n.tr("webblock.add.single")).tag(0)
                Text(L10n.tr("webblock.add.batch")).tag(1)
            }
            .pickerStyle(.segmented)
            
            if addMode == 0 {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .foregroundColor(.secondary)
                            TextField(L10n.tr("webblock.add.single.placeholder"), text: $newDomain)
                                .textFieldStyle(.plain)
                                .onSubmit { saveSingleDomain() }
                        }
                        .frame(height: 32)
                        .padding(.horizontal, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 12) {
                        Picker(L10n.tr("webblock.category") + ":", selection: $selectedCategory) {
                            ForEach(WebsiteCategory.allCases) { cat in
                                Text(cat.localizedName).tag(cat)
                            }
                        }
                        .frame(width: 240)
                        
                        Spacer()
                        
                        Button(L10n.tr("common.cancel")) {
                            isAddingDomain = false
                            newDomain = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Button(L10n.tr("webblock.add.btn.block")) {
                            saveSingleDomain()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("webblock.add.batch.hint"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $batchText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 80)
                        .padding(4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    HStack {
                        Picker(L10n.tr("webblock.category") + ":", selection: $batchCategory) {
                            ForEach(WebsiteCategory.allCases) { cat in
                                Text(cat.localizedName).tag(cat)
                            }
                        }
                        .frame(width: 220)
                        
                        Spacer()
                        
                        Button(L10n.tr("common.cancel")) {
                            isAddingDomain = false
                            batchText = ""
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Button(L10n.tr("webblock.add.batch.btn")) {
                            processBatchDomains()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(batchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(12)
    }
    
    private var visibleCategories: [WebsiteCategory] {
        if let filter = selectedCategoryFilter {
            return [filter]
        }
        return WebsiteCategory.allCases
    }
    
    private func filteredItems(for category: WebsiteCategory) -> [BlockedWebsite] {
        engine.settings.blockedWebsites
            .filter { site in
                site.category == category &&
                (searchText.isEmpty ||
                 site.domain.localizedCaseInsensitiveContains(searchText) ||
                 site.name.localizedCaseInsensitiveContains(searchText))
            }
            .sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
    }
    
    private func categoryHeader(category: WebsiteCategory, items: [BlockedWebsite]) -> some View {
        HStack {
            Image(systemName: category.iconName)
                .foregroundColor(Color(hex: category.colorHex))
            Text(category.localizedName)
                .fontWeight(.bold)
            
            Text("(\(items.count))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            let allEnabled = items.allSatisfy { $0.isEnabled }
            Button(allEnabled ? L10n.tr("common.disableAll") : L10n.tr("common.enableAll")) {
                for item in items {
                    if let index = engine.settings.blockedWebsites.firstIndex(where: { $0.id == item.id }) {
                        engine.settings.blockedWebsites[index].isEnabled = !allEnabled
                    }
                }
                engine.saveSettings()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(Color(hex: category.colorHex))
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
    
    private func siteRow(site: BlockedWebsite) -> some View {
        HStack(spacing: 10) {
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
            
            Button(action: {
                engine.removeBlockedWebsite(id: site.id)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .help("Eliminar este sitio")
            
            Toggle("", isOn: Binding(
                get: { site.isEnabled },
                set: { newValue in
                    if let index = engine.settings.blockedWebsites.firstIndex(where: { $0.id == site.id }) {
                        engine.settings.blockedWebsites[index].isEnabled = newValue
                        engine.saveSettings()
                    }
                }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(site.isEnabled ? Color.clear : Color.secondary.opacity(0.02))
        .cornerRadius(6)
    }
    
    private func cleanDomainString(_ raw: String) -> String {
        var clean = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "https://", with: "")
        clean = clean.replacingOccurrences(of: "http://", with: "")
        clean = clean.replacingOccurrences(of: "www.", with: "")
        
        if let firstPart = clean.components(separatedBy: "/").first {
            clean = firstPart
        }
        return clean
    }
    
    private func saveSingleDomain() {
        let domain = cleanDomainString(newDomain)
        guard !domain.isEmpty else { return }
        
        let name = FocusEngine.cleanDomainToName(domain)
        
        if !engine.settings.blockedWebsites.contains(where: { $0.domain.lowercased() == domain }) {
            let newSite = BlockedWebsite(
                domain: domain,
                name: name,
                category: selectedCategory,
                isEnabled: true,
                isCustom: true
            )
            engine.settings.blockedWebsites.append(newSite)
            engine.saveSettings()
        }
        
        newDomain = ""
        isAddingDomain = false
    }
    
    private func processBatchDomains() {
        let rawItems = batchText.components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",;")))
        var addedCount = 0
        
        for raw in rawItems {
            let domain = cleanDomainString(raw)
            guard !domain.isEmpty && !domain.hasPrefix("#") && domain.contains(".") else {
                continue
            }
            
            if !engine.settings.blockedWebsites.contains(where: { $0.domain.lowercased() == domain }) {
                let newSite = BlockedWebsite(
                    domain: domain,
                    name: domain.capitalized,
                    category: batchCategory,
                    isEnabled: true,
                    isCustom: true
                )
                engine.settings.blockedWebsites.append(newSite)
                addedCount += 1
            }
        }
        
        if addedCount > 0 {
            engine.saveSettings()
        }
        
        batchText = ""
        isAddingDomain = false
    }
}
