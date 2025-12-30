import UIKit
import Flutter
import GoogleMaps // 1. Importáld be

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. Itt állítsd be a kulcsot a Secrets fájlból
    GMSServices.provideAPIKey(Secrets.googleMapsKey)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}