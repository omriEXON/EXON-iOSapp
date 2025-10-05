import SwiftUI
import WebKit
import Intercom

struct ContentView: View {
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    @State private var selectedTab: TabSection = .home
    @State private var storeWebView: WKWebView?
    @State private var searchText = ""
    @State private var showingActivation = false
    @State private var activationToken: String?
    @State private var storedProducts: [StoredProduct] = []
    @State private var isRefreshing = false
    
    enum TabSection: Hashable {
        case home, cart, chat, account, search
    }
    
    var body: some View {
        ZStack {
            // Main tab view
            TabView(selection: $selectedTab) {
                // Home Tab
                Tab("בית", systemImage: "house", value: TabSection.home) {
                    NavigationStack {
                        VStack(spacing: 0) {
                            // Custom Header
                            CustomHeaderView(
                                webView: storeWebView,
                                title: "EXON Games",
                                subtitle: "חנות הגיימינג שלכם",
                                onRefresh: refreshWebView
                            )
                            
                            // Web View Content
                            StoreWebView(
                                url: URL(string: "https://exongames.co.il")!,
                                webView: $storeWebView,
                                onActivationDetected: handleActivationDetected
                            )
                            .ignoresSafeArea(.container, edges: .bottom)
                        }
                        .navigationBarHidden(true)
                    }
                }
                
                // Search Tab
                Tab("חיפוש", systemImage: "magnifyingglass", value: TabSection.search) {
                    NavigationStack {
                        VStack(spacing: 0) {
                            CustomHeaderView(
                                webView: nil,
                                title: "חיפוש",
                                subtitle: "מצאו את המשחק המושלם"
                            )
                            
                            StoreWebView(
                                url: URL(string: "https://exongames.co.il/search")!,
                                webView: .constant(nil),
                                onActivationDetected: handleActivationDetected
                            )
                            .ignoresSafeArea(.container, edges: .bottom)
                        }
                        .navigationBarHidden(true)
                    }
                }
                
                // Chat Tab
                Tab("צ'אט", systemImage: "message", value: TabSection.chat) {
                    NavigationStack {
                        Color.clear
                            .onAppear {
                                openNativeIntercom()
                                // Switch back to home tab after opening chat
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    selectedTab = .home
                                }
                            }
                    }
                }
                
                // Account Tab - Shows stored products
                Tab("חשבון", systemImage: "person.circle", value: TabSection.account) {
                    NavigationStack {
                        AccountView(
                            products: $storedProducts,
                            onActivateProduct: activateStoredProduct,
                            onRefresh: loadStoredProducts
                        )
                    }
                }
                
                // Cart Tab (floating button style)
                Tab("עגלה", systemImage: "cart", value: TabSection.cart, role: .search) {
                    NavigationStack {
                        Color.clear
                            .onAppear {
                                openCart()
                            }
                    }
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == .cart {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        selectedTab = .home
                    }
                }
            }
            
            // Activation overlay
            if showingActivation, let token = activationToken {
                ActivationOverlay(sessionToken: token) {
                    withAnimation {
                        showingActivation = false
                        activationToken = nil
                    }
                    deepLinkHandler.clearActivation()
                    loadStoredProducts()
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(999)
            }
        }
        .onChange(of: deepLinkHandler.shouldShowActivation) { _, shouldShow in
            if shouldShow, let activation = deepLinkHandler.pendingActivation {
                print("[ContentView] Showing activation for token: \(activation.sessionToken)")
                activationToken = activation.sessionToken
                withAnimation {
                    showingActivation = true
                }
            }
        }
        .onAppear {
            setupWebViewMessageHandler()
            loadStoredProducts()
        }
    }
    
    // MARK: - Portal Activation Detection
    
    private func setupWebViewMessageHandler() {
        // Listen for portal activation messages
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PortalActivation"),
            object: nil,
            queue: .main
        ) { notification in
            if let token = notification.userInfo?["token"] as? String {
                print("[ContentView] Portal activation detected: \(token)")
                deepLinkHandler.triggerActivation(token: token, source: .inApp)
            }
        }
    }
    
    private func handleActivationDetected(token: String) {
        print("[ContentView] Activation detected from web: \(token)")
        deepLinkHandler.triggerActivation(token: token, source: .inApp)
    }
    
    // MARK: - Stored Products Management
    
    private func loadStoredProducts() {
        // Load from UserDefaults or CoreData
        if let data = UserDefaults.standard.data(forKey: "storedProducts"),
           let products = try? JSONDecoder().decode([StoredProduct].self, from: data) {
            storedProducts = products
                .sorted { $0.addedAt > $1.addedAt }
                .prefix(20)
                .map { $0 }
        }
    }
    
    private func activateStoredProduct(_ product: StoredProduct) {
        activationToken = product.sessionToken
        withAnimation {
            showingActivation = true
        }
    }
    
    // MARK: - Cart Functions
    
    private func openCart() {
        guard let webView = storeWebView else { return }
        
        let cartScript = """
        (function() {
            console.log('[EXON] Opening cart...');
            
            // Try Dawn theme cart drawer first
            if (window.cart && typeof window.cart.open === 'function') {
                window.cart.open();
                return 'Cart opened via window.cart.open()';
            }
            
            // Try various cart drawer selectors
            const selectors = [
                '[data-action="open-drawer"][data-drawer-id*="cart"]',
                '[data-cart-drawer-toggle]',
                '.js-drawer-open-cart',
                '.cart-drawer__toggle',
                '.cart-link__bubble',
                '.site-header__cart-toggle',
                '[href="/cart"].cart-icon'
            ];
            
            for (let selector of selectors) {
                const el = document.querySelector(selector);
                if (el) {
                    el.click();
                    return 'Cart opened via ' + selector;
                }
            }
            
            // Fallback: navigate to cart page
            window.location.href = '/cart';
            return 'Navigated to cart page';
        })();
        """
        
        webView.evaluateJavaScript(cartScript) { result, error in
            if let error = error {
                print("[Cart] Error: \(error)")
            } else if let result = result {
                print("[Cart] Success: \(result)")
            }
        }
    }
    
    private func refreshWebView() {
        withAnimation {
            isRefreshing = true
        }
        
        storeWebView?.reload()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                isRefreshing = false
            }
        }
    }
    
    private func openNativeIntercom() {
        // Use the native Intercom SDK
        Intercom.present()
    }
}

// MARK: - Account View
struct AccountView: View {
    @Binding var products: [StoredProduct]
    let onActivateProduct: (StoredProduct) -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            CustomHeaderView(
                webView: nil,
                title: "החשבון שלי",
                subtitle: "ניהול פרופיל והזמנות"
            )
            
            ScrollView {
                if products.isEmpty {
                    EmptyProductsView()
                        .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(products) { product in
                            ProductCard(
                                product: product,
                                onActivate: { onActivateProduct(product) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .refreshable {
                onRefresh()
            }
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: StoredProduct
    let onActivate: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Product Image
            AsyncImage(url: URL(string: product.productImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            
            // Product Info
            VStack(alignment: .leading, spacing: 8) {
                Text(product.productName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack {
                    StatusBadge(status: product.status)
                    
                    Spacer()
                    
                    if let addedAt = product.addedAt {
                        Text(timeAgo(from: addedAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            if product.status == "ready" {
                Button(action: onActivate) {
                    Text("הפעל")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "E70E3C"))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var statusColor: Color {
        switch status {
        case "ready": return Color(hex: "33E7BB")
        case "activated": return Color.gray
        case "expired": return Color.orange
        default: return Color.gray
        }
    }
    
    private var statusText: String {
        switch status {
        case "ready": return "זמין"
        case "activated": return "הופעל"
        case "expired": return "פג תוקף"
        default: return "לא ידוע"
        }
    }
}

// MARK: - Empty Products View
struct EmptyProductsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("אין רישיונות עדיין")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                Text("הרישיונות שלך יופיעו כאן.\nרכוש מהחנות שלנו כדי להתחיל.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                if let url = URL(string: "https://exongames.co.il") {
                    UIApplication.shared.open(url)
                }
            }) {
                Label("לחנות", systemImage: "cart.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "E70E3C"))
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

// MARK: - Web View
struct StoreWebView: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView?
    var onActivationDetected: ((String) -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        
        // Inject activation detection script
        let script = """
        (function() {
            // Listen for activation links
            document.addEventListener('click', function(e) {
                const link = e.target.closest('a');
                if (link && link.href) {
                    if (link.href.includes('session=')) {
                        const url = new URL(link.href);
                        const session = url.searchParams.get('session');
                        if (session) {
                            window.webkit.messageHandlers.activation.postMessage({
                                type: 'session',
                                token: session
                            });
                        }
                    }
                }
            });
        })();
        """
        
        let userScript = WKUserScript(
            source: script,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(context.coordinator, name: "activation")
        
        let newWebView = WKWebView(frame: .zero, configuration: configuration)
        newWebView.navigationDelegate = context.coordinator
        newWebView.load(URLRequest(url: url))
        
        // Store reference if needed
        DispatchQueue.main.async {
            if webView == nil {
                webView = newWebView
            }
        }
        
        return webView ?? newWebView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onActivationDetected: onActivationDetected)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let onActivationDetected: ((String) -> Void)?
        
        init(onActivationDetected: ((String) -> Void)?) {
            self.onActivationDetected = onActivationDetected
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "activation",
                  let body = message.body as? [String: Any],
                  let token = body["token"] as? String else {
                return
            }
            
            onActivationDetected?(token)
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                // Check for activation URLs
                if url.absoluteString.contains("session=") {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let session = components.queryItems?.first(where: { $0.name == "session" })?.value {
                        onActivationDetected?(session)
                    }
                }
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - Custom Header
struct CustomHeaderView: View {
    let webView: WKWebView?
    let title: String
    let subtitle: String
    var onRefresh: (() -> Void)? = nil
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Logo and title
                HStack(spacing: 12) {
                    Image("exon-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Navigation controls (only for home tab)
                if let webView = webView {
                    HStack(spacing: 8) {
                        // Back button
                        Button {
                            webView.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.medium))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15), in: Circle())
                                .foregroundStyle(.white)
                        }
                        .disabled(!webView.canGoBack)
                        .opacity(webView.canGoBack ? 1.0 : 0.4)
                        
                        // Forward button
                        Button {
                            webView.goForward()
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.title3.weight(.medium))
                                .frame(width: 36, height: 36)
                                .background(.white.opacity(0.15), in: Circle())
                                .foregroundStyle(.white)
                        }
                        .disabled(!webView.canGoForward)
                        .opacity(webView.canGoForward ? 1.0 : 0.4)
                        
                        // Refresh button
                        Button {
                            withAnimation(.easeInOut(duration: 0.6)) {
                                isRefreshing = true
                            }
                            webView.reload()
                            onRefresh?()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation {
                                    isRefreshing = false
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3.weight(.medium))
                                .frame(width: 36, height: 36)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "E70E3C"), Color(hex: "33E7BB")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Circle()
                                )
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.top, 8)
            .background {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.black.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            }
            
            // Separator
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: "33E7BB").opacity(0.6), Color(hex: "E70E3C").opacity(0.4)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 2)
        }
    }
}

// MARK: - Data Models
struct StoredProduct: Identifiable, Codable {
    let id = UUID()
    let sessionToken: String
    let productName: String
    let productImage: String
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let status: String // "ready", "activated", "expired"
    let vendor: String?
    let addedAt: Date?
    let activatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
        case productName = "product_name"
        case productImage = "product_image"
        case productKey = "product_key"
        case productKeys = "product_keys"
        case region
        case status
        case vendor
        case addedAt = "added_at"
        case activatedAt = "activated_at"
    }
}
