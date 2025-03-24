import UIKit
import SwiftUI

class MacrosPageViewController: UIViewController {
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSwiftUIView()
        title = "Macros"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = UIColor(Color(red: 0.0, green: 0.6, blue: 1.0))
    }
    
    // MARK: - UI Setup
    private func setupSwiftUIView() {
        // Create and configure SwiftUI view
        let macrosView = MacrosView()
        
        // Create a hosting controller for the SwiftUI view
        let hostingController = UIHostingController(rootView: macrosView)
        
        // Add the hosting controller as a child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        // Configure the hosting controller's view
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Complete the addition of the child view controller
        hostingController.didMove(toParent: self)
    }
}