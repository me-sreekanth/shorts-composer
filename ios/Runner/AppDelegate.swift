import UIKit
import Flutter
import GoogleSignIn

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configure Google Sign-In
    let signInConfig = GIDConfiguration(clientID: "18038789658-mifrqrpenap8vred4cfulc1pmgkco5e8.apps.googleusercontent.com")
    GIDSignIn.sharedInstance.configuration = signInConfig
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @available(iOS 9.0, *)
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return GIDSignIn.sharedInstance.handle(url)
  }
}
