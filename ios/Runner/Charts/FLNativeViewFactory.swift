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
    private var _view: UIView
    private weak var parentViewController: FlutterViewController?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?,
        parentViewController: FlutterViewController?
    ) {
        _view = UIView(frame: frame)
        self.parentViewController = parentViewController
        super.init()
        createNativeView(arguments: args)
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func createNativeView(arguments args: Any?) {
        let statsVC = StatsTabBarController()
        
        if let args = args as? [String: Any],
           let initialSection = args["initialSection"] as? String {
            statsVC.navigateToSection(initialSection)
        }
        
        // Add close button to statsVC
        statsVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(dismissController)
        )
        
        let navController = UINavigationController(rootViewController: statsVC)
        navController.modalPresentationStyle = .fullScreen
        
        DispatchQueue.main.async { [weak self] in
            self?.parentViewController?.present(navController, animated: true)
        }
    }
    
    @objc private func dismissController() {
        parentViewController?.dismiss(animated: true)
    }
}

