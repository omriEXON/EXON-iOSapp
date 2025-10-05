import UIKit
import Intercom

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Initialize Intercom
        Intercom.setApiKey("ios_sdk-5e5431124536209e7211c9d514f4cb4beac2b76a",
                          forAppId: "uygd8ocd")
        Intercom.setLauncherVisible(false)
        Intercom.loginUnidentifiedUser()
        
        return true
    }
    
    func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        DeepLinkHandler.shared.handle(url)
        return true
    }
}
