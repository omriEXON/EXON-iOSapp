import Foundation

struct RegionNormalizer {
    
    // Region translations (Hebrew, Arabic, English)
    private static let regionTranslations: [String: [String: String]] = [
        "US": ["en": "United States", "he": "ארצות הברית", "ar": "الولايات المتحدة"],
        "CA": ["en": "Canada", "he": "קנדה", "ar": "كندا"],
        "AR": ["en": "Argentina", "he": "ארגנטינה", "ar": "الأرجنتين"],
        "TR": ["en": "Turkey", "he": "טורקיה", "ar": "تركيا"],
        "DE": ["en": "Germany", "he": "גרמניה", "ar": "ألمانيا"],
        "AU": ["en": "Australia", "he": "אוסטרליה", "ar": "أستراليا"],
        "SG": ["en": "Singapore", "he": "סינגפור", "ar": "سنغافورة"],
        "IN": ["en": "India", "he": "הודו", "ar": "الهند"],
        "UA": ["en": "Ukraine", "he": "אוקראינה", "ar": "أوكرانيا"],
        "EG": ["en": "Egypt", "he": "מצרים", "ar": "مصر"],
        "IL": ["en": "Israel", "he": "ישראל", "ar": "إسرائيل"],
        "HK": ["en": "Hong Kong", "he": "הונג קונג", "ar": "هونغ كونغ"],
        "JP": ["en": "Japan", "he": "יפן", "ar": "اليابان"],
        "CN": ["en": "China", "he": "סין", "ar": "الصين"],
        "BR": ["en": "Brazil", "he": "ברזיל", "ar": "البرازيل"],
        "PK": ["en": "Pakistan", "he": "פקיסטן", "ar": "باكستان"],
        "CO": ["en": "Colombia", "he": "קולומביה", "ar": "كولومبيا"],
        "MX": ["en": "Mexico", "he": "מקסיקו", "ar": "المكسيك"],
        "AE": ["en": "United Arab Emirates", "he": "איחוד האמירויות", "ar": "الإمارات العربية المتحدة"],
        "PH": ["en": "Philippines", "he": "פיליפינים", "ar": "الفلبين"],
        "TW": ["en": "Taiwan", "he": "טייוואן", "ar": "تايوان"],
        "KR": ["en": "South Korea", "he": "דרום קוריאה", "ar": "كوريا الجنوبية"],
        "TH": ["en": "Thailand", "he": "תאילנד", "ar": "تايلاند"],
        "NZ": ["en": "New Zealand", "he": "ניו זילנד", "ar": "نيوزيلندا"],
        "ZA": ["en": "South Africa", "he": "דרום אפריקה", "ar": "جنوب أفريقيا"],
        "GB": ["en": "United Kingdom", "he": "בריטניה", "ar": "المملكة المتحدة"],
        "NG": ["en": "Nigeria", "he": "ניגריה", "ar": "نيجيريا"]
    ]
    
    // Build reverse lookup map for O(1) performance
    private static let regionLookupMap: [String: String] = {
        var map: [String: String] = [:]
        
        for (code, translations) in regionTranslations {
            // Add all translations as keys pointing to the region code
            for (_, name) in translations {
                if !name.isEmpty {
                    map[name.lowercased()] = code
                }
            }
            // Also add the code itself
            map[code.lowercased()] = code
        }
        
        return map
    }()
    
    // Universal region normalizer function (matching Chrome extension)
    static func normalizeRegion(_ input: String?) -> String? {
        guard let input = input else { return nil }
        
        // Convert to string, lowercase, and trim whitespace
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // O(1) lookup - returns region code or uppercase fallback
        return regionLookupMap[normalized] ?? input.uppercased()
    }
    
    static func getRegionName(_ code: String, language: String = "en") -> String {
        guard let translations = regionTranslations[code.uppercased()] else {
            return code
        }
        
        return translations[language] ?? translations["en"] ?? code
    }
    
    static func isGlobalRegion(_ region: String?) -> Bool {
        guard let region = region else { return false }
        let globalRegions = ["GLOBAL", "WW", "WORLDWIDE"]
        return globalRegions.contains(region.uppercased())
    }
}
