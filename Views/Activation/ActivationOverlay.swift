// CompleteActivationCards.swift
// Complete 1:1 port of Chrome Extension activation UI
// Includes ALL cards, animations, and mobile optimizations

import SwiftUI
import WebKit

// MARK: - Configuration & Colors
extension Color {
    static let exonBg = Color(hex: "1C1A1D")
    static let exonRed = Color(hex: "E70E3C")
    static let exonMint = Color(hex: "33E7BB")
    static let exonWarning = Color(hex: "FFA726")
    static let exonError = Color(hex: "F44336")
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Hebrew Translations (from Chrome Extension)
struct HebrewI18n {
    static let activateTitle = "הפעלת מוצר"
    static let activateLead = "בלחיצה על \"הפעל\" הנך מאשר/ת:"
    static let bulletTermsPrefix = "מסכים/ה לתנאי Microsoft –"
    static let termsSale = "תנאי מכירה"
    static let termsUse = "תנאי שימוש בחנות"
    static let termsDigital = "כללי שימוש למוצרים דיגיטליים"
    static let bulletData = "מסכים/ה ל-EXON להשתמש בנתוני הגישה והזיהוי שלך ובמידע הנלווה, לצורך הפעלת המוצר בחשבון Microsoft שלך."
    static let note = "ההחלטה חלה על הפעלה זו בלבד. איננו שומרים את ההפעלה לשימוש מאוחר יותר."
    static let btnActivate = "הפעל"
    static let btnCancel = "ביטול"
    static let btnSupport = "תמיכה"
    static let statusCapture = "🔍 לוכד אסימון אימות..."
    static let statusRedeem = "🔄 מאמת וממש את הקוד..."
    static let statusFetchingProduct = "🔍 טוען פרטי מוצר..."
    static let successTitle = "המוצר הופעל בהצלחה"
    static let successGoServices = "לשירותים שלי"
    static let successGoOrders = "להיסטוריית הרכישות"
    static let reviewTitle = "נהנית מהתהליך? נשמח לשמוע!"
    static let reviewText = "המשוב שלך עוזר לנו לשפר את החוויה."
    static let reviewCta = "כתבו ביקורת"
    static let testBadge = "מצב בדיקה: הפעלה מפרמטרים ב-URL"
    static let loadingProduct = "טוען פרטי מוצר..."
    static let errorLoadingProduct = "שגיאה בטעינת פרטי המוצר"
    static let errorGeneric = "אירעה שגיאה. אנא נסה שוב."
    static let redeemedTitle = "הקוד כבר מומש"
    static let redeemedMessage = "קוד זה כבר הופעל בחשבון Microsoft מסוים."
    static let redeemedNote = "אם אתה מאמין שזו טעות או שהקוד שלך לא הופעל כראוי, אנא צור קשר עם התמיכה שלנו."
    static let contactSupport = "פנה לתמיכה שלנו בווטסאפ לקבלת עזרה מיידית"
    static let errorTitle = "אירעה שגיאה"
    static let errorMessage = "לא הצלחנו לטעון את פרטי המוצר בשל בעיה טכנית."
    static let errorDetail = "ייתכן שיש בעיה עם האזור הגיאוגרפי או עם הגדרות המוצר."
    static let errorContactSupport = "אנא צור קשר עם צוות התמיכה שלנו כדי לפתור את הבעיה במהירות."
    static let errorSupportHint = "צוות התמיכה שלנו זמין לעזור לך"
    static let alreadyOwnedTitle = "המוצר כבר ברשותך"
    static let alreadyOwnedMessage = "חשבון Microsoft שלך כבר מכיל את המוצר הזה או מוצרים דומים."
    static let alreadyOwnedDetail = "לא ניתן להפעיל מוצר זהה פעמיים באותו חשבון."
    static let alreadyOwnedProducts = "המוצרים שכבר ברשותך:"
    static let alreadyOwnedNote = "אם ברצונך להפעיל את הקוד עבור מישהו אחר, עליך להתנתק מהחשבון הנוכחי ולהתחבר לחשבון Microsoft אחר."
    static let alreadyOwnedHint = "ניתן גם להעביר את הקוד למישהו אחר או לשמור אותו לשימוש עתידי."
    static let goToServices = "למוצרים שלי"
    static let switchAccount = "החלף חשבון"
    static let expiredTitle = "תוקף ההפעלה פג"
    static let expiredMessage = "קישור ההפעלה שלך פג תוקף מסיבות אבטחה."
    static let expiredExplanation = "כל קישור הפעלה תקף למשך שעה אחת בלבד. זהו אמצעי אבטחה להגנה על המוצר שלך."
    static let expiredHowToFix = "כיצד להפעיל את המוצר שלך:"
    static let expiredStep1 = "חזור לעמוד ההזמנה שלך באתר EXON"
    static let expiredStep2 = "לחץ שוב על כפתור \"הפעל\" ליד המוצר"
    static let expiredStep3 = "תועבר לכאן עם קישור הפעלה חדש"
    static let expiredNote = "הקוד שלך עדיין ממתין לך ולא נעשה בו שימוש."
    static let btnBackToOrder = "חזור להזמנה שלי"
    static let btnContactSupport = "פנה לתמיכה"
    static let expiredTimeAgo = "פג לפני"
    static let minutes = "דקות"
    static let hours = "שעות"
    static let justNow = "הרגע"
}

// MARK: - Data Models
struct Product {
    let productName: String
    let productImage: String?
    let productKey: String?
    let productKeys: [String]?
    let region: String
    let status: String?
    let vendor: String?
    let fromUrl: Bool
    let orderNumber: String?
    let portalUrl: String?
    let sessionToken: String?
    let activationMethod: String?
    let expiresAt: Date?
}

struct ActiveSubscription {
    let name: String
    let productId: String
    let endDate: String?
    let daysRemaining: Int?
    let hasPaymentIssue: Bool
    let autorenews: Bool
}

// MARK: - Main Overlay Container
struct ActivationOverlay: View {
    let sessionToken: String?
    let testLicense: String?
    let pendingActivation: Product?
    let onDismiss: () -> Void
    
    @State private var currentCard: CardType = .loading
    @State private var product: Product?
    @State private var errorMessage: String = ""
    @State private var ownedProducts: [String] = []
    @State private var activeSubscription: ActiveSubscription?
    @State private var accountRegion: String = ""
    @State private var succeeded: Int = 0
    @State private var failed: [(key: String, error: String)] = []
    @State private var total: Int = 0
    
    enum CardType {
        case loading
        case activation
        case activationLoading(stage: LoadingStage)
        case success
        case partialSuccess
        case redeemed
        case error
        case alreadyOwned
        case expired
        case regionMismatch
        case activeSubscription
        case digitalAccount
        case cookiesDisabled
        case notLoggedIn
    }
    
    enum LoadingStage {
        case capture, redeem
    }
    
    var body: some View {
        ZStack {
            // Dark overlay background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // Card content
            cardContent()
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .pad ? 760 : .infinity)
                .padding(UIDevice.current.userInterfaceIdiom == .phone ? 16 : 28)
        }
        .environment(\.layoutDirection, .rightToLeft) // RTL for Hebrew
        .onAppear {
            initializeActivation()
        }
    }
    
    @ViewBuilder
    private func cardContent() -> some View {
        switch currentCard {
        case .loading:
            LoadingCard()
            
        case .activation:
            if let product = product {
                ActivationCard(
                    product: product,
                    onActivate: handleActivation,
                    onCancel: onDismiss
                )
            }
            
        case .activationLoading(let stage):
            if let product = product {
                ActivationLoadingCard(product: product, stage: stage)
            }
            
        case .success:
            SuccessCard(
                productName: product?.productName ?? "",
                onDismiss: onDismiss
            )
            
        case .partialSuccess:
            PartialSuccessCard(
                succeeded: succeeded,
                total: total,
                failed: failed,
                onDismiss: onDismiss
            )
            
        case .redeemed:
            RedeemedCard(product: product, onDismiss: onDismiss)
            
        case .error:
            ErrorCard(message: errorMessage, onDismiss: onDismiss)
            
        case .alreadyOwned:
            AlreadyOwnedCard(
                products: ownedProducts,
                onDismiss: onDismiss
            )
            
        case .expired:
            ExpiredSessionCard(
                sessionToken: sessionToken ?? "",
                onDismiss: onDismiss
            )
            
        case .regionMismatch:
            RegionMismatchCard(
                accountRegion: accountRegion,
                keyRegion: product?.region ?? "",
                onDismiss: onDismiss
            )
            
        case .activeSubscription:
            if let subscription = activeSubscription {
                ActiveSubscriptionCard(
                    subscription: subscription,
                    onDismiss: onDismiss
                )
            }
            
        case .digitalAccount:
            if let product = product {
                DigitalAccountCard(
                    product: product,
                    onDismiss: onDismiss
                )
            }
            
        case .cookiesDisabled:
            CookiesDisabledCard(onDismiss: onDismiss)
            
        case .notLoggedIn:
            NotLoggedInCard(onDismiss: onDismiss)
        }
    }
    
    private func initializeActivation() {
        // Match Chrome extension initialization logic
        guard sessionToken != nil || testLicense != nil || pendingActivation != nil else {
            onDismiss()
            return
        }
        
        // Start the activation flow
        currentCard = .loading
        
        // Simulate product loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Create test product for demo
            self.product = Product(
                productName: testLicense != nil ? "Test Product" : "Microsoft Product",
                productImage: "https://store-images.s-microsoft.com/image/apps.28274.13537095652231823.aa1fc8dc-8517-4d40-a5ac-553a21f159e9.a5630217-dea7-46ae-846e-02bc04a452fe",
                productKey: testLicense,
                productKeys: nil,
                region: "IL",
                status: "ready",
                vendor: "Microsoft Store",
                fromUrl: testLicense != nil,
                orderNumber: nil,
                portalUrl: nil,
                sessionToken: sessionToken,
                activationMethod: nil,
                expiresAt: nil
            )
            currentCard = .activation
        }
    }
    
    private func handleActivation() {
        currentCard = .activationLoading(stage: .capture)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            currentCard = .activationLoading(stage: .redeem)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                currentCard = .success
            }
        }
    }
}

// MARK: - Card Background Component
struct CardBackground: View {
    var body: some View {
        ZStack {
            // Main gradient
            LinearGradient(
                stops: [
                    .init(color: .exonBg, location: 0),
                    .init(color: .exonBg.opacity(0.95), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Radial gradient overlay
            RadialGradient(
                colors: [Color.white.opacity(0.08), .clear],
                center: UnitPoint(x: 0.8, y: -0.1),
                startRadius: 0,
                endRadius: UIScreen.main.bounds.width * 0.6
            )
            
            // Color accent
            LinearGradient(
                colors: [
                    .exonRed.opacity(0.24),
                    .exonBg.opacity(0.4),
                    .exonMint.opacity(0.22)
                ],
                startPoint: UnitPoint(x: 1.6, y: -0.1),
                endPoint: .bottomLeading
            )
        }
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.exonMint.opacity(0.3), .exonRed.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.45), radius: 40, y: 14)
    }
}

// MARK: - Logo Component
struct ExonLogo: View {
    var body: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .foregroundColor(.white)
            Text("EXON")
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
        }
        .frame(width: 124, height: 30)
    }
}

// MARK: - Loading Card
struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 0) {
            CardBackground()
                .overlay(
                    VStack(spacing: 20) {
                        ExonLogo()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text(HebrewI18n.loadingProduct)
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .padding(40)
                )
        }
    }
}

// MARK: - Main Activation Card
struct ActivationCard: View {
    let product: Product
    let onActivate: () -> Void
    let onCancel: () -> Void
    
    @State private var isActivating = false
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 0) {
                // Logo positioned top-right
                HStack {
                    Spacer()
                    ExonLogo()
                        .padding(.top, 18)
                        .padding(.trailing, 18)
                }
                
                VStack(spacing: 18) {
                    // Product Section
                    ProductSection(product: product)
                    
                    // Activation Section
                    ActivationSection()
                    
                    // Actions
                    HStack(spacing: 12) {
                        Button(action: {
                            isActivating = true
                            onActivate()
                        }) {
                            HStack {
                                if isActivating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Text(HebrewI18n.btnActivate)
                                }
                            }
                            .frame(minWidth: 140)
                            .padding(.horizontal, 26)
                            .padding(.vertical, 12)
                            .background(Color.exonRed)
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .heavy))
                            .cornerRadius(10)
                            .shadow(color: .exonRed.opacity(0.35), radius: 24, y: 10)
                        }
                        .disabled(isActivating)
                        
                        Button(action: onCancel) {
                            Text(HebrewI18n.btnCancel)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                )
                        }
                    }
                    
                    if product.fromUrl {
                        TestBadge()
                    }
                }
                .padding(.horizontal, mobileAdjusted(28, 18))
                .padding(.bottom, 26)
            }
        }
    }
}

// MARK: - Product Section
struct ProductSection: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 16) {
            // Product Image
            AsyncImage(url: URL(string: product.productImage ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: mobileAdjusted(84, 72), height: mobileAdjusted(84, 72))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.productName)
                    .font(.system(size: mobileAdjusted(24, 20), weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                StatusBadge(status: product.status ?? "ready")
            }
            
            Spacer()
        }
        .padding(14)
        .padding(.trailing, 100) // Space for logo
        .background(Color.exonBg.opacity(0.28))
        .background(.ultraThinMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - Activation Section
struct ActivationSection: View {
    @State private var pulseAnimation = false
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon and Title
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.exonMint.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .scaleEffect(pulseAnimation ? 1.2 : 1)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 2).repeatForever(autoreverses: false), value: pulseAnimation)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.exonMint)
                }
                .onAppear { pulseAnimation = true }
                
                Text(HebrewI18n.activateTitle)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: .exonMint.opacity(0.3), radius: 8, y: 2)
            }
            
            Text(HebrewI18n.activateLead)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
            
            // Terms
            VStack(spacing: 20) {
                TermItem(
                    icon: "checkmark.circle.fill",
                    text: HebrewI18n.bulletTermsPrefix,
                    links: [
                        (HebrewI18n.termsSale, "https://www.microsoft.com/legal/terms-of-use"),
                        (HebrewI18n.termsUse, "https://www.microsoft.com/store/terms"),
                        (HebrewI18n.termsDigital, "https://www.microsoft.com/legal/usage-rules")
                    ]
                )
                
                TermItem(
                    icon: "checkmark.circle.fill",
                    text: HebrewI18n.bulletData
                )
            }
            
            // Note
            NoteBox(text: HebrewI18n.note)
        }
        .padding(mobileAdjusted(32, 24))
        .background(
            LinearGradient(
                colors: [.exonBg.opacity(0.4), .exonBg.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.exonMint.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 32, y: 8)
        .overlay(
            // Shimmer animation
            LinearGradient(
                colors: [.clear, .exonMint.opacity(0.3), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 100, height: 3)
            .offset(x: shimmerOffset)
            .onAppear {
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    shimmerOffset = 200
                }
            }
            , alignment: .top
        )
    }
}

// MARK: - Activation Loading Card
struct ActivationLoadingCard: View {
    let product: Product
    let stage: ActivationOverlay.LoadingStage
    
    @State private var iconPulse = false
    @State private var progressAnimation = false
    
    var stageConfig: (icon: String, title: String, message: String, progress: CGFloat) {
        switch stage {
        case .capture:
            return ("lock.shield.fill", "אימות זהות", "מאמת את החשבון שלך ב-Microsoft...", 0.4)
        case .redeem:
            return ("key.fill", "מפעיל את המוצר", "ממש את הקוד בחשבון Microsoft שלך...", 0.8)
        }
    }
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 32) {
                ExonLogo()
                
                // Product info (faded)
                ProductSection(product: product)
                    .opacity(0.7)
                
                // Loading animation
                VStack(spacing: 24) {
                    // Progress circle with icon
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 4)
                            .frame(width: 100, height: 100)
                        
                        Circle()
                            .trim(from: 0, to: stageConfig.progress)
                            .stroke(
                                LinearGradient(
                                    colors: [.exonMint, .exonRed],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: stageConfig.progress)
                        
                        Image(systemName: stageConfig.icon)
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .scaleEffect(iconPulse ? 1.1 : 1)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: iconPulse)
                    }
                    .onAppear { iconPulse = true }
                    
                    VStack(spacing: 12) {
                        Text(stageConfig.title)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(stageConfig.message)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    // Steps indicator
                    StepsIndicator(currentStage: stage)
                    
                    // Warning note
                    NoteBox(
                        text: "אל תסגור את החלון. התהליך עשוי לקחת מספר שניות.",
                        icon: "info.circle.fill",
                        color: .exonMint
                    )
                }
                .padding(mobileAdjusted(32, 24))
            }
        }
    }
}

// MARK: - Success Card
struct SuccessCard: View {
    let productName: String
    let onDismiss: () -> Void
    
    @State private var checkmarkAnimation = false
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 32) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .stroke(Color.exonMint.opacity(0.2), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: checkmarkAnimation ? 1 : 0)
                        .stroke(Color.exonMint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.6), value: checkmarkAnimation)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.exonMint)
                        .scaleEffect(checkmarkAnimation ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.4), value: checkmarkAnimation)
                }
                .onAppear { checkmarkAnimation = true }
                
                Text(HebrewI18n.successTitle)
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundColor(.white)
                
                // Action buttons
                VStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/services") {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(HebrewI18n.successGoServices)
                            .frame(width: 180)
                            .padding(.vertical, 14)
                            .background(Color.exonRed)
                            .foregroundColor(.white)
                            .font(.system(size: 15, weight: .bold))
                            .cornerRadius(10)
                            .shadow(color: .exonRed.opacity(0.35), radius: 24, y: 10)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/billing/orders") {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(HebrewI18n.successGoOrders)
                            .frame(width: 180)
                            .padding(.vertical, 14)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                // Review section
                VStack(spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    VStack(spacing: 8) {
                        Text(HebrewI18n.reviewTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                        
                        Text(HebrewI18n.reviewText)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://apps.apple.com/app/id123456789") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text(HebrewI18n.reviewCta)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.exonMint)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.exonMint.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.exonMint, lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }
                }
                .padding(.top, 20)
            }
            .padding(mobileAdjusted(40, 30))
        }
    }
}

// MARK: - Partial Success Card (for Bundles)
struct PartialSuccessCard: View {
    let succeeded: Int
    let total: Int
    let failed: [(key: String, error: String)]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("הופעלו \(succeeded) מתוך \(total) מוצרים")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(total - succeeded) מוצרים לא הופעלו")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                
                // Failed items list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(failed, id: \.key) { item in
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(item.error)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/services") {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(HebrewI18n.successGoServices)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.exonRed)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        openWhatsApp(message: "שלום, חלק מהמפתחות שלי לא הופעלו")
                    }) {
                        Text(HebrewI18n.btnSupport)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Redeemed Card
struct RedeemedCard: View {
    let product: Product?
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                if let product = product {
                    ProductSection(product: product)
                        .opacity(0.7)
                }
                
                VStack(spacing: 24) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.orange)
                    
                    Text(HebrewI18n.redeemedTitle)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(HebrewI18n.redeemedMessage)
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 12) {
                        NoteBox(
                            text: HebrewI18n.redeemedNote,
                            icon: "info.circle.fill",
                            color: .orange
                        )
                        
                        Text(HebrewI18n.contactSupport)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.exonMint)
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            openWhatsApp(message: HebrewI18n.redeemedNote)
                        }) {
                            Label(HebrewI18n.btnSupport, systemImage: "message.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: onDismiss) {
                            Text(HebrewI18n.btnCancel)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(mobileAdjusted(32, 24))
            }
        }
    }
}

// MARK: - Error Card
struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.red)
                
                Text(HebrewI18n.errorTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(message.isEmpty ? HebrewI18n.errorMessage : message)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text(HebrewI18n.errorDetail)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                NoteBox(
                    text: HebrewI18n.errorContactSupport,
                    icon: "info.circle.fill",
                    color: .red
                )
                
                HStack(spacing: 16) {
                    Button(action: {
                        openWhatsApp(message: HebrewI18n.errorGeneric)
                    }) {
                        Label(HebrewI18n.btnSupport, systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onDismiss) {
                        Text(HebrewI18n.btnCancel)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Already Owned Card
struct AlreadyOwnedCard: View {
    let products: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                }
                
                Text(HebrewI18n.alreadyOwnedTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(HebrewI18n.alreadyOwnedMessage)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                Text(HebrewI18n.alreadyOwnedDetail)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                if !products.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(HebrewI18n.alreadyOwnedProducts)
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                        
                        ForEach(products, id: \.self) { product in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(product)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                
                NoteBox(
                    text: HebrewI18n.alreadyOwnedNote,
                    icon: "info.circle.fill",
                    color: .blue
                )
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/services") {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(HebrewI18n.goToServices)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let url = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/logout") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text(HebrewI18n.switchAccount)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                Text(HebrewI18n.alreadyOwnedHint)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Expired Session Card
struct ExpiredSessionCard: View {
    let sessionToken: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                Image(systemName: "clock.badge.xmark.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                
                Text(HebrewI18n.expiredTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(HebrewI18n.expiredMessage)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                
                Text(HebrewI18n.expiredExplanation)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(HebrewI18n.expiredHowToFix)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(1...3, id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(step).")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.exonMint)
                                .frame(width: 20)
                            
                            Text(expiredStepText(step))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                NoteBox(
                    text: HebrewI18n.expiredNote,
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://exongames.co.il/account") {
                            UIApplication.shared.open(url)
                        }
                        onDismiss()
                    }) {
                        Text(HebrewI18n.btnBackToOrder)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.exonRed)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        openWhatsApp(message: "תוקף ההפעלה שלי פג")
                    }) {
                        Text(HebrewI18n.btnContactSupport)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
    
    func expiredStepText(_ step: Int) -> String {
        switch step {
        case 1: return HebrewI18n.expiredStep1
        case 2: return HebrewI18n.expiredStep2
        case 3: return HebrewI18n.expiredStep3
        default: return ""
        }
    }
}

// MARK: - Region Mismatch Card
struct RegionMismatchCard: View {
    let accountRegion: String
    let keyRegion: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                
                Text("אזור החשבון אינו תואם לאזור המפתח")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    HStack {
                        Text("אזור המפתח:")
                        Spacer()
                        Text(keyRegion)
                            .foregroundColor(.exonMint)
                    }
                    
                    HStack {
                        Text("אזור החשבון שלך:")
                        Spacer()
                        Text(accountRegion)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                Text("כדי להפעיל את המוצר, עליך לשנות את אזור החשבון שלך להתאים לאזור המפתח.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("כיצד לשנות את אזור החשבון:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach(1...4, id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 24, height: 24)
                                Text("\(step)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(regionStepText(step))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/profile") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("עבור להגדרות פרופיל")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onDismiss) {
                        Text(HebrewI18n.btnCancel)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
    
    func regionStepText(_ step: Int) -> String {
        switch step {
        case 1: return "לחץ על \"עבור להגדרות פרופיל\" למטה"
        case 2: return "בכרטיסיה \"המידע שלך\", מצא את שדה \"מדינה/אזור\""
        case 3: return "שנה את האזור ל-\(keyRegion)"
        case 4: return "שמור את השינויים וחזור לכאן"
        default: return ""
        }
    }
}

// MARK: - Active Subscription Card
struct ActiveSubscriptionCard: View {
    let subscription: ActiveSubscription
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                
                Text("יש לך כבר מנוי Game Pass פעיל")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("מנוי פעיל:")
                        Spacer()
                        Text(subscription.name)
                            .foregroundColor(.exonMint)
                    }
                    
                    if let endDate = subscription.endDate {
                        HStack {
                            Text("תאריך סיום:")
                            Spacer()
                            Text(endDate)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    if let daysRemaining = subscription.daysRemaining {
                        HStack {
                            Text("ימים שנותרו:")
                            Spacer()
                            Text("\(daysRemaining)")
                                .foregroundColor(daysRemaining > 0 ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                if subscription.hasPaymentIssue {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        Text("יש בעיית תשלום עם המנוי הקיים")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Text("לא ניתן להפעיל מנוי Game Pass נוסף כאשר יש לך כבר מנוי פעיל.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("האפשרויות שלך:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach([
                        "בטל את המנוי הקיים בעמוד השירותים שלך",
                        "אם המנוי לא פעיל או לא משולם, בטל אותו ונסה שוב",
                        "שמור את הקוד להפעלה מאוחר יותר",
                        "העבר את הקוד לחשבון אחר או לחבר"
                    ], id: \.self) { option in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(option)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://account.microsoft.com/services") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("נהל מנויים")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button(action: onDismiss) {
                        Text(HebrewI18n.btnCancel)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Digital Account Card
struct DigitalAccountCard: View {
    let product: Product
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                ProductSection(product: product)
                
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                
                Text("התחבר לחשבון הדיגיטלי שלך")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("המוצר שרכשת מגיע עם חשבון דיגיטלי ייעודי להפעלה.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                if let orderNumber = product.orderNumber {
                    Text("הזמנה \(orderNumber)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.exonMint.opacity(0.2))
                        .foregroundColor(.exonMint)
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(1...3, id: \.self) { step in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.exonMint.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Text("\(step)")
                                    .font(.caption.bold())
                                    .foregroundColor(.exonMint)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(digitalStepTitle(step))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text(digitalStepDescription(step, productName: product.productName))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                if let portalUrl = product.portalUrl {
                    Button(action: {
                        if let url = URL(string: portalUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("צפה בפרטי החשבון", systemImage: "folder.badge.person.crop")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.exonRed)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                
                Button(action: onDismiss) {
                    Text(HebrewI18n.btnCancel)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
    
    func digitalStepTitle(_ step: Int) -> String {
        switch step {
        case 1: return "צפה בפרטי החשבון"
        case 2: return "התחבר לחשבון הדיגיטלי"
        case 3: return "חזור לכאן להפעלה"
        default: return ""
        }
    }
    
    func digitalStepDescription(_ step: Int, productName: String) -> String {
        switch step {
        case 1: return "לחץ על הכפתור למטה לצפייה בחשבון הדיגיטלי עבור \(productName)"
        case 2: return "לחץ על תמונת הפרופיל שלך למעלה ← בחר \"החלף חשבון\" או \"התנתק\" והתחבר עם הפרטים שבפורטל"
        case 3: return "המוצר יופעל אוטומטית על החשבון הדיגיטלי"
        default: return ""
        }
    }
}

// MARK: - Cookies Disabled Card
struct CookiesDisabledCard: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                // Cookie icon
                ZStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .fill(.white)
                        .frame(width: 36, height: 36)
                        .overlay(
                            ZStack {
                                ForEach([(26, 26, 3), (38, 28, 2.5), (30, 37, 3), (40, 38, 2)], id: \.0) { config in
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: CGFloat(config.2) * 2, height: CGFloat(config.2) * 2)
                                        .offset(x: CGFloat(config.0) - 32, y: CGFloat(config.1) - 32)
                                }
                            }
                        )
                }
                
                Text("עוגיות (Cookies) מושבתות")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("על מנת להפעיל את המוצר, הדפדפן צריך לאפשר שימוש בעוגיות עבור Microsoft.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("כיצד לאפשר עוגיות:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach([
                        "לחץ על כפתור הנעילה בשורת הכתובת למעלה",
                        "בחר \"הגדרות אתר\" או \"Site settings\"",
                        "שנה את \"Cookies\" ל-\"Allow\" או \"אפשר\"",
                        "רענן את העמוד"
                    ], id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                NoteBox(
                    text: "עוגיות נדרשות לצורך אימות מאובטח מול שרתי Microsoft.",
                    icon: "info.circle.fill",
                    color: .orange
                )
                
                Button(action: onDismiss) {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Not Logged In Card
struct NotLoggedInCard: View {
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            CardBackground()
            
            VStack(spacing: 24) {
                ExonLogo()
                
                ZStack {
                    Circle()
                        .fill(Color.exonRed)
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text("לא מחובר לחשבון Microsoft")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("כדי להפעיל את המוצר, עליך להיות מחובר לחשבון Microsoft שלך.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("כיצד להתחבר:")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    ForEach([
                        "לחץ על \"רענן עמוד\" למטה",
                        "המערכת תנתב אותך להתחברות Microsoft",
                        "הזן את פרטי החשבון שלך",
                        "לאחר ההתחברות, תחזור לכאן אוטומטית"
                    ], id: \.self) { step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.exonRed)
                            Text(step)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                
                NoteBox(
                    text: "ודא שאתה מתחבר עם החשבון הנכון שבו רכשת את המוצר.",
                    icon: "info.circle.fill",
                    color: .exonRed
                )
                
                Button(action: onDismiss) {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .padding(mobileAdjusted(32, 24))
        }
    }
}

// MARK: - Helper Components

struct TermItem: View {
    let icon: String
    let text: String
    let links: [(String, String)]?
    
    init(icon: String, text: String, links: [(String, String)]? = nil) {
        self.icon = icon
        self.text = text
        self.links = links
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.exonMint)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(text)
                        .foregroundColor(.white.opacity(0.95))
                    
                    if let links = links {
                        ForEach(links, id: \.0) { link in
                            Link(destination: URL(string: link.1)!) {
                                Text(link.0)
                                    .foregroundColor(.exonMint)
                                    .underline()
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            
                            if link != links.last {
                                Text(",")
                                    .foregroundColor(.white.opacity(0.95))
                            }
                        }
                    }
                }
                .font(.system(size: 15))
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.exonMint.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.exonMint.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct NoteBox: View {
    let text: String
    let icon: String = "info.circle.fill"
    let color: Color = Color.white.opacity(0.6)
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 14))
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(10)
    }
}

struct StatusBadge: View {
    let status: String
    
    var statusConfig: (text: String, color: Color) {
        switch status {
        case "ready": return ("מוכן להפעלה", .exonMint)
        case "activated": return ("הופעל", .gray)
        case "redeemed": return ("כבר מומש", .orange)
        case "expired": return ("פג תוקף", .orange)
        default: return ("לא ידוע", .gray)
        }
    }
    
    var body: some View {
        Text(statusConfig.text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(statusConfig.color)
    }
}

struct TestBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Text("🧪")
            Text(HebrewI18n.testBadge)
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.exonBg.opacity(0.22))
        .cornerRadius(10)
    }
}

struct StepsIndicator: View {
    let currentStage: ActivationOverlay.LoadingStage
    
    @State private var pulseAnimation = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Step 1
            StepCircle(
                number: 1,
                title: "אימות זהות",
                isActive: currentStage == .capture,
                isCompleted: currentStage == .redeem
            )
            
            // Connector line
            Rectangle()
                .fill(currentStage == .redeem ? Color.exonMint : Color.white.opacity(0.2))
                .frame(width: 60, height: 2)
                .animation(.easeInOut, value: currentStage)
            
            // Step 2
            StepCircle(
                number: 2,
                title: "הפעלת המוצר",
                isActive: currentStage == .redeem,
                isCompleted: false
            )
        }
        .padding(20)
        .background(Color.exonBg.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct StepCircle: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if isActive {
                    Circle()
                        .stroke(Color.exonMint, lineWidth: 2)
                        .frame(width: 36, height: 36)
                        .scaleEffect(pulseAnimation ? 1.5 : 1)
                        .opacity(pulseAnimation ? 0 : 1)
                        .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                }
            }
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(isActive || isCompleted ? .white : .white.opacity(0.6))
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return .exonMint
        } else if isActive {
            return Color.exonBg.opacity(0.5)
        } else {
            return Color.white.opacity(0.2)
        }
    }
}

// MARK: - Helper Functions
func openWhatsApp(message: String) {
    let whatsappNumber = "972557207138"
    let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://wa.me/\(whatsappNumber)?text=\(encoded)"
    
    if let url = URL(string: urlString) {
        UIApplication.shared.open(url)
    }
}

func mobileAdjusted(_ regular: CGFloat, _ mobile: CGFloat) -> CGFloat {
    return UIDevice.current.userInterfaceIdiom == .phone ? mobile : regular
}
