import SwiftUI
import Intercom

@main
struct EXON_StoreApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler.shared
    
    init() {
        // Initialize Intercom
        Intercom.setApiKey("ios_sdk-5e5431124536209e7211c9d514f4cb4beac2b76a", forAppId: "uygd8ocd")
        Intercom.setLauncherVisible(false)
        Intercom.loginUnidentifiedUser()
        
        // Log app launch
        print("[EXON] App launched")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deepLinkHandler)
                .onOpenURL { url in
                    print("[EXON] Received URL: \(url)")
                    deepLinkHandler.handle(url)
                }
                .onAppear {
                    // Register for notifications if needed
                    registerForNotifications()
                }
        }
    }
    
    private func registerForNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("[EXON] Notification permission granted")
            } else if let error = error {
                print("[EXON] Notification permission error: \(error)")
            }
        }
    }
}
