import SwiftUI
import WebKit

// MARK: - Main Activation View
struct ActivationOverlay: View {
    let sessionToken: String
    let onDismiss: () -> Void
    
    @StateObject private var manager = ActivationManager.shared
    @State private var showWebView = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            // Content based on state
            VStack {
                switch manager.activationState {
                case .idle:
                    LoadingCard(message: "מאתחל...")
                    
                case .fetchingProduct:
                    LoadingCard(message: "טוען פרטי מוצר...")
                    
                case .validatingKey:
                    LoadingCard(message: "מאמת רישיון...")
                    
                case .checkingGamePass:
                    LoadingCard(message: "בודק מנוי Game Pass...")
                    
                case .capturingToken:
                    ActivationLoadingCard(
                        product: manager.currentProduct,
                        stage: .capturingToken
                    )
                    
                case .activating:
                    ActivationLoadingCard(
                        product: manager.currentProduct,
                        stage: .activating
                    )
                    
                case .handlingConversion:
                    ActivationLoadingCard(
                        product: manager.currentProduct,
                        stage: .conversion
                    )
                    
                case .success(let productName, let keys):
                    SuccessCard(
                        productName: productName,
                        keys: keys,
                        onDismiss: onDismiss
                    )
                    
                case .partialSuccess(let succeeded, let total, let failed):
                    PartialSuccessCard(
                        succeeded: succeeded,
                        total: total,
                        failed: failed,
                        onDismiss: onDismiss
                    )
                    
                case .error(let message):
                    ErrorCard(
                        message: message,
                        onRetry: { Task { await manager.startActivation(sessionToken: sessionToken) } },
                        onDismiss: onDismiss
                    )
                    
                case .alreadyOwned(let products):
                    AlreadyOwnedCard(
                        products: products,
                        onDismiss: onDismiss
                    )
                    
                case .alreadyRedeemed:
                    RedeemedCard(
                        product: manager.currentProduct,
                        onSupport: openSupport,
                        onDismiss: onDismiss
                    )
                    
                case .regionMismatch(let accountRegion, let keyRegion):
                    RegionMismatchCard(
                        accountRegion: accountRegion,
                        keyRegion: keyRegion,
                        onDismiss: onDismiss
                    )
                    
                case .activeSubscription(let subscription):
                    ActiveSubscriptionCard(
                        subscription: subscription,
                        onDismiss: onDismiss
                    )
                    
                case .expiredSession:
                    ExpiredSessionCard(onDismiss: onDismiss)
                    
                case .requiresDigitalAccount:
                    DigitalAccountCard(
                        product: manager.currentProduct,
                        onOpenPortal: openPortal,
                        onDismiss: onDismiss
                    )
                }
            }
            .padding()
            
            // Hidden WebView for token capture
            if showWebView {
                MicrosoftWebView()
                    .frame(width: 1, height: 1)
                    .opacity(0)
            }
        }
        .task {
            await manager.startActivation(sessionToken: sessionToken)
        }
    }
    
    private func openSupport() {
        let whatsappNumber = "972557207138"
        let message = "שלום, אני צריך עזרה עם הפעלת המוצר שלי"
        let urlString = "https://wa.me/\(whatsappNumber)?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPortal() {
        if let portalUrl = manager.currentProduct?.portalUrl,
           let url = URL(string: portalUrl) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Loading Cards
struct LoadingCard: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text(message)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(40)
        .background(CardBackground())
    }
}

struct ActivationLoadingCard: View {
    let product: ActivationManager.Product?
    let stage: LoadingStage
    
    enum LoadingStage {
        case capturingToken
        case activating
        case conversion
    }
    
    var body: some View {
        VStack(spacing: 32) {
            ExonLogo()
            
            // Product Info
            if let product = product {
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: product.productImage ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 72, height: 72)
                    .cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.productName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.3))
                .cornerRadius(12)
            }
            
            // Loading Animation
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "33E7BB"), Color(hex: "E70E3C")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                
                Text(stageTitle)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text(stageMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            // Steps Indicator
            HStack(spacing: 24) {
                StepIndicator(
                    number: 1,
                    title: "אימות זהות",
                    isActive: stage == .capturingToken,
                    isCompleted: stage != .capturingToken
                )
                
                Rectangle()
                    .fill(stage != .capturingToken ? Color(hex: "33E7BB") : Color.white.opacity(0.2))
                    .frame(width: 40, height: 2)
                
                StepIndicator(
                    number: 2,
                    title: "הפעלת המוצר",
                    isActive: stage == .activating || stage == .conversion,
                    isCompleted: false
                )
            }
            .padding(.top)
            
            // Warning Note
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "33E7BB"))
                
                Text("אל תסגור את החלון. התהליך עשוי לקחת מספר שניות.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
        .padding(32)
        .background(CardBackground())
    }
    
    private var progress: CGFloat {
        switch stage {
        case .capturingToken: return 0.4
        case .activating: return 0.8
        case .conversion: return 0.9
        }
    }
    
    private var iconName: String {
        switch stage {
        case .capturingToken: return "lock.shield"
        case .activating: return "key.fill"
        case .conversion: return "arrow.triangle.2.circlepath"
        }
    }
    
    private var stageTitle: String {
        switch stage {
        case .capturingToken: return "אימות זהות"
        case .activating: return "מפעיל את המוצר"
        case .conversion: return "מטפל בהמרת Game Pass"
        }
    }
    
    private var stageMessage: String {
        switch stage {
        case .capturingToken: return "מאמת את החשבון שלך ב-Microsoft..."
        case .activating: return "ממש את הקוד בחשבון Microsoft שלך..."
        case .conversion: return "מבצע המרה ל-Game Pass..."
        }
    }
    
    private var statusText: String {
        switch stage {
        case .capturingToken: return "מאמת..."
        case .activating: return "מפעיל..."
        case .conversion: return "ממיר..."
        }
    }
}

// MARK: - Success Cards
struct SuccessCard: View {
    let productName: String
    let keys: [String]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            ExonLogo()
            
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "33E7BB").opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "33E7BB"))
            }
            
            VStack(spacing: 8) {
                Text("המוצר הופעל בהצלחה")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(productName)
                    .font(.headline)
                    .foregroundColor(Color(hex: "33E7BB"))
            }
            
            if keys.count > 1 {
                Text("הופעלו \(keys.count) מפתחות")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://account.microsoft.com/services") {
                        UIApplication.shared.open(url)
                    }
                    onDismiss()
                }) {
                    Label("השירותים שלי", systemImage: "gamecontroller")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "E70E3C"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("סגור")
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
        .padding(32)
        .background(CardBackground())
    }
}

struct PartialSuccessCard: View {
    let succeeded: Int
    let total: Int
    let failed: [(key: String, error: String)]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            // Warning Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("הופעלו \(succeeded) מתוך \(total) מוצרים")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("\(total - succeeded) מוצרים לא הופעלו")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
            
            // Failed Keys List
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
                    Text("השירותים שלי")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "E70E3C"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    openSupport()
                }) {
                    Text("תמיכה")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
    
    private func openSupport() {
        let whatsappNumber = "972557207138"
        let message = "שלום, חלק מהמפתחות שלי לא הופעלו"
        let urlString = "https://wa.me/\(whatsappNumber)?text=\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Error Cards
struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("אירעה שגיאה")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button(action: onRetry) {
                    Label("נסה שוב", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "E70E3C"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("ביטול")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
}

struct RedeemedCard: View {
    let product: ActivationManager.Product?
    let onSupport: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("הקוד כבר מומש")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("קוד זה כבר הופעל בחשבון Microsoft מסוים.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 12) {
                Text("אם אתה מאמין שזו טעות או שהקוד שלך לא הופעל כראוי, אנא צור קשר עם התמיכה שלנו.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                
                Text("פנה לתמיכה שלנו בווטסאפ לקבלת עזרה מיידית")
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: "33E7BB"))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            HStack(spacing: 16) {
                Button(action: onSupport) {
                    Label("תמיכה", systemImage: "message.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
}

struct AlreadyOwnedCard: View {
    let products: [String]
    let onDismiss: () -> Void
    
    var body: some View {
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
            
            VStack(spacing: 8) {
                Text("המוצר כבר ברשותך")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("חשבון Microsoft שלך כבר מכיל את המוצר הזה או מוצרים דומים.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            if !products.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("המוצרים שכבר ברשותך:")
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
            
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://account.microsoft.com/services") {
                        UIApplication.shared.open(url)
                    }
                    onDismiss()
                }) {
                    Text("למוצרים שלי")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
}

// MARK: - Special State Cards
struct RegionMismatchCard: View {
    let accountRegion: String
    let keyRegion: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("אזור החשבון אינו תואם לאזור המפתח")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("אזור המפתח:")
                        Spacer()
                        Text(keyRegion)
                            .foregroundColor(Color(hex: "33E7BB"))
                    }
                    
                    HStack {
                        Text("אזור החשבון שלך:")
                        Spacer()
                        Text(accountRegion)
                            .foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("כיצד לשנות את אזור החשבון:")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                ForEach(1...4, id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step).")
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "33E7BB"))
                            .frame(width: 20, alignment: .leading)
                        
                        Text(getStepText(step))
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
                    Text("ביטול")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
    
    private func getStepText(_ step: Int) -> String {
        switch step {
        case 1: return "לחץ על \"עבור להגדרות פרופיל\" למטה"
        case 2: return "בכרטיסיה \"המידע שלך\", מצא את שדה \"מדינה/אזור\""
        case 3: return "שנה את האזור ל-\(keyRegion)"
        case 4: return "שמור את השינויים וחזור לכאן"
        default: return ""
        }
    }
}

struct ActiveSubscriptionCard: View {
    let subscription: ActivationManager.ActiveSubscription
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("יש לך כבר מנוי Game Pass פעיל")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("מנוי פעיל:")
                        Spacer()
                        Text(subscription.name)
                            .foregroundColor(Color(hex: "33E7BB"))
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
                .font(.subheadline)
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }
            
            if subscription.hasPaymentIssue {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    
                    Text("יש בעיית תשלום עם המנוי הקיים. כדאי לבדוק את אמצעי התשלום או לבטל את המנוי.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            Text("לא ניתן להפעיל מנוי Game Pass נוסף כאשר יש לך כבר מנוי פעיל.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
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
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
}

struct ExpiredSessionCard: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "clock.badge.xmark.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("תוקף ההפעלה פג")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("קישור ההפעלה שלך פג תוקף מסיבות אבטחה.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Text("כל קישור הפעלה תקף למשך שעה אחת בלבד. זהו אמצעי אבטחה להגנה על המוצר שלך.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("כיצד להפעיל את המוצר שלך:")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                
                ForEach(1...3, id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(step).")
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "33E7BB"))
                            .frame(width: 20, alignment: .leading)
                        
                        Text(getExpiredStepText(step))
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
                    if let url = URL(string: "https://exongames.co.il/account") {
                        UIApplication.shared.open(url)
                    }
                    onDismiss()
                }) {
                    Text("חזור להזמנה שלי")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "E70E3C"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("סגור")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
    
    private func getExpiredStepText(_ step: Int) -> String {
        switch step {
        case 1: return "חזור לעמוד ההזמנה שלך באתר EXON"
        case 2: return "לחץ שוב על כפתור \"הפעל\" ליד המוצר"
        case 3: return "תועבר לכאן עם קישור הפעלה חדש"
        default: return ""
        }
    }
}

struct DigitalAccountCard: View {
    let product: ActivationManager.Product?
    let onOpenPortal: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ExonLogo()
            
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("התחבר לחשבון הדיגיטלי שלך")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                
                Text("המוצר שרכשת מגיע עם חשבון דיגיטלי ייעודי להפעלה.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                if let orderNumber = product?.orderNumber {
                    Text("הזמנה \(orderNumber)")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(hex: "33E7BB").opacity(0.2))
                        .foregroundColor(Color(hex: "33E7BB"))
                        .cornerRadius(12)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach(1...3, id: \.self) { step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "33E7BB").opacity(0.2))
                                .frame(width: 32, height: 32)
                            
                            Text("\(step)")
                                .font(.caption.bold())
                                .foregroundColor(Color(hex: "33E7BB"))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(getDigitalStepTitle(step))
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            
                            Text(getDigitalStepDescription(step, productName: product?.productName ?? "המוצר"))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            if product?.portalUrl != nil {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("גישה מאובטחת לפורטל מוכנה")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            HStack(spacing: 16) {
                Button(action: onOpenPortal) {
                    Label("צפה בפרטי החשבון", systemImage: "folder.badge.person.crop")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "E70E3C"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: onDismiss) {
                    Text("ביטול")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .padding(32)
        .background(CardBackground())
    }
    
    private func getDigitalStepTitle(_ step: Int) -> String {
        switch step {
        case 1: return "צפה בפרטי החשבון"
        case 2: return "התחבר לחשבון הדיגיטלי"
        case 3: return "חזור לכאן להפעלה"
        default: return ""
        }
    }
    
    private func getDigitalStepDescription(_ step: Int, productName: String) -> String {
        switch step {
        case 1: return "לחץ על הכפתור למטה לצפייה בחשבון הדיגיטלי עבור \(productName)"
        case 2: return "לחץ על תמונת הפרופיל שלך למעלה ← בחר \"החלף חשבון\" או \"התנתק\" והתחבר עם הפרטים שבפורטל"
        case 3: return "המוצר יופעל אוטומטית על החשבון הדיגיטלי"
        default: return ""
        }
    }
}

// MARK: - Helper Views
struct StepIndicator: View {
    let number: Int
    let title: String
    let isActive: Bool
    let isCompleted: Bool
    
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
                        .stroke(Color(hex: "33E7BB"), lineWidth: 2)
                        .frame(width: 42, height: 42)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isActive)
                }
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(textColor)
        }
    }
    
    private var backgroundColor: Color {
        if isCompleted {
            return Color(hex: "33E7BB")
        } else if isActive {
            return Color(hex: "E70E3C")
        } else {
            return Color.white.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        if isCompleted || isActive {
            return .white
        } else {
            return .white.opacity(0.5)
        }
    }
}

struct ExonLogo: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("exon-logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 30)
                .foregroundColor(.white)
            
            Text("מנהל רישיונות")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [
                        Color(hex: "1C1A1D"),
                        Color(hex: "1C1A1D").opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "33E7BB").opacity(0.3),
                                Color(hex: "E70E3C").opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }
}

// MARK: - WebView for Token Capture
struct MicrosoftWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        let url = URL(string: "https://account.microsoft.com/")!
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
