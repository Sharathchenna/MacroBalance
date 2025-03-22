import Flutter
import UIKit

class FlutterStatsViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FlutterStatsView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }
}

class FlutterStatsView: NSObject, FlutterPlatformView {
    private var statsController: StatsTabBarController
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        statsController = StatsTabBarController()
        super.init()
        
        // Handle initial section if provided
        if let args = args as? [String: Any],
           let section = args["section"] as? String {
            statsController.navigateToSection(section)
        }
    }
    
    func view() -> UIView {
        return statsController.view
    }
}