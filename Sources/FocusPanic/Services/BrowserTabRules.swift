import Foundation

/// Reglas de bloqueo de pestañas evaluadas en Swift.
///
/// Antes estas comprobaciones vivían dentro de un AppleScript que se compilaba
/// y ejecutaba entero cada 0,85 s por navegador. Los `contains` de AppleScript
/// ignoran mayúsculas con comparaciones Unicode (ICU) y, con el escudo de
/// adultos, además se leía el texto completo de TODAS las pestañas en cada
/// pasada: cada ciclo tardaba segundos y FocusPanic quedaba a ~95 % de CPU.
///
/// Ahora AppleScript solo LEE las pestañas (URL y título) y solo ESCRIBE para
/// redirigir una pestaña bloqueada; toda la lógica está aquí y reproduce la
/// semántica del script anterior (incluida la insensibilidad a mayúsculas).
public struct BrowserTabRules {
    public enum Mode { case rules, whitelist }

    public struct Decision: Equatable {
        /// Texto que se muestra en la página de intervención (`?site=`).
        public let label: String
        /// Lo que se notifica y se registra en estadísticas.
        public let reported: String
    }

    public let mode: Mode
    public let allowed: [String]
    public let blocked: [String]
    public let keywords: [String]
    public let isTeraBoxStrict: Bool
    private let blockedIndex: DomainIndex
    private let keywordIndex: KeywordIndex
    /// Decisiones ya calculadas por (URL, título). Las reglas son inmutables y
    /// `evaluate` es pura, así que una pestaña que no cambió entre pasadas
    /// (lo normal) no se vuelve a evaluar. Al cambiar los ajustes se crean
    /// reglas nuevas y con ellas una caché vacía.
    private let decisionCache = DecisionCache()

    public static let interventionBase = "http://127.0.0.1:8484/?site="

    /// Firmas de TeraBox en URL y título (mismas que el AppleScript anterior).
    static let teraBoxTitleSignatures: [String] = [
        "terabox", "teraboz", "teraboc", "teraz", "terboz", "terbox", "teravox", "terrabox",
        "terraboz", "terraboc", "1024tera", "freeterabox", "terashare", "terafileshare",
        "teradownload", "teraboxdl", "teradl", "tibibox", "4funbox", "mirrobox", "nephobox",
        "teraboxapp", "teraboxlink", "momerybox", "boxtera", "flowvideoplayer",
        "tera box", "tera boz", "tera boc", "tera z",
    ]

    /// Firmas buscadas en el TEXTO de la página (solo Safari puede leerlo).
    static let teraBoxPageTextSignatures: [String] = [
        "terabox", "teraboz", "teraboc", "1024tera", "freeterabox", "terashare",
        "teraboxdl", "terabox.com",
    ]

    /// Dominios que se comparan también como "instancia" (sin exigir el punto).
    static let instanceItems: Set<String> = [
        "terabox", "1024tera", "4funbox", "mirrobox", "nephobox", "freeterabox", "tibibox",
        "redlib", "libreddit", "teddit", "nitter", "proxitok", "invidious", "piped",
    ]

    /// Separadores de palabras del filtro de palabras clave.
    static let keywordDelimiters: [String] = [
        "%20", " ", "+", "-", "_", "/", "?", "=", "&", ".", ",", ":", ";", "(", ")", "[", "]",
        "'", "\"", "!", "@", "#", "$", "%", "^", "*", "~", "`", "<", ">", "|", "\\",
    ]

    /// Los separadores de un solo carácter, para normalizar en una pasada.
    static let delimiterScalars: Set<Unicode.Scalar> = Set(
        keywordDelimiters.filter { $0.unicodeScalars.count == 1 }.map { $0.unicodeScalars.first! }
    )

    public init(mode: Mode, allowed: [String], blocked: [String], keywords: [String], isTeraBoxStrict: Bool) {
        self.mode = mode
        self.allowed = allowed.map { $0.lowercased() }.filter { !$0.isEmpty }
        let allowedSet = Set(self.allowed)
        self.blocked = blocked
            .map { $0.replacingOccurrences(of: "www.", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !allowedSet.contains($0) }
        self.keywords = keywords.map { $0.lowercased() }.filter { !$0.isEmpty }
        self.keywordIndex = KeywordIndex(keywords: self.keywords)
        self.isTeraBoxStrict = isTeraBoxStrict
        self.blockedIndex = DomainIndex(items: self.blocked) { item in
            item.contains("terabox") || Self.instanceItems.contains(item) || !item.contains(".")
        }
    }

    // MARK: - Qué pestañas se revisan

    /// Pestañas internas del navegador o de la propia intervención: nunca se tocan.
    public static func shouldInspect(url: String, isSafariLike: Bool) -> Bool {
        let lower = url.lowercased()
        guard !lower.isEmpty, lower != "missing value" else { return false }
        if isSafariLike {
            if lower.hasPrefix("about:") || lower.hasPrefix("favorites://") || lower.hasPrefix("topsites://") { return false }
        } else {
            if lower.hasPrefix("chrome://") || lower.hasPrefix("edge://") || lower.hasPrefix("brave://") || lower.hasPrefix("file://") { return false }
        }
        if lower.contains("127.0.0.1:8484") || lower.contains("localhost:8484") { return false }
        if lower.hasPrefix("http://127.0.0.1") || lower.hasPrefix("http://localhost") { return false }
        return true
    }

    // MARK: - Decisión por pestaña

    /// Decide si una pestaña se bloquea mirando su URL y título.
    public func evaluate(url: String, title: String) -> Decision? {
        decisionCache.value(url: url, title: title) { evaluateUncached(url: url, title: title) }
    }

    func evaluateUncached(url: String, title: String) -> Decision? {
        let lowerURL = url.lowercased()
        let lowerTitle = title.lowercased()

        if isTeraBoxStrict && Self.matchesTeraBox(url: lowerURL, title: lowerTitle) {
            return Decision(label: "TeraBox Detectado", reported: "TeraBox Detectado")
        }

        switch mode {
        case .rules:
            if let kw = keywordIndex.firstMatch(normalized: Self.normalizedWords(lowerTitle + " " + lowerURL)) {
                let label = "Búsqueda: \(kw)"
                return Decision(label: label, reported: label)
            }
            if allowed.contains(where: { Self.matchesDomain(url: lowerURL, item: $0, includeInstances: true) }) {
                return nil
            }
            if let hit = blockedIndex.firstMatch(in: lowerURL, where: { Self.matchesDomain(url: lowerURL, item: $0, includeInstances: true) }) {
                return Decision(label: hit, reported: hit)
            }
            return nil
        case .whitelist:
            if allowed.contains(where: { Self.matchesDomain(url: lowerURL, item: $0, includeInstances: false) }) {
                return nil
            }
            let host = URL(string: url)?.host ?? url
            return Decision(label: "bloqueo-total", reported: host)
        }
    }

    /// Comprobación del texto de la página (TeraBox en resultados de búsqueda).
    public func evaluatePageText(_ text: String) -> Decision? {
        guard isTeraBoxStrict, !text.isEmpty else { return nil }
        let lower = text.lowercased()
        guard Self.teraBoxPageTextSignatures.contains(where: { lower.contains($0) }) else { return nil }
        return Decision(label: "TeraBox en Resultados", reported: "TeraBox en Resultados")
    }

    public static func interventionURL(for decision: Decision) -> String {
        interventionBase + decision.label.replacingOccurrences(of: " ", with: "%20")
    }

    // MARK: - Coincidencias (misma semántica que el AppleScript anterior)

    static func matchesTeraBox(url: String, title: String) -> Bool {
        let combined = url + " " + title
        return teraBoxTitleSignatures.contains(where: { combined.contains($0) })
    }

    /// Palabra completa: título y URL se parten por los separadores y se busca
    /// " palabra " (también frases de varias palabras).
    /// Comprobación original, una palabra clave cada vez. Ya no se usa en la
    /// app (ver `KeywordIndex`); los tests la usan como referencia.
    static func matchesKeyword(url: String, title: String, keyword: String) -> Bool {
        " \(normalizedWordsReference(title + " " + url)) ".contains(" \(keyword) ")
    }

    /// Cambia cada separador por un espacio en UNA pasada (antes: 33 pasadas de
    /// `replacingOccurrences`, una por separador). `%20` se trata primero, igual
    /// que en la versión anterior, que lo reemplazaba antes que `%`.
    static func normalizedWords(_ text: String) -> String {
        let scalars = Array(text.unicodeScalars)
        var result = String.UnicodeScalarView()
        result.reserveCapacity(scalars.count)
        var i = 0
        while i < scalars.count {
            let scalar = scalars[i]
            if scalar == "%" && i + 2 < scalars.count && scalars[i + 1] == "2" && scalars[i + 2] == "0" {
                result.append(" ")
                i += 3
                continue
            }
            result.append(delimiterScalars.contains(scalar) ? " " : scalar)
            i += 1
        }
        return String(result)
    }

    /// Versión anterior de `normalizedWords`; solo la usan los tests para
    /// comprobar que la nueva da exactamente lo mismo.
    static func normalizedWordsReference(_ text: String) -> String {
        var result = text
        for delimiter in keywordDelimiters {
            result = result.replacingOccurrences(of: delimiter, with: " ")
        }
        return result
    }

    static func matchesDomain(url: String, item: String, includeInstances: Bool) -> Bool {
        if includeInstances {
            if url.contains("accounts.youtube.com") || url.contains("accounts.google.com") { return false }
            if item.contains("terabox") || instanceItems.contains(item) || !item.contains(".") {
                if url.contains(item) { return true }
            }
        }
        if url.contains("://\(item)/") || url.contains("://\(item)?") || url.contains("://\(item)#")
            || url.hasSuffix("://\(item)") || url.contains(".\(item)/") || url.contains(".\(item)?")
            || url.contains(".\(item)#") || url.hasSuffix(".\(item)") || url.contains("//\(item)/")
            || url == item {
            return true
        }
        if includeInstances && (url.contains("://\(item).") || url.contains(".\(item).")) {
            return true
        }
        return false
    }
}

/// Índice para comparar una URL contra listas grandes de dominios (el escudo
/// de adultos aporta ~1.200) sin recorrerlas enteras.
///
/// Todas las formas de coincidencia "con límites" exigen que el dominio
/// aparezca justo después de `/` o `.` (o al inicio) y justo antes de `/`,
/// `?`, `#`, `.` o el final. Así que se extraen de la URL esos fragmentos
/// (pocas decenas) y se buscan en un `Set`; cada candidato se confirma con la
/// función de coincidencia original, de modo que el resultado es idéntico al
/// recorrido completo, incluido el orden (gana el primero de la lista).
/// Los elementos que pueden coincidir "en cualquier parte" (instancias, sin
/// punto, rutas) se comprueban siempre de forma lineal: son pocos.
public struct DomainIndex {
    private let items: [String]
    private let positions: [String: Int]
    private let linear: [Int]

    private static let domainBytes: Set<UInt8> = Set("abcdefghijklmnopqrstuvwxyz0123456789.-_".utf8)
    private static let startBoundary: Set<UInt8> = Set("/.".utf8)
    private static let endBoundary: Set<UInt8> = Set("/?#.".utf8)

    public init(items: [String], needsLinear: (String) -> Bool) {
        self.items = items
        var positions: [String: Int] = [:]
        var linear: [Int] = []
        for (index, item) in items.enumerated() {
            let plainDomain = !item.isEmpty && item.utf8.allSatisfy { Self.domainBytes.contains($0) }
            if !plainDomain || needsLinear(item) {
                linear.append(index)
            } else if positions[item] == nil {
                positions[item] = index
            }
        }
        self.positions = positions
        self.linear = linear
    }

    public var isEmpty: Bool { items.isEmpty }

    /// Primer elemento (en el orden de la lista) para el que `matches` es cierto.
    /// Requisito: `matches(item)` solo puede ser cierto si la URL CONTIENE el
    /// elemento (así es en ambas funciones de coincidencia); por eso los
    /// elementos lineales se descartan antes con una sola búsqueda.
    public func firstMatch(in lowerURL: String, where matches: (String) -> Bool) -> String? {
        guard !items.isEmpty else { return nil }
        var candidates = Set(linear.filter { lowerURL.contains(items[$0]) })
        let bytes = Array(lowerURL.utf8)
        let count = bytes.count
        for start in 0..<count where start == 0 || Self.startBoundary.contains(bytes[start - 1]) {
            var end = start
            while end < count, end - start < 253, Self.domainBytes.contains(bytes[end]) {
                end += 1
                if end == count || Self.endBoundary.contains(bytes[end]) {
                    if let fragment = String(bytes: bytes[start..<end], encoding: .utf8),
                       let index = positions[fragment] {
                        candidates.insert(index)
                    }
                }
            }
        }
        for index in candidates.sorted() where matches(items[index]) {
            return items[index]
        }
        return nil
    }
}

/// Búsqueda de palabras clave sobre un texto ya normalizado, con la misma
/// semántica que `" \(texto) ".contains(" \(palabra) ")` y respetando el orden
/// de la lista (gana la primera palabra clave que coincida).
///
/// Las palabras sueltas se buscan en un diccionario (O(1) por palabra del
/// texto) en vez de recorrer el texto una vez por palabra clave; las frases y
/// las palabras clave raras (con espacios en los bordes o separadores) siguen
/// el camino de `contains`, así que el resultado es idéntico.
struct KeywordIndex {
    /// Palabra suelta → su posición en la lista original (la primera si se repite).
    private let wordPositions: [String: Int]
    /// El resto, con su posición, en orden.
    private let phrases: [(position: Int, keyword: String)]
    private let keywords: [String]

    init(keywords: [String]) {
        self.keywords = keywords
        var words: [String: Int] = [:]
        var phrases: [(Int, String)] = []
        for (position, keyword) in keywords.enumerated() {
            let isSingleWord = !keyword.isEmpty
                && !keyword.unicodeScalars.contains { BrowserTabRules.delimiterScalars.contains($0) }
            if isSingleWord {
                if words[keyword] == nil { words[keyword] = position }
            } else {
                phrases.append((position, keyword))
            }
        }
        self.wordPositions = words
        self.phrases = phrases
    }

    func firstMatch(normalized: String) -> String? {
        guard !keywords.isEmpty else { return nil }
        var best = Int.max
        if !wordPositions.isEmpty {
            for word in normalized.split(separator: " ", omittingEmptySubsequences: true) {
                if let position = wordPositions[String(word)], position < best { best = position }
            }
        }
        if !phrases.isEmpty {
            let padded = " \(normalized) "
            for phrase in phrases where phrase.position < best {
                if padded.contains(" \(phrase.keyword) ") {
                    best = phrase.position
                    break
                }
            }
        }
        return best == Int.max ? nil : keywords[best]
    }
}

/// Caché de decisiones de `BrowserTabRules.evaluate` por (URL, título).
/// Se vacía entera si crece demasiado (muchas pestañas distintas a lo largo
/// del día); volver a calcular una entrada cuesta poco.
final class DecisionCache {
    private struct Key: Hashable { let url: String; let title: String }
    private var entries: [Key: BrowserTabRules.Decision?] = [:]
    private let lock = NSLock()
    private let limit = 2_000

    func value(url: String, title: String, compute: () -> BrowserTabRules.Decision?) -> BrowserTabRules.Decision? {
        let key = Key(url: url, title: title)
        lock.lock()
        if let cached = entries[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let decision = compute()
        lock.lock()
        if entries.count >= limit { entries.removeAll(keepingCapacity: true) }
        entries[key] = decision
        lock.unlock()
        return decision
    }
}
