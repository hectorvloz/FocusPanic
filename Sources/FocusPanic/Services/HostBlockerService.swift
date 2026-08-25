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
                    killall -HUP mDNSResponder 2>/dev/null || true
                    dscacheutil -flushcache 2>/dev/null || true
                    rm -f "$2"
                    echo "OK"
                else
                    echo "ERROR" && exit 1
                fi
                ;;
            remove)
                if grep -q "BEGIN FOCUSPANIC" "$HOSTS"; then
                    sed -i '' '/# >>> BEGIN FOCUSPANIC BLOCK/,/# <<< END FOCUSPANIC BLOCK/d' "$HOSTS"
                    chmod 644 "$HOSTS"
                    killall -HUP mDNSResponder 2>/dev/null || true
                    dscacheutil -flushcache 2>/dev/null || true
                fi
                echo "OK"
                ;;
            flush)
                killall -HUP mDNSResponder 2>/dev/null || true
                dscacheutil -flushcache 2>/dev/null || true
                echo "OK"
                ;;
            *)
                echo "Usage: focuspanic-helper {apply|remove|flush} [file]"; exit 1;;
        esac
        """
        
        let tempHelper = "/tmp/focuspanic-helper-install.sh"
        try helperContent.write(toFile: tempHelper, atomically: true, encoding: .utf8)
        
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
    
    public func applyBlock(domains: [String], forceSafeSearch: Bool = true) throws {
        let currentContent = (try? String(contentsOfFile: hostsFilePath, encoding: .utf8)) ?? ""
        let cleanedContent = removeBlockSection(from: currentContent)
        
        var allDomains = Set<String>()
        
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
            
            // Expansión especializada para plataformas complejas
            if clean.contains("tiktok") {
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
            } else if clean.contains("facebook.com") || clean.contains("fb.com") {
                let fbHosts = [
                    "facebook.com", "www.facebook.com", "m.facebook.com", "web.facebook.com",
                    "l.facebook.com", "touch.facebook.com", "graph.facebook.com", "edge-chat.facebook.com",
                    "connect.facebook.net", "fbcdn.net", "static.xx.fbcdn.net", "scontent.xx.fbcdn.net",
                    "fb.com", "www.fb.com", "messenger.com", "www.messenger.com"
                ]
                for fh in fbHosts { allDomains.insert(fh) }
            } else if clean.contains("instagram.com") {
                let igHosts = [
                    "instagram.com", "www.instagram.com", "m.instagram.com", "api.instagram.com",
                    "i.instagram.com", "graph.instagram.com", "cdninstagram.com", "www.cdninstagram.com",
                    "scontent.cdninstagram.com", "threads.net", "www.threads.net"
                ]
                for ih in igHosts { allDomains.insert(ih) }
            } else if clean.contains("youtube.com") || clean.contains("youtu.be") {
                let ytHosts = [
                    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
                    "ytimg.com", "i.ytimg.com", "googlevideo.com", "youtubei.googleapis.com",
                    "yt3.ggpht.com"
                ]
                for yh in ytHosts { allDomains.insert(yh) }
            } else if clean.contains("twitter.com") || clean.contains("x.com") {
                let xHosts = [
                    "twitter.com", "www.twitter.com", "mobile.twitter.com", "api.twitter.com",
                    "x.com", "www.x.com", "api.x.com", "twimg.com", "pbs.twimg.com"
                ]
                for xh in xHosts { allDomains.insert(xh) }
            } else if clean.contains("reddit.com") {
                let rHosts = [
                    "reddit.com", "www.reddit.com", "old.reddit.com", "oauth.reddit.com",
                    "gql.reddit.com", "redditstatic.com", "redditmedia.com"
                ]
                for rh in rHosts { allDomains.insert(rh) }
            }
        }
        
        for doh in dohResolvers { allDomains.insert(doh) }
        
        let tab = "\t"
        var lines = [String]()
        lines.append(beginTag)
        lines.append("# Bloqueo Universal FocusPanic TDAH")
        
        // Validación estricta de nombres de host para proteger /etc/hosts
        let domainRegex = try? NSRegularExpression(pattern: "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$")
        
        for domain in allDomains.sorted() {
            guard let regex = domainRegex,
                  regex.firstMatch(in: domain, options: [], range: NSRange(location: 0, length: domain.utf16.count)) != nil else {
                continue
            }
            lines.append("0.0.0.0" + tab + domain)
            lines.append("127.0.0.1" + tab + domain)
            lines.append("::1" + tab + domain)
        }
        
        // Inyección de SafeSearch Forzado (Google, Bing, DuckDuckGo)
        if forceSafeSearch {
            lines.append("# SafeSearch Forzado Estricto (Google, Bing, DuckDuckGo)")
            lines.append("216.239.38.120" + tab + "www.google.com")
            lines.append("216.239.38.120" + tab + "google.com")
            lines.append("216.239.38.120" + tab + "www.google.es")
            lines.append("216.239.38.120" + tab + "google.es")
            lines.append("216.239.38.120" + tab + "www.google.co")
            lines.append("216.239.38.120" + tab + "www.google.com.co")
            lines.append("216.239.38.120" + tab + "www.google.com.mx")
            lines.append("216.239.38.120" + tab + "www.google.com.ar")
            lines.append("216.239.38.120" + tab + "www.google.cl")
            lines.append("216.239.38.120" + tab + "www.google.com.pe")
            lines.append("204.79.197.220" + tab + "www.bing.com")
            lines.append("204.79.197.220" + tab + "bing.com")
            lines.append("52.142.124.215" + tab + "duckduckgo.com")
            lines.append("52.142.124.215" + tab + "www.duckduckgo.com")
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
