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
    private var hostingControllers: [Int64: UIHostingController<AnyView>] = [:]
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
            factory: self,
            parentViewController: parentViewController
        )
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
    
    func storeHostingController(_ controller: UIHostingController<AnyView>, for viewId: Int64) {
        print("[FLNativeViewFactory] Storing hosting controller for view id: \(viewId)")
        hostingControllers[viewId] = controller
    }
    
    func removeHostingController(for viewId: Int64) {
        print("[FLNativeViewFactory] Removing hosting controller for view id: \(viewId)")
        if let controller = hostingControllers[viewId] {
            controller.removeFromParent()
            controller.view.removeFromSuperview()
        }
        hostingControllers.removeValue(forKey: viewId)
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var viewId: Int64
    private weak var factory: FLNativeViewFactory?
    private weak var parentViewController: UIViewController?
    private var hostingController: UIHostingController<AnyView>?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger,
        factory: FLNativeViewFactory,
        parentViewController: UIViewController?
    ) {
        print("[FLNativeView] Initializing view with id: \(viewId)")
        print("[FLNativeView] Frame: \(frame)")
        
        self.viewId = viewId
        self.factory = factory
        self.parentViewController = parentViewController
        
        let chartFactory = ChartFactory()
        
        // Create a container with a proper initial frame
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300))
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        
        if let args = args as? [String: Any],
           let chartType = args["chartType"] as? String,
           let data = args["data"] as? [[String: Any]] {
            
            print("[FLNativeView] Creating chart of type: \(chartType)")
            print("[FLNativeView] Data: \(data.count) entries")
            
            var chartView: UIView
            
            switch chartType {
            case "weight":
                chartView = chartFactory.createWeightChart(data: data, parent: parentViewController)
                print("[FLNativeView] Created weight chart view")
            case "steps":
                chartView = chartFactory.createStepsChart(data: data, parent: parentViewController)
                print("[FLNativeView] Created steps chart view")
            case "calories":
                chartView = chartFactory.createCaloriesChart(data: data, parent: parentViewController)
                print("[FLNativeView] Created calories chart view")
            case "macros":
                chartView = chartFactory.createMacrosChart(data: data, parent: parentViewController)
                print("[FLNativeView] Created macros chart view")
            default:
                print("[FLNativeView] Unknown chart type: \(chartType)")
                chartView = UIView()
                chartView.backgroundColor = .systemRed // Debug color for unknown chart type
            }
            
            // Add visible styling for debugging
            chartView.backgroundColor = .systemBackground
            chartView.layer.cornerRadius = 12
            chartView.clipsToBounds = true
            
            // Ensure the chart view has the correct frame
            chartView.frame = containerView.bounds
            chartView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.addSubview(chartView)
            
            print("[FLNativeView] Added chart view to container")
            
            // Check and store the hosting controller if present
            if let hostController = chartView.next as? UIHostingController<AnyView> {
                print("[FLNativeView] Found hosting controller")
                self.hostingController = hostController
                factory.storeHostingController(hostController, for: viewId)
            } else {
                print("[FLNativeView] No hosting controller found for view. Using view directly.")
            }
            
        } else {
            print("[FLNativeView] Invalid or missing arguments")
            // Add visible placeholder for debugging
            let placeholderLabel = UILabel(frame: containerView.bounds)
            placeholderLabel.text = "Invalid chart arguments"
            placeholderLabel.textAlignment = .center
            placeholderLabel.textColor = .systemRed
            containerView.addSubview(placeholderLabel)
        }
        
        _view = containerView
        super.init()
    }
    
    func view() -> UIView {
        print("[FLNativeView] Returning view for id: \(viewId), frame: \(_view.frame)")
        return _view
    }
    
    deinit {
        print("[FLNativeView] Deinitializing view with id: \(viewId)")
        factory?.removeHostingController(for: viewId)
    }
}

