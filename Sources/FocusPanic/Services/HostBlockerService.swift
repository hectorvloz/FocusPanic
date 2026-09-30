import AppKit
import Foundation

public final class HostBlockerService {
    public static let shared = HostBlockerService()
    
    private let hostsFilePath = "/etc/hosts"
    private let beginTag = "# >>> BEGIN FOCUSPANIC BLOCK"
    private let endTag = "# <<< END FOCUSPANIC BLOCK"
    private let helperPath = "/usr/local/bin/focuspanic-helper"
    
    // Resolvers DoH y servidores de Apple Private Relay para forzar resolución local del sistema
    private let dohResolvers = [
        "dns.google", "dns.google.com",
        "cloudflare-dns.com", "one.one.one.one",
        "dns.quad9.net", "doh.opendns.com",
        // Apple iCloud Private Relay (al bloquear estos, Safari respeta /etc/hosts 100%)
        "mask.icloud.com", "mask-h2.icloud.com", "mask-api.icloud.com",
        "mask-t.apple-dns.net", "mask.apple-dns.net"
    ]
    
    private init() {}
    
    public var isHelperInstalled: Bool {
        return FileManager.default.fileExists(atPath: helperPath)
    }
    
    public func isCurrentlyBlocking() -> Bool {
        guard let content = try? String(contentsOfFile: hostsFilePath, encoding: .utf8) else { return false }
        return content.contains(beginTag) && content.contains(endTag)
    }
    
    /// Instalar helper + sudoers UNA SOLA VEZ
    public func installHelper() throws {
        let helperContent = """
        #!/bin/bash
        ACTION="$1"
        HOSTS="/etc/hosts"
        case "$ACTION" in
            apply)
                if [ -f "$2" ]; then
                    cp -f "$2" "$HOSTS"
                    chmod 644 "$HOSTS"
                    networksetup -listallnetworkservices 2>/dev/null | grep -v '^\\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
                        [ -n "$iface" ] && networksetup -setdnsservers "$iface" 1.1.1.3 1.0.0.3 2606:4700:4700::1113 2606:4700:4700::1003 2>/dev/null || true
                    done
                    killall -HUP mDNSResponder 2>/dev/null || true
                    dscacheutil -flushcache 2>/dev/null || true
                    rm -f "$2"
                    echo "OK"
                else
                    echo "ERROR" && exit 1
                fi
                ;;
            apply-family-dns)
                networksetup -listallnetworkservices 2>/dev/null | grep -v '^\\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
                    [ -n "$iface" ] && networksetup -setdnsservers "$iface" 1.1.1.3 1.0.0.3 2606:4700:4700::1113 2606:4700:4700::1003 2>/dev/null || true
                done
                killall -HUP mDNSResponder 2>/dev/null || true
                dscacheutil -flushcache 2>/dev/null || true
                echo "OK"
                ;;
            remove)
                if grep -q "BEGIN FOCUSPANIC" "$HOSTS"; then
                    sed -i '' '/# >>> BEGIN FOCUSPANIC BLOCK/,/# <<< END FOCUSPANIC BLOCK/d' "$HOSTS"
                    chmod 644 "$HOSTS"
                fi
                networksetup -listallnetworkservices 2>/dev/null | grep -v '^\\*' | grep -v 'An asterisk' | while IFS= read -r iface; do
                    [ -n "$iface" ] && networksetup -setdnsservers "$iface" "Empty" 2>/dev/null || true
                done
                killall -HUP mDNSResponder 2>/dev/null || true
                dscacheutil -flushcache 2>/dev/null || true
                echo "OK"
                ;;
            flush)
                killall -HUP mDNSResponder 2>/dev/null || true
                dscacheutil -flushcache 2>/dev/null || true
                echo "OK"
                ;;
            *)
                echo "Usage: focuspanic-helper {apply|apply-family-dns|remove|flush} [file]"; exit 1;;
        esac
        """
        
        let tempHelper = "/tmp/focuspanic-helper-install.sh"
        try helperContent.write(toFile: tempHelper, atomically: true, encoding: String.Encoding.utf8)
        
        let username = NSUserName()
        let installCmd = "cp -f '\(tempHelper)' /usr/local/bin/focuspanic-helper && chmod 755 /usr/local/bin/focuspanic-helper && echo '\(username) ALL=(ALL) NOPASSWD: /usr/local/bin/focuspanic-helper' > /etc/sudoers.d/focuspanic && chmod 0440 /etc/sudoers.d/focuspanic && rm -f '\(tempHelper)'"
        
        let escapedCmd = installCmd.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCmd)\" with administrator privileges with prompt \"FocusPanic: Configuración única de permisos.\""
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Permisos denegados."
                throw NSError(domain: "FocusPanic", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
        
        let testSuccess = runHelper(args: ["flush"])
        if !testSuccess {
            throw NSError(domain: "FocusPanic", code: 2, userInfo: [NSLocalizedDescriptionKey: "Error al verificar el ayudante de bloqueo."])
        }
    }
    
    // MARK: - Bloqueo con Expansión Exhaustiva de Subdominios y CDNs + SafeSearch
    
    public func applyBlock(domains: [String], allowedDomains: [String] = [], forceSafeSearch: Bool = true) throws {
        let currentContent = (try? String(contentsOfFile: hostsFilePath, encoding: .utf8)) ?? ""
        let cleanedContent = removeBlockSection(from: currentContent)
        
        var allDomains = Set<String>()
        
        func matchesBase(_ clean: String, _ base: String) -> Bool {
            return clean == base || clean == "www.\(base)" || clean.hasSuffix(".\(base)")
        }
        
        for domain in domains {
            let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty && !clean.hasPrefix("#") else { continue }
            
            allDomains.insert(clean)
            
            // Subdominios genéricos estándar
            if !clean.hasPrefix("www.") { allDomains.insert("www.\(clean)") }
            if !clean.hasPrefix("m.") { allDomains.insert("m.\(clean)") }
            if !clean.hasPrefix("mobile.") { allDomains.insert("mobile.\(clean)") }
            if !clean.hasPrefix("web.") { allDomains.insert("web.\(clean)") }
            if !clean.hasPrefix("api.") { allDomains.insert("api.\(clean)") }
            if !clean.hasPrefix("l.") { allDomains.insert("l.\(clean)") }
            
            // Expansión especializada para plataformas complejas (con coincidencia exacta de dominio)
            if matchesBase(clean, "tiktok.com") || clean == "tiktok" {
                let tiktokHosts = [
                    "tiktok.com", "www.tiktok.com", "m.tiktok.com", "t.tiktok.com",
                    "web.tiktok.com", "api.tiktok.com", "mobile.tiktok.com",
                    "v16-web.tiktok.com", "v16a.tiktok.com", "v19-web.tiktok.com",
                    "tiktokcdn.com", "www.tiktokcdn.com", "v16-web.tiktokcdn.com",
                    "v16a.tiktokcdn.com", "v19-web.tiktokcdn.com", "p16-sign-va.tiktokcdn.com",
                    "p16-sign.tiktokcdn.com", "p16-va.tiktokcdn.com", "p16.tiktokcdn.com",
                    "p16-tiktokcdn-com.akamaized.net", "sf16-website-login.neutral.ttwstatic.com",
                    "byteoversea.com", "www.byteoversea.com", "byteoversea.net",
                    "ibyteimg.com", "ibytedtos.com", "muscdn.com", "musical.ly",
                    "tiktokv.com", "tiktokcdn-us.com", "ttwstatic.com", "sgsnssdk.com",
                    "isnssdk.com", "bytedance.com", "byteimg.com", "bytefcdn.com",
                    "ttlivecdn.com", "pull-f3.tiktokcdn.com", "pull-f5.tiktokcdn.com"
                ]
                for th in tiktokHosts { allDomains.insert(th) }
            } else if matchesBase(clean, "facebook.com") || matchesBase(clean, "fb.com") || clean == "facebook" {
                let fbHosts = [
                    "facebook.com", "www.facebook.com", "m.facebook.com", "web.facebook.com",
                    "l.facebook.com", "touch.facebook.com", "graph.facebook.com", "edge-chat.facebook.com",
                    "connect.facebook.net", "fbcdn.net", "static.xx.fbcdn.net", "scontent.xx.fbcdn.net",
                    "fb.com", "www.fb.com", "messenger.com", "www.messenger.com"
                ]
                for fh in fbHosts { allDomains.insert(fh) }
            } else if matchesBase(clean, "instagram.com") || clean == "instagram" {
                let igHosts = [
                    "instagram.com", "www.instagram.com", "m.instagram.com", "api.instagram.com",
                    "i.instagram.com", "graph.instagram.com", "cdninstagram.com", "www.cdninstagram.com",
                    "scontent.cdninstagram.com", "threads.net", "www.threads.net"
                ]
                for ih in igHosts { allDomains.insert(ih) }
            } else if matchesBase(clean, "youtube.com") || matchesBase(clean, "youtu.be") || clean == "youtube" {
                let ytHosts = [
                    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
                    "ytimg.com", "i.ytimg.com", "googlevideo.com", "youtubei.googleapis.com",
                    "yt3.ggpht.com"
                ]
                for yh in ytHosts { allDomains.insert(yh) }
            } else if matchesBase(clean, "twitter.com") || matchesBase(clean, "x.com") || clean == "twitter" {
                let xHosts = [
                    "twitter.com", "www.twitter.com", "mobile.twitter.com", "api.twitter.com",
                    "x.com", "www.x.com", "api.x.com", "twimg.com", "pbs.twimg.com"
                ]
                for xh in xHosts { allDomains.insert(xh) }
            } else if matchesBase(clean, "reddit.com") || clean == "reddit" {
                let rHosts = [
                    "reddit.com", "www.reddit.com", "old.reddit.com", "oauth.reddit.com",
                    "gql.reddit.com", "redditstatic.com", "redditmedia.com"
                ]
                for rh in rHosts { allDomains.insert(rh) }
            } else if clean.contains("terabox") || clean.contains("1024tera") || clean.contains("4funbox") || clean.contains("mirrobox") || clean.contains("nephobox") || clean.contains("freeterabox") || clean.contains("tibibox") {
                let tbHosts = [
                    "terabox.app", "www.terabox.app", "terabox.com", "www.terabox.com",
                    "teraboxapp.com", "www.teraboxapp.com", "terabox.fun", "www.terabox.fun",
                    "terabox.link", "www.terabox.link", "terabox.me", "www.terabox.me",
                    "terabox.in", "www.terabox.in", "terabox.club", "www.terabox.club",
                    "terabox.space", "www.terabox.space", "terabox.org", "www.terabox.org",
                    "terabox.net", "www.terabox.net", "terabox.top", "www.terabox.top",
                    "terabox.site", "www.terabox.site", "terabox.tech", "www.terabox.tech",
                    "terabox.vip", "www.terabox.vip", "terabox.lat", "www.terabox.lat",
                    "terabox.asia", "www.terabox.asia", "terabox.download", "www.terabox.download",
                    "terabox.is", "www.terabox.is", "terabox.pw", "www.terabox.pw", "terabox.la", "www.terabox.la",
                    "1024tera.com", "www.1024tera.com", "1024terabox.com", "www.1024terabox.com",
                    "1024terabox.net", "www.1024terabox.net", "1024tera.co", "www.1024tera.co",
                    "4funbox.com", "www.4funbox.com", "mirrobox.com", "www.mirrobox.com",
                    "nephobox.com", "www.nephobox.com", "freeterabox.com", "www.freeterabox.com",
                    "tibibox.com", "www.tibibox.com", "momerybox.com", "www.momerybox.com",
                    "boxtera.com", "www.boxtera.com", "terastorage.com", "www.terastorage.com",
                    "terasharelink.com", "www.terasharelink.com", "terafileshare.com", "www.terafileshare.com",
                    "teraboxshare.com", "www.teraboxshare.com", "teraboxurl.com", "www.teraboxurl.com",
                    "teraboxlink.com", "www.teraboxlink.com", "terashare.net", "www.terashare.net",
                    "terashare.org", "www.terashare.org", "terashare.top", "www.terashare.top",
                    "terafiles.net", "www.terafiles.net", "teradrive.co", "www.teradrive.co",
                    "teradrop.net", "www.teradrop.net", "teraboxcdn.com", "www.teraboxcdn.com",
                    "teraboxhls.com", "www.teraboxhls.com",
                    "teraboxdownloader.com", "www.teraboxdownloader.com", "terabox-downloader.com", "www.terabox-downloader.com",
                    "teraboxdl.com", "www.teraboxdl.com", "teraboxdl.net", "www.teraboxdl.net",
                    "teraboxdownloader.online", "www.teraboxdownloader.online", "teraboxdownloader.in", "www.teraboxdownloader.in",
                    "teradownloader.com", "www.teradownloader.com", "teradownload.com", "www.teradownload.com",
                    "teradl.com", "www.teradl.com", "teradl.in", "www.teradl.in", "tera-dl.com", "www.tera-dl.com",
                    "teraboxvideodownloader.com", "www.teraboxvideodownloader.com", "teraboxvideo.com", "www.teraboxvideo.com",
                    "teraboxdirect.com", "www.teraboxdirect.com", "teraboxdirectdownload.com", "www.teraboxdirectdownload.com",
                    "teraboxplayer.com", "www.teraboxplayer.com", "teraboxplayer.online", "www.teraboxplayer.online",
                    "teraboxlinkdownloader.com", "www.teraboxlinkdownloader.com", "terastream.xyz", "www.terastream.xyz",
                    "teraboxmp4.com", "www.teraboxmp4.com", "teramp4.com", "www.teramp4.com",
                    "terasaver.com", "www.terasaver.com", "terafast.com", "www.terafast.com",
                    "flowvideoplayer.com", "www.flowvideoplayer.com"
                ]
                for tb in tbHosts { allDomains.insert(tb) }
            }
        }
        
        // Excluir cualquier host que esté en la lista permitida o en bypass temporal
        if !allowedDomains.isEmpty {
            var allowedRoots: Set<String> = []
            for allowed in allowedDomains {
                let cleanAllowed = allowed.lowercased()
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                    .replacingOccurrences(of: "www.", with: "")
                    .components(separatedBy: "/").first ?? allowed.lowercased()
                allowedRoots.insert(cleanAllowed)
                
                // Si se permite instagram, también permitir sus CDNs
                if cleanAllowed == "instagram.com" || cleanAllowed.contains("instagram") {
                    allowedRoots.insert("instagram.com")
                    allowedRoots.insert("cdninstagram.com")
                    allowedRoots.insert("threads.net")
                } else if cleanAllowed == "facebook.com" || cleanAllowed.contains("facebook") {
                    allowedRoots.insert("facebook.com")
                    allowedRoots.insert("fbcdn.net")
                    allowedRoots.insert("facebook.net")
                    allowedRoots.insert("fb.com")
                    allowedRoots.insert("messenger.com")
                } else if cleanAllowed == "youtube.com" || cleanAllowed.contains("youtube") {
                    allowedRoots.insert("youtube.com")
                    allowedRoots.insert("youtu.be")
                    allowedRoots.insert("ytimg.com")
                    allowedRoots.insert("googlevideo.com")
                } else if cleanAllowed == "tiktok.com" || cleanAllowed.contains("tiktok") {
                    allowedRoots.insert("tiktok.com")
                    allowedRoots.insert("tiktokcdn.com")
                    allowedRoots.insert("byteoversea.com")
                }
            }
            
            allDomains = allDomains.filter { host in
                let cleanHost = host.lowercased().replacingOccurrences(of: "www.", with: "")
                for root in allowedRoots {
                    if cleanHost == root || cleanHost.hasSuffix("." + root) || host.contains(root) {
                        return false
                    }
                }
                return true
            }
        }
        
        for doh in dohResolvers { allDomains.insert(doh) }
        
        let tab = "\t"
        var lines = [String]()
        lines.append(beginTag)
        lines.append("# Bloqueo Universal FocusPanic TDAH")
        
        // Inyección de SafeSearch Forzado (Google, Bing, Yahoo) IPv4 e IPv6 AL PRINCIPIO
        // CRÍTICO: macOS mDNSResponder lee /etc/hosts secuencialmente y tiene límites de búfer.
        // Si SafeSearch se coloca al final (después de 25,000+ dominios), macOS lo ignora.
        if forceSafeSearch {
            lines.append("# SafeSearch Forzado Estricto IPv4 e IPv6 (Google, Bing, Yahoo)")
            let googleDomains = [
                "google.com", "www.google.com",
                "google.es", "www.google.es",
                "google.co", "www.google.co",
                "google.com.co", "www.google.com.co",
                "google.com.mx", "www.google.com.mx",
                "google.com.ar", "www.google.com.ar",
                "google.cl", "www.google.cl",
                "google.com.pe", "www.google.com.pe",
                "google.com.ec", "www.google.com.ec",
                "google.com.ve", "www.google.com.ve",
                "google.com.gt", "www.google.com.gt",
                "google.com.pr", "www.google.com.pr",
                "google.com.uy", "www.google.com.uy",
                "google.com.py", "www.google.com.py",
                "google.com.bo", "www.google.com.bo",
                "google.com.sv", "www.google.com.sv",
                "google.com.hn", "www.google.com.hn",
                "google.com.ni", "www.google.com.ni",
                "google.com.cr", "www.google.com.cr",
                "google.com.pa", "www.google.com.pa",
                "google.com.do", "www.google.com.do",
                "google.com.br", "www.google.com.br",
                "google.ca", "www.google.ca",
                "google.co.uk", "www.google.co.uk",
                "google.fr", "www.google.fr",
                "google.de", "www.google.de",
                "google.it", "www.google.it"
            ]
            for g in googleDomains {
                lines.append("216.239.38.120" + tab + g)
                lines.append("2001:4860:4806::78" + tab + g)
            }
            
            // Bing Strict SafeSearch (strict.bing.com) IPv4 e IPv6
            let bingDomains = [
                "bing.com", "www.bing.com", "cn.bing.com", "r.bing.com",
                "ssl.bing.com", "m.bing.com", "api.bing.com", "global.bing.com"
            ]
            for b in bingDomains {
                lines.append("150.171.29.16" + tab + b)
                lines.append("150.171.30.16" + tab + b)
                lines.append("2620:1ec:33:2::16" + tab + b)
                lines.append("2620:1ec:33:3::16" + tab + b)
            }
            
            // Yahoo SafeSearch
            let yahooDomains = [
                "search.yahoo.com", "safe.search.yahoo.com", "espanol.search.yahoo.com", "mx.search.yahoo.com"
            ]
            for y in yahooDomains {
                lines.append("150.171.29.16" + tab + y) // Bing SafeSearch index
            }
            
            // Bloqueo de más de 100 buscadores alternativos y sin moderación (Solo permitidos Google, Bing y Yahoo con SafeSearch estricto; DuckDuckGo bloqueado)
            lines.append("# Buscadores alternativos bloqueados por Modo Seguro (SafeSearch)")
            let alternativeSearchEngines = [
                // DuckDuckGo (Bloqueado por evasión)
                "duckduckgo.com", "www.duckduckgo.com", "safe.duckduckgo.com",
                "html.duckduckgo.com", "lite.duckduckgo.com", "links.duckduckgo.com",
                "duck.com", "www.duck.com",
                // Yandex
                "yandex.com", "www.yandex.com", "yandex.ru", "www.yandex.ru", "ya.ru", "yandex.eu", "yandex.by", "yandex.kz", "yandex.uz", "dzen.ru", "yandex.com.tr",
                // Baidu
                "baidu.com", "www.baidu.com", "m.baidu.com", "tieba.baidu.com", "zhidao.baidu.com", "haokan.baidu.com",
                // Brave Search
                "search.brave.com", "api.search.brave.com",
                // Ecosia
                "ecosia.org", "www.ecosia.org",
                // Qwant
                "qwant.com", "www.qwant.com", "api.qwant.com", "lite.qwant.com", "junior.qwant.com",
                // Startpage & Ixquick
                "startpage.com", "www.startpage.com", "startpage.nl", "ixquick.com", "www.ixquick.com", "ixquick.eu", "ixquick.info",
                // Searx & SearXNG instances
                "searx.me", "searx.space", "searx.info", "searxng.org", "searx.be", "searx.ninja", "searx.tiekoetter.com",
                "searx.si", "searx.fmac.xyz", "paulgo.io", "priv.au", "search.sapti.me", "search.bus-hit.me", "search.gcomm.ch",
                "search.onions.eng.br", "searx.work", "northboot.xyz", "search.demoverse.org", "search.mdosch.de",
                "search.charlesreid1.com", "opnxng.com", "search.rowie.at", "searx.dresden.network", "privatesearch.dev",
                "search.im-in.space", "searx.roflcopter.fr", "search.smnz.de", "search.unlocked.link", "searx.ru",
                // Whoogle & LibreX
                "whoogle.io", "whoogle.sdf.org", "whoogle.lunar.icu", "whoogle.catsarch.com", "librex.beparanoid.de", "librex.retrohacker.pro",
                // Swisscows & Mojeek
                "swisscows.com", "www.swisscows.com", "hulbee.com", "mojeek.com", "www.mojeek.com",
                // Kagi, Gibiru, Ask, Dogpile, Lycos, Exalead
                "kagi.com", "www.kagi.com", "ask.com", "www.ask.com", "es.ask.com", "dogpile.com", "www.dogpile.com",
                "lycos.com", "www.lycos.com", "exalead.com", "www.exalead.com", "gibiru.com", "www.gibiru.com",
                // Metasearch & Web Crawlers
                "metacrawler.com", "www.metacrawler.com", "webcrawler.com", "www.webcrawler.com", "gigablast.com", "www.gigablast.com",
                "infospace.com", "www.infospace.com", "peekier.com", "www.peekier.com", "entireweb.com", "www.entireweb.com",
                "teoma.com", "www.teoma.com", "yacy.net", "search.yacy.net", "excite.com", "www.excite.com", "hotbot.com", "www.hotbot.com",
                "alexandria.org", "www.alexandria.org", "marginalia.nu", "search.marginalia.nu", "yep.com", "www.yep.com",
                "stract.com", "www.stract.com", "presearch.com", "www.presearch.com", "presearch.io", "presearch.org",
                "search.disroot.org", "lukol.com", "www.lukol.com", "metager.org", "www.metager.org", "metager.de", "metager.es",
                "oscobo.com", "www.oscobo.com", "andisearch.com", "www.andisearch.com",
                // International Search Engines
                "naver.com", "search.naver.com", "daum.net", "search.daum.net", "goo.ne.jp", "search.goo.ne.jp",
                "sogou.com", "www.sogou.com", "sm.cn", "m.sm.cn", "rambler.ru", "nova.rambler.ru", "go.mail.ru",
                "seznam.cz", "search.seznam.cz", "sapra.io", "egerin.com", "alleba.com", "waldo.fyi", "moonsift.com",
                // Reverse Image & Privacy Search Engines
                "tineye.com", "www.tineye.com", "boardreader.com", "zapmeta.com", "www.zapmeta.com", "zapmeta.ws", "zapmeta.mx",
                "searchencrypt.com", "www.searchencrypt.com", "onesearch.com", "www.onesearch.com", "givero.com", "www.givero.com",
                "ekoru.org", "www.ekoru.org", "oceanhero.today", "www.oceanhero.today", "goodgush.com", "privatesearch.com",
                "searchlock.com", "infinitysearch.co", "findx.com", "feedster.com", "webiator.com", "wiby.me", "millionshort.com",
                "alltheweb.com", "altavista.com", "acoona.com", "cuil.com", "hakia.com", "chacha.com", "mahalo.com", "scour.com",
                "sproose.com", "kartoo.com", "mamma.com", "info.com", "www.info.com", "mywebsearch.com", "search.mywebsearch.com",
                "trova.com", "yippy.com", "kosmix.com", "blinkx.com", "kidrex.org", "jigso.com", "24seek.com", "izito.com",
                "izito.es", "izito.mx", "vinden.nl", "search.ch", "zoeken.nl", "looksmart.com", "webmania.com", "findrequest.com",
                "searchpulse.net", "websearch.com", "searchmine.net", "searchawesome.net", "searchmanager.net", "searchlee.com",
                "searchit.com", "searchsnow.com", "searchmarquis.com", "searchbaron.com", "nearbyme.io",
                // oTechWorld Search Engines List (General, Niche, People & Meta Search)
                "search.aol.com", "aol.com", "search.com", "www.search.com", "devilfinder.com", "www.devilfinder.com",
                "privatelee.com", "www.privatelee.com", "search.disconnect.me", "disconnect.me", "spokeo.com", "www.spokeo.com",
                "freepeoplesearch.com", "www.freepeoplesearch.com", "social-searcher.com", "www.social-searcher.com",
                "base-search.net", "www.base-search.net", "kiddle.co", "www.kiddle.co", "yummly.com", "www.yummly.com"
            ]
            for alt in alternativeSearchEngines {
                lines.append("0.0.0.0" + tab + alt)
                lines.append("127.0.0.1" + tab + alt)
                lines.append("::1" + tab + alt)
            }
        }
        
        // Validación estricta de nombres de host para proteger /etc/hosts
        let domainRegex = try? NSRegularExpression(pattern: "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$")
        
        for domain in allDomains.sorted() {
            guard let regex = domainRegex,
                  regex.firstMatch(in: domain, options: [], range: NSRange(location: 0, length: domain.utf16.count)) != nil else {
                continue
            }
            lines.append("0.0.0.0" + tab + domain)
        }
        
        lines.append(endTag)
        
        let blockSection = "\n" + lines.joined(separator: "\n") + "\n"
        let newContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines) + "\n" + blockSection
        
        let tempPath = "/tmp/focuspanic_hosts_\(UUID().uuidString).txt"
        try newContent.write(toFile: tempPath, atomically: true, encoding: .utf8)
        
        if isHelperInstalled {
            let success = runHelper(args: ["apply", tempPath])
            if success { return }
        }
        
        try applyWithAppleScript(tempPath: tempPath)
    }
    
    public func removeBlock() throws {
        if isHelperInstalled {
            let _ = runHelper(args: ["remove"])
            return
        }
        guard let currentContent = try? String(contentsOfFile: hostsFilePath, encoding: .utf8) else { return }
        let cleanedContent = removeBlockSection(from: currentContent)
        let tempPath = "/tmp/focuspanic_hosts_remove.txt"
        try cleanedContent.write(toFile: tempPath, atomically: true, encoding: .utf8)
        try applyWithAppleScript(tempPath: tempPath)
    }
    
    public func clearAllBlocks() throws {
        try removeBlock()
    }
    
    public func uninstallHelper() throws {
        try removeBlock()
        let script = "do shell script \"rm -f /usr/local/bin/focuspanic-helper /etc/sudoers.d/focuspanic 2>/dev/null\" with administrator privileges"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
    
    public func flushDNSCache() {
        if isHelperInstalled {
            let _ = runHelper(args: ["flush"])
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            process.arguments = ["-flushcache"]
            try? process.run()
        }
    }
    
    // MARK: - Verificación y Configuración de DNS Cloudflare Families (1.1.1.3)
    
    public func isFamilyDNSActive() -> Bool {
        // 1. Obtener todos los servicios de red configurados en macOS
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        listProcess.arguments = ["-listallnetworkservices"]
        let listPipe = Pipe()
        listProcess.standardOutput = listPipe
        listProcess.standardError = listPipe
        
        var services: [String] = ["Wi-Fi", "Ethernet", "Thunderbolt Ethernet"]
        do {
            try listProcess.run()
            listProcess.waitUntilExit()
            let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: listData, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("*") && !$0.contains("An asterisk") }
                if !lines.isEmpty {
                    services = lines
                }
            }
        } catch {}
        
        // 2. Verificar que las interfaces principales tengan el DNS activo
        var checkedAtLeastOne = false
        for service in services {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            proc.arguments = ["-getdnsservers", service]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    // Si el servicio no tiene DNS ("There aren't any DNS Servers"), es que no tiene 1.1.1.3
                    if output.contains("There aren't any DNS Servers") {
                        return false
                    }
                    if output.contains("1.1.1.3") {
                        checkedAtLeastOne = true
                    }
                }
            } catch {}
        }
        return checkedAtLeastOne
    }
    
    @discardableResult
    public func applyFamilyDNS() -> Bool {
        if isHelperInstalled {
            return runHelper(args: ["apply-family-dns"])
        }
        return false
    }
    
    // MARK: - Internals
    
    private func runHelper(args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [helperPath] + args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    private func removeBlockSection(from content: String) -> String {
        guard let startRange = content.range(of: beginTag),
              let endRange = content.range(of: endTag) else { return content }
        var result = content
        let endIdx = endRange.upperBound
        let searchEnd = content.index(endIdx, offsetBy: 1, limitedBy: content.endIndex) ?? endIdx
        result.removeSubrange(startRange.lowerBound..<searchEnd)
        return result.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
    
    private func applyWithAppleScript(tempPath: String) throws {
        let cmd = "cp -f '\(tempPath)' /etc/hosts && chmod 644 /etc/hosts && killall -HUP mDNSResponder && dscacheutil -flushcache && rm -f '\(tempPath)'"
        let escapedCmd = cmd.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escapedCmd)\" with administrator privileges with prompt \"FocusPanic necesita permisos para el bloqueo.\""
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            if let error = error {
                let msg = error[NSAppleScript.errorMessage] as? String ?? "Permisos denegados."
                throw NSError(domain: "FocusPanic", code: 1, userInfo: [NSLocalizedDescriptionKey: msg])
            }
        }
    }
}
