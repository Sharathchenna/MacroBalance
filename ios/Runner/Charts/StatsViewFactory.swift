@_exported import Flutter
import Foundation
import UIKit

class StatsViewWrapper: NSObject, FlutterPlatformView {
    private let statsViewController: StatsViewController
    
    init(statsViewController: StatsViewController) {
        self.statsViewController = statsViewController
        super.init()
    }
    
    func view() -> UIView {
        return statsViewController.view
    }
}

class StatsViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var flutterViewController: FlutterViewController?
    
    init(messenger: FlutterBinaryMessenger, flutterViewController: FlutterViewController) {
        self.messenger = messenger
        self.flutterViewController = flutterViewController
        super.init()
    }
    
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        let initialSection = (args as? [String: Any])?["initialSection"] as? String ?? "weight"
        guard let parentVC = flutterViewController else {
            fatalError("FlutterViewController is required for StatsViewController")
        }
        let statsViewController = StatsViewController(messenger: messenger, parentViewController: parentVC)
        statsViewController.navigateToSection(initialSection)
        return StatsViewWrapper(statsViewController: statsViewController)
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}