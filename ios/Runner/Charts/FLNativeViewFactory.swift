//
//  FLNativeViewFactory.swift
//  Runner
//
//  Created by Sharath Chenna on 3/21/25.
//

import Flutter
import UIKit
import SwiftUI

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    private weak var parentViewController: FlutterViewController?
    
    init(messenger: FlutterBinaryMessenger, parentViewController: FlutterViewController) {
        print("[FLNativeViewFactory] Initializing factory")
        self.messenger = messenger
        self.parentViewController = parentViewController
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        print("[FLNativeViewFactory] Creating view with id: \(viewId)")
        print("[FLNativeViewFactory] Arguments: \(String(describing: args))")
        
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger,
            parentViewController: parentViewController
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var containerView: UIView
    private weak var parentViewController: FlutterViewController?
    private var statsTabBarController: StatsTabBarController?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        parentViewController: FlutterViewController?
    ) {
        self.containerView = UIView(frame: frame)
        self.parentViewController = parentViewController
        super.init()
        createNativeView(arguments: args)
    }
    
    func view() -> UIView {
        return containerView
    }
    
    private func createNativeView(arguments args: Any?) {
        let statsVC = StatsTabBarController()
        self.statsTabBarController = statsVC
        
        if let args = args as? [String: Any],
           let initialSection = args["initialSection"] as? String {
            statsVC.navigateToSection(initialSection)
        }
        
        guard let parentVC = parentViewController else { return }
        
        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        
        DispatchQueue.main.async {
            parentVC.present(navController, animated: true)
        }
    }
}

