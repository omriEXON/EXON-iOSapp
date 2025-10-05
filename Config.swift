// Config.swift
import Foundation

// MARK: - Debug Configuration
#if DEBUG
let DEBUG = true
#else
let DEBUG = false
#endif

// MARK: - Logging Functions
func devLog(_ message: String) {
    if DEBUG {
        print("[EXON] \(message)")
    }
}

func devError(_ message: String) {
    if DEBUG {
        print("[EXON] ❌ \(message)")
    }
}

func devWarn(_ message: String) {
    if DEBUG {
        print("[EXON] ⚠️ \(message)")
    }
}

func devInfo(_ message: String) {
    if DEBUG {
        print("[EXON] ℹ️ \(message)")
    }
}

struct Config {
    struct Supabase {
        static let url = "https://fyjejvboeopofqbvvatc.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ5amVqdmJvZW9wb2ZxYnZ2YXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTUwODMwMDIsImV4cCI6MjA3MDY1OTAwMn0.Od2OfMA3D9HpL_MKusXWkblDBDKHKZWQuKbCo9LE3oU"
    }
    
    // Lowercase alias for compatibility
    struct supabase {
        static let url = Supabase.url
        static let anonKey = Supabase.anonKey
    }
}

// MARK: - Proxy Configuration
struct ProxyConfig {
    static let regions: [String: ProxyRegion] = [
        "US": ProxyRegion(host: "us.decodo.com", port: 10000, market: "US", country: "United States"),
        "CA": ProxyRegion(host: "ca.decodo.com", port: 20000, market: "CA", country: "Canada"),
        "AR": ProxyRegion(host: "ar.decodo.com", port: 10000, market: "AR", country: "Argentina"),
        "TR": ProxyRegion(host: "tr.decodo.com", port: 40000, market: "TR", country: "Turkey"),
        "DE": ProxyRegion(host: "de.decodo.com", port: 20000, market: "DE", country: "Germany"),
        "AU": ProxyRegion(host: "au.decodo.com", port: 30000, market: "AU", country: "Australia"),
        "SG": ProxyRegion(host: "sg.decodo.com", port: 10000, market: "SG", country: "Singapore"),
        "IN": ProxyRegion(host: "in.decodo.com", port: 10000, market: "IN", country: "India"),
        "UA": ProxyRegion(host: "ua.decodo.com", port: 40000, market: "UA", country: "Ukraine"),
        "EG": ProxyRegion(host: "eg.decodo.com", port: 20000, market: "EG", country: "Egypt"),
        "IL": ProxyRegion(host: "il.decodo.com", port: 30000, market: "IL", country: "Israel"),
        "HK": ProxyRegion(host: "hk.decodo.com", port: 10000, market: "HK", country: "Hong Kong"),
        "JP": ProxyRegion(host: "jp.decodo.com", port: 30000, market: "JP", country: "Japan"),
        "CN": ProxyRegion(host: "cn.decodo.com", port: 30000, market: "CN", country: "China"),
        "BR": ProxyRegion(host: "br.decodo.com", port: 10000, market: "BR", country: "Brazil"),
        "PK": ProxyRegion(host: "pk.decodo.com", port: 10000, market: "PK", country: "Pakistan"),
        "CO": ProxyRegion(host: "co.decodo.com", port: 30000, market: "CO", country: "Colombia"),
        "MX": ProxyRegion(host: "mx.decodo.com", port: 20000, market: "MX", country: "Mexico"),
        "AE": ProxyRegion(host: "ae.decodo.com", port: 20000, market: "AE", country: "United Arab Emirates"),
        "PH": ProxyRegion(host: "ph.decodo.com", port: 40000, market: "PH", country: "Philippines"),
        "TW": ProxyRegion(host: "tw.decodo.com", port: 20000, market: "TW", country: "Taiwan"),
        "KR": ProxyRegion(host: "kr.decodo.com", port: 10000, market: "KR", country: "South Korea"),
        "TH": ProxyRegion(host: "th.decodo.com", port: 30000, market: "TH", country: "Thailand"),
        "NZ": ProxyRegion(host: "nz.decodo.com", port: 39000, market: "NZ", country: "New Zealand"),
        "ZA": ProxyRegion(host: "za.decodo.com", port: 40000, market: "ZA", country: "South Africa"),
        "GB": ProxyRegion(host: "gb.decodo.com", port: 30000, market: "GB", country: "United Kingdom"),
        "NG": ProxyRegion(host: "ng.decodo.com", port: 42000, market: "NG", country: "Nigeria")
    ]
    
    static let defaultRegion = "IL"
    static let connectionTimeout: TimeInterval = 10
    static let maxRetries = 2
    static let authCacheDuration: TimeInterval = 300 // 5 minutes
    
    static let targetHosts = [
        "purchase.mp.microsoft.com",
        "displaycatalog.mp.microsoft.com",
        "account.microsoft.com",
        "mp.microsoft.com",
        "microsoft.com",
        "browser.events.data.microsoft.com"
    ]
    
    struct ProxyRegion {
        let host: String
        let port: Int
        let market: String
        let country: String
    }
}

// MARK: - Shopify Configuration
struct ShopifyConfig {
    static let allowedOrigins = [
        "https://exongames.co.il",
        "https://exon-israel.myshopify.com"
    ]
}

// MARK: - Support Configuration
struct SupportConfig {
    // WhatsApp Business number (without + sign)
    static let whatsappNumber = "972557207138"
    
    // Default support messages in Hebrew
    struct DefaultMessages {
        static let redeemed = "שלום, אני צריך עזרה עם קוד שכבר מומש"
        static let general = "שלום, אני צריך עזרה עם הפעלת מוצר"
        static let technical = "שלום, יש לי בעיה טכנית עם ההרחבה"
    }
    
    // Support email (optional fallback)
    static let supportEmail = "help@exongames.co.il"
}

// MARK: - Multi-language Region Translations
struct RegionTranslations {
    static let translations: [String: RegionNames] = [
        "US": RegionNames(en: "United States", he: "ארצות הברית", ar: "الولايات المتحدة"),
        "CA": RegionNames(en: "Canada", he: "קנדה", ar: "كندا"),
        "AR": RegionNames(en: "Argentina", he: "ארגנטינה", ar: "الأرجنتين"),
        "TR": RegionNames(en: "Turkey", he: "טורקיה", ar: "تركيا"),
        "DE": RegionNames(en: "Germany", he: "גרמניה", ar: "ألمانيا"),
        "AU": RegionNames(en: "Australia", he: "אוסטרליה", ar: "أستراليا"),
        "SG": RegionNames(en: "Singapore", he: "סינגפור", ar: "سنغافورة"),
        "IN": RegionNames(en: "India", he: "הודו", ar: "الهند"),
        "UA": RegionNames(en: "Ukraine", he: "אוקראינה", ar: "أوكرانيا"),
        "EG": RegionNames(en: "Egypt", he: "מצרים", ar: "مصر"),
        "IL": RegionNames(en: "Israel", he: "ישראל", ar: "إسرائيل"),
        "HK": RegionNames(en: "Hong Kong", he: "הונג קונג", ar: "هونغ كونغ"),
        "JP": RegionNames(en: "Japan", he: "יפן", ar: "اليابان"),
        "CN": RegionNames(en: "China", he: "סין", ar: "الصين"),
        "BR": RegionNames(en: "Brazil", he: "ברזיל", ar: "البرازيل"),
        "PK": RegionNames(en: "Pakistan", he: "פקיסטן", ar: "باكستان"),
        "CO": RegionNames(en: "Colombia", he: "קולומביה", ar: "كولومبيا"),
        "MX": RegionNames(en: "Mexico", he: "מקסיקו", ar: "المكسيك"),
        "AE": RegionNames(en: "United Arab Emirates", he: "איחוד האמירויות", ar: "الإمارات العربية المتحدة"),
        "PH": RegionNames(en: "Philippines", he: "פיליפינים", ar: "الفلبين"),
        "TW": RegionNames(en: "Taiwan", he: "טייוואן", ar: "تايوان"),
        "KR": RegionNames(en: "South Korea", he: "דרום קוריאה", ar: "كوريا الجنوبية"),
        "TH": RegionNames(en: "Thailand", he: "תאילנד", ar: "تايلاند"),
        "NZ": RegionNames(en: "New Zealand", he: "ניו זילנד", ar: "نيوزيلندا"),
        "ZA": RegionNames(en: "South Africa", he: "דרום אפריקה", ar: "جنوب أفريقيا"),
        "GB": RegionNames(en: "United Kingdom", he: "בריטניה", ar: "المملكة المتحدة"),
        "NG": RegionNames(en: "Nigeria", he: "ניגריה", ar: "نيجيريا")
    ]
    
    struct RegionNames {
        let en: String
        let he: String
        let ar: String
    }
    
    // Build reverse lookup map for O(1) performance
    private static let lookupMap: [String: String] = {
        var map: [String: String] = [:]
        
        for (code, names) in translations {
            // Add all translations as keys pointing to the region code
            map[names.en.lowercased()] = code
            map[names.he.lowercased()] = code
            map[names.ar.lowercased()] = code
            // Also add the code itself
            map[code.lowercased()] = code
        }
        
        return map
    }()
    
    // Universal region normalizer function
    static func normalizeRegion(_ input: String?) -> String? {
        guard let input = input else { return nil }
        
        // Convert to string, lowercase, and trim whitespace
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // O(1) lookup - returns region code or uppercase fallback
        return lookupMap[normalized] ?? input.uppercased()
    }
    
    static func getRegionName(_ code: String, language: String = "en") -> String {
        guard let names = translations[code.uppercased()] else {
            return code
        }
        
        switch language {
        case "he": return names.he
        case "ar": return names.ar
        default: return names.en
        }
    }
}
