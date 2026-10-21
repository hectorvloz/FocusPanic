import XCTest
@testable import FocusPanic

/// Las reglas en Swift deben decidir lo mismo que el AppleScript anterior.
final class BrowserTabRulesTests: XCTestCase {
    private func rules(
        _ mode: BrowserTabRules.Mode = .rules,
        allowed: [String] = ["github.com"],
        blocked: [String] = ["instagram.com", "www.reddit.com", "redlib"],
        keywords: [String] = ["porno", "porno casero"],
        teraBox: Bool = true
    ) -> BrowserTabRules {
        BrowserTabRules(mode: mode, allowed: allowed, blocked: blocked, keywords: keywords, isTeraBoxStrict: teraBox)
    }

    func testBlockedDomainsIncludingSubdomainsAndCase() {
        let r = rules()
        XCTAssertEqual(r.evaluate(url: "https://www.Instagram.com/explore", title: "Instagram")?.label, "instagram.com")
        XCTAssertEqual(r.evaluate(url: "https://old.reddit.com/r/x", title: "")?.label, "reddit.com")
        XCTAssertNil(r.evaluate(url: "https://notinstagram.company.com/", title: ""))
        XCTAssertNil(r.evaluate(url: "https://github.com/instagram.com", title: "repo"))
    }

    func testInstanceItemsMatchWithoutDot() {
        XCTAssertEqual(rules().evaluate(url: "https://redlib.example.org/r/a", title: "")?.label, "redlib")
    }

    func testKeywordsAreWholeWordsAndPhrases() {
        let r = rules()
        XCTAssertEqual(r.evaluate(url: "https://www.google.com/search?q=porno", title: "Google")?.label, "Búsqueda: porno")
        XCTAssertEqual(r.evaluate(url: "https://www.google.com/search?q=porno+casero", title: "")?.label, "Búsqueda: porno")
        XCTAssertNil(r.evaluate(url: "https://es.wikipedia.org/wiki/Pornografía_infantil_(ley)", title: "Wiki"))
        XCTAssertEqual(rules(keywords: ["porno casero"]).evaluate(url: "https://x.com/?q=porno%20casero", title: "")?.label, "Búsqueda: porno casero")
    }

    func testTeraBoxInUrlTitleAndPageText() {
        let r = rules()
        XCTAssertEqual(r.evaluate(url: "https://www.google.com/search?q=tera+box", title: "tera box - Buscar con Google")?.label, "TeraBox Detectado")
        XCTAssertEqual(r.evaluatePageText("Resultados: descarga en Terabox.com gratis")?.label, "TeraBox en Resultados")
        XCTAssertNil(rules(teraBox: false).evaluatePageText("terabox"))
    }

    func testWhitelistModeBlocksEverythingNotAllowed() {
        let r = rules(.whitelist)
        XCTAssertNil(r.evaluate(url: "https://github.com/hector", title: "GitHub"))
        let decision = r.evaluate(url: "https://www.youtube.com/watch?v=1", title: "YouTube")
        XCTAssertEqual(decision?.label, "bloqueo-total")
        XCTAssertEqual(decision?.reported, "www.youtube.com")
    }

    func testInternalPagesAreNeverTouched() {
        XCTAssertFalse(BrowserTabRules.shouldInspect(url: "http://127.0.0.1:8484/?site=x", isSafariLike: true))
        XCTAssertFalse(BrowserTabRules.shouldInspect(url: "favorites://", isSafariLike: true))
        XCTAssertFalse(BrowserTabRules.shouldInspect(url: "chrome://settings", isSafariLike: false))
        XCTAssertFalse(BrowserTabRules.shouldInspect(url: "", isSafariLike: false))
        XCTAssertTrue(BrowserTabRules.shouldInspect(url: "https://instagram.com", isSafariLike: true))
    }

    func testInterventionUrlEncodesSpaces() {
        let decision = BrowserTabRules.Decision(label: "Búsqueda: porno casero", reported: "x")
        XCTAssertEqual(BrowserTabRules.interventionURL(for: decision), "http://127.0.0.1:8484/?site=Búsqueda:%20porno%20casero")
    }
}

/// El índice debe dar exactamente lo mismo que recorrer la lista entera.
final class DomainIndexTests: XCTestCase {
    func testIndexMatchesLinearScanOnRealList() {
        let blocked = AdultBlockListProvider.adultDomains.map { $0.lowercased() }
            + ["instagram.com", "reddit.com", "redlib", "example.com/path", "tiktok"]
        let needsLinear: (String) -> Bool = { item in
            item.contains("terabox") || BrowserTabRules.instanceItems.contains(item) || !item.contains(".")
        }
        let index = DomainIndex(items: blocked, needsLinear: needsLinear)
        let urls = [
            "https://www.instagram.com/explore", "https://old.reddit.com/r/x?y=1", "https://redlib.foo.org/",
            "https://example.com/path/x", "https://www.tiktok.com/@a", "https://github.com/instagram.com",
            "https://www.google.com/url?q=https://instagram.com/", "https://instagram.com", "instagram.com",
            "https://notinstagram.com/", "https://instagram.com.evil.net/", "https://news.ycombinator.com/",
        ] + blocked.prefix(50).map { "https://www.\($0)/video" }
        for url in urls {
            let linear = blocked.first { BrowserTabRules.matchesDomain(url: url, item: $0, includeInstances: true) }
            let indexed = index.firstMatch(in: url) { BrowserTabRules.matchesDomain(url: url, item: $0, includeInstances: true) }
            XCTAssertEqual(indexed, linear, url)
        }
    }
}

final class TabListScriptTests: XCTestCase {
    /// Dentro de `tell application` la palabra `tab` es la clase pestaña: si se
    /// usa como separador, el script devuelve la palabra «tab» y no se
    /// reconoce ninguna pestaña (nada se bloquea).
    func testSeparatorIsTheTabCharacterNotTheTabClass() {
        for (app, safari) in [("Safari", true), ("Google Chrome", false)] {
            let source = BrowserWatchdogService.tabListScript(appName: app, isSafariLike: safari)
            XCTAssertTrue(source.contains("set sep to (character id 9)"))
            XCTAssertFalse(source.contains("& tab &"))
            XCTAssertFalse(source.contains("& tab\n"))
        }
    }

    /// El script real, compilado y ejecutado contra un navegador que no existe,
    /// no debe fallar al compilar.
    func testScriptCompiles() {
        let script = NSAppleScript(source: BrowserWatchdogService.tabListScript(appName: "Safari", isSafariLike: true))
        var error: NSDictionary?
        XCTAssertTrue(script?.compileAndReturnError(&error) == true, "\(String(describing: error))")
    }
}

/// La versión optimizada del filtro de palabras clave debe decidir EXACTAMENTE
/// lo mismo que la original (normalizar 33 veces por palabra clave).
final class KeywordOptimizationTests: XCTestCase {
    private static let alphabet: [Character] = Array("abcdeporno casero%20+-_/?=&.,:;()[]'\"!@#$^*~`<>|\\áéñü0123456789")

    private func randomText(_ rng: inout SystemRandomNumberGenerator, length: Int) -> String {
        String((0..<length).map { _ in Self.alphabet.randomElement(using: &rng)! })
    }

    func testSinglePassNormalizationMatchesReference() {
        var rng = SystemRandomNumberGenerator()
        let fixed = ["%20", "%%20", "%2", "%200", "a%20b%", "porno%20casero", "x--y..z", "", "%", "ñandú/(ley)"]
        for text in fixed {
            XCTAssertEqual(BrowserTabRules.normalizedWords(text), BrowserTabRules.normalizedWordsReference(text), text)
        }
        for _ in 0..<5_000 {
            let text = randomText(&rng, length: Int.random(in: 0...60, using: &rng))
            XCTAssertEqual(BrowserTabRules.normalizedWords(text), BrowserTabRules.normalizedWordsReference(text), text)
        }
    }

    func testKeywordIndexMatchesLinearScan() {
        var rng = SystemRandomNumberGenerator()
        let keywords = (AdultBlockListProvider.adultKeywords
            + ["porno", "porno casero", "casero", "porno ", " x", "a-b", "%20", "porno", "é"]).map { $0.lowercased() }
        let rules = BrowserTabRules(mode: .rules, allowed: [], blocked: [], keywords: keywords, isTeraBoxStrict: false)
        var cases: [(String, String)] = [
            ("https://www.google.com/search?q=porno+casero", "Google"),
            ("https://x.com/?q=porno%20casero", ""),
            ("https://es.wikipedia.org/wiki/Pornografía", "Wiki"),
            ("https://example.com/a-b", "porno  casero"),
        ]
        cases += (0..<400).map { _ in
            ("https://ex.com/?q=" + randomText(&rng, length: Int.random(in: 0...40, using: &rng)),
             randomText(&rng, length: Int.random(in: 0...30, using: &rng)))
        }
        cases += keywords.prefix(200).map { ("https://www.google.com/search?q=\($0.replacingOccurrences(of: " ", with: "+"))", "") }
        for (url, title) in cases {
            let expected = rules.keywords.first {
                BrowserTabRules.matchesKeyword(url: url.lowercased(), title: title.lowercased(), keyword: $0)
            }
            let decision = rules.evaluateUncached(url: url, title: title)
            XCTAssertEqual(decision?.label, expected.map { "Búsqueda: \($0)" }, "\(url) | \(title)")
        }
    }

    func testCachedDecisionEqualsUncached() {
        let rules = BrowserTabRules(mode: .rules, allowed: ["github.com"], blocked: ["instagram.com"],
                                    keywords: ["porno"], isTeraBoxStrict: true)
        for (url, title) in [("https://instagram.com/", "IG"), ("https://github.com/", "GH"),
                             ("https://google.com/?q=porno", ""), ("https://google.com/?q=terabox", "")] {
            let first = rules.evaluate(url: url, title: title)
            XCTAssertEqual(first, rules.evaluateUncached(url: url, title: title))
            XCTAssertEqual(rules.evaluate(url: url, title: title), first)
        }
    }

    /// Una pasada realista: 50 pestañas con la lista completa de palabras
    /// clave y de dominios del escudo de adultos. Con la versión anterior
    /// (build de depuración) tardaba ~3,8 s; ahora ~0,08 s.
    func testPerformanceOfFullPass() {
        let rules = BrowserTabRules(mode: .rules, allowed: ["github.com"],
                                    blocked: AdultBlockListProvider.adultDomains,
                                    keywords: AdultBlockListProvider.adultKeywords, isTeraBoxStrict: true)
        let tabs = (0..<50).map { ("https://www.example\($0).com/articulo/\($0)?q=algo+de+texto&page=\($0)",
                                   "Un título de página bastante normal número \($0) - Sitio") }
        measure {
            for (url, title) in tabs { _ = rules.evaluateUncached(url: url, title: title) }
        }
    }
}

/// La lectura única de pestañas también trae las ventanas privadas y la
/// pestaña activa (antes eran AppleScripts aparte).
final class TabSnapshotTests: XCTestCase {
    func testParsesPrivateWindowsAndActiveTab() {
        let raw = "ACTIVE\t2\nPRIVATE\t3\n1\t1\thttps://a.com\tA\n1\t2\thttps://instagram.com/\tIG\n3\t1\thttps://p.com\tP\n"
        let snapshot = BrowserWatchdogService.parseTabList(raw)
        XCTAssertEqual(snapshot.tabs.count, 3)
        XCTAssertEqual(snapshot.incognitoWindows, [3])
        XCTAssertEqual(snapshot.activeTabURL, "https://instagram.com/")
        XCTAssertNil(BrowserWatchdogService.parseTabList("1\t1\thttps://a.com\tA\n").activeTabURL)
    }

    /// Compilar el script de Chrome necesita Chrome instalado; aquí solo se
    /// comprueba que pregunte por el modo incógnito de cada ventana.
    func testScriptsAskForPrivateWindows() {
        XCTAssertTrue(BrowserWatchdogService.tabListScript(appName: "Google Chrome", isSafariLike: false)
            .contains("if (mode of window wi) is \"incognito\" then set out to out & \"PRIVATE\""))
        XCTAssertTrue(BrowserWatchdogService.tabListScript(appName: "Safari", isSafariLike: true)
            .contains("if («class pmnd» of window wi) is true then set out to out & \"PRIVATE\""))
    }
}
