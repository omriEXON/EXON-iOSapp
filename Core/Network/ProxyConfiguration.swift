import Foundation

struct ProxyConfiguration {
    let host: String
    let port: Int
    let market: String
    
    static func getConfig(for region: String) -> ProxyConfiguration? {
        let configs: [String: ProxyConfiguration] = [
            "US": ProxyConfiguration(host: "us.decodo.com", port: 10000, market: "US"),
            "CA": ProxyConfiguration(host: "ca.decodo.com", port: 20000, market: "CA"),
            "AR": ProxyConfiguration(host: "ar.decodo.com", port: 10000, market: "AR"),
            "TR": ProxyConfiguration(host: "tr.decodo.com", port: 40000, market: "TR"),
            "DE": ProxyConfiguration(host: "de.decodo.com", port: 20000, market: "DE"),
            "AU": ProxyConfiguration(host: "au.decodo.com", port: 30000, market: "AU"),
            "SG": ProxyConfiguration(host: "sg.decodo.com", port: 10000, market: "SG"),
            "IN": ProxyConfiguration(host: "in.decodo.com", port: 10000, market: "IN"),
            "UA": ProxyConfiguration(host: "ua.decodo.com", port: 40000, market: "UA"),
            "EG": ProxyConfiguration(host: "eg.decodo.com", port: 20000, market: "EG"),
            "IL": ProxyConfiguration(host: "il.decodo.com", port: 30000, market: "IL"),
            "HK": ProxyConfiguration(host: "hk.decodo.com", port: 10000, market: "HK"),
            "JP": ProxyConfiguration(host: "jp.decodo.com", port: 30000, market: "JP"),
            "CN": ProxyConfiguration(host: "cn.decodo.com", port: 30000, market: "CN"),
            "BR": ProxyConfiguration(host: "br.decodo.com", port: 10000, market: "BR"),
            "PK": ProxyConfiguration(host: "pk.decodo.com", port: 10000, market: "PK"),
            "CO": ProxyConfiguration(host: "co.decodo.com", port: 30000, market: "CO"),
            "MX": ProxyConfiguration(host: "mx.decodo.com", port: 20000, market: "MX"),
            "AE": ProxyConfiguration(host: "ae.decodo.com", port: 20000, market: "AE"),
            "PH": ProxyConfiguration(host: "ph.decodo.com", port: 40000, market: "PH"),
            "TW": ProxyConfiguration(host: "tw.decodo.com", port: 20000, market: "TW"),
            "KR": ProxyConfiguration(host: "kr.decodo.com", port: 10000, market: "KR"),
            "TH": ProxyConfiguration(host: "th.decodo.com", port: 30000, market: "TH"),
            "NZ": ProxyConfiguration(host: "nz.decodo.com", port: 39000, market: "NZ"),
            "ZA": ProxyConfiguration(host: "za.decodo.com", port: 40000, market: "ZA"),
            "GB": ProxyConfiguration(host: "gb.decodo.com", port: 30000, market: "GB"),
            "NG": ProxyConfiguration(host: "ng.decodo.com", port: 42000, market: "NG")
        ]
        
        return configs[region.uppercased()]
    }
    
    func createProxyDict(credentials: ProxyCredentials) -> [String: Any] {
        return [
            kCFNetworkProxiesHTTPEnable as String: true,
            kCFNetworkProxiesHTTPProxy as String: host,
            kCFNetworkProxiesHTTPPort as String: port,
            kCFNetworkProxiesHTTPSEnable as String: true,
            kCFNetworkProxiesHTTPSProxy as String: host,
            kCFNetworkProxiesHTTPSPort as String: port,
            kCFProxyUsernameKey as String: credentials.username,
            kCFProxyPasswordKey as String: credentials.password
        ]
    }
}
