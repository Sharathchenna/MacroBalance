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
    private weak var parentViewController: UIViewController?
    
    init(messenger: FlutterBinaryMessenger, parentViewController: UIViewController?) {
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
            messenger: messenger,
            parentViewController: parentViewController
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private let frame: CGRect
    private let viewId: Int64
    private var goalsViewController: GoalsViewController?
    private weak var parentViewController: UIViewController?
    private var containerView: UIView

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger, parentViewController: UIViewController?) {
        self.frame = frame
        self.viewId = viewId
        self.parentViewController = parentViewController
        self.containerView = UIView(frame: frame)
        
        super.init()
        
        createNativeView(arguments: args)
    }

    func view() -> UIView {
        return containerView
    }

    private func createNativeView(arguments args: Any?) {
        // Set up container view
        containerView.backgroundColor = .clear
        
        // Create GoalsViewController
        let goalsVC = GoalsViewController()
        self.goalsViewController = goalsVC
        
        // Set initial section if provided in arguments
        if let args = args as? [String: Any],
           let initialSection = args["initialSection"] as? String {
            goalsVC.initialSection = initialSection
        }

        // Add GoalsViewController as child of parent
        if let parentVC = parentViewController {
            parentVC.addChild(goalsVC)
            containerView.addSubview(goalsVC.view)
            goalsVC.view.frame = containerView.bounds
            goalsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            goalsVC.didMove(toParent: parentVC)
        }
    }
}

