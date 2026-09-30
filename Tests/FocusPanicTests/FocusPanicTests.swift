import XCTest
@testable import FocusPanic

final class FocusPanicTests: XCTestCase {
    
    func testFocusSessionCalculation() {
        let session = FocusSession(durationMinutes: 25, presetName: "Pomodoro TDAH")
        XCTAssertEqual(session.originalDurationSeconds, 1500)
        XCTAssertFalse(session.isFinished)
        XCTAssertGreaterThan(session.remainingSeconds, 0)
    }
    
    func testEmergencyCodeGenerator() {
        let code = EmailService.shared.generateEmergencyCode()
        XCTAssertEqual(code.count, 6)
        XCTAssertNotNil(Int(code))
    }
    
    func testDefaultPresetsAvailability() {
        let presets = FocusPreset.defaultPresets
        XCTAssertGreaterThanOrEqual(presets.count, 4)
        XCTAssertTrue(presets.contains { $0.durationMinutes == 25 })
    }
    
    func testTeraBoxStrictSignatureMatching() {
        // Consultas de búsqueda en buscadores
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=terabox"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("terabox - Buscar con Google"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://duckduckgo.com/?q=terabox+video"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("Descargar archivo de 1024tera"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://ejemplo.com/ver?url=freeterabox"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("Ver con flowvideoplayer"))
        
        // Evasiones fonéticas y errores ortográficos intencionales (teraboz, teraz, teraboc, terboz, tera box)
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=teraboz"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=teraz"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=teraboc"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=terboz"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=tera+box"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("https://www.google.com/search?q=tera+boz"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("teraboz - Buscar con Google"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("teraz - Buscar con Google"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("teraboc - Buscar con Google"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("También se muestran resultados de terabox"))
        XCTAssertTrue(AdultBlockListProvider.containsTeraBoxSignature("TeraBox: Free 1TB(1024GB) Cloud Storage & File Storage"))
        
        // Falsos positivos no relacionados
        XCTAssertFalse(AdultBlockListProvider.containsTeraBoxSignature("https://apple.com/macos"))
        XCTAssertFalse(AdultBlockListProvider.containsTeraBoxSignature("Programación en Swift"))
    }
    
    func testDuckDuckGoInAlternativeSearchEngines() {
        XCTAssertTrue(AdultBlockListProvider.alternativeSearchEngines.contains("duckduckgo.com"))
        XCTAssertTrue(AdultBlockListProvider.alternativeSearchEngines.contains("duck.com"))
        XCTAssertTrue(AdultBlockListProvider.alternativeSearchEngines.contains("safe.duckduckgo.com"))
    }
    
    func testDuckDuckGoBrowserInBlockedBrowsers() {
        let bIds = AdultBlockListProvider.blockedBrowsers.map { $0.bundleIdentifier }
        XCTAssertTrue(bIds.contains("com.duckduckgo.macos.browser"))
        XCTAssertTrue(bIds.contains("com.duckduckgo.mobile.ios"))
    }
    
    func testFlowVideoPlayerInBlockedDomains() {
        XCTAssertTrue(AdultBlockListProvider.adultDomains.contains("flowvideoplayer.com"))
        XCTAssertTrue(AdultBlockListProvider.adultDomains.contains("www.flowvideoplayer.com"))
    }
    
    func testExplicitAdultKeywordsAndLatinActresses() {
        // Términos sexuales explícitos
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("follando"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("follar"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("tetas"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("culonas"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("cogiendo"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("mamada"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("onlyfans leaks"))
        
        // Actrices y creadoras de contenido para adultos de Colombia y Latinoamérica
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("esperanza gomez"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("amaranta hank"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("cintia cossio"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("karely ruiz"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("celia lora"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("diosa canales"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("la sirena 69"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("daniella chavez"))
        
        // Modelos de SexMex y búsquedas clandestinas de filtraciones
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("lesly medina"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("dulce caramelo"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("michelle rabbit"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("kourtney love"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("martina smith"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("sara blonde"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("jessica sodi"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("tatiana alvarez"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("salome gil"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("silvana lee"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("yorgeis carrillo"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("alisson mayer"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("elizabeth loaiza"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("onlyfans gratis"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("packs de famosas"))
        XCTAssertTrue(AdultBlockListProvider.adultKeywords.contains("pack telegram"))
    }
}
