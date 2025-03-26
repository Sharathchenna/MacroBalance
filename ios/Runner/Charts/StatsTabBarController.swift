import UIKit

class StatsTabBarController: UITabBarController {
    // Callback that gets called when controller is dismissed
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupAppearance()
        setupNavigation()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Makes sure the tab bar is visible when returning from child views
        tabBar.isHidden = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Call the dismissal callback when the controller is actually dismissed
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            onDismiss?()
        }
    }
    
    private func setupNavigation() {
        // Add a close button that properly dismisses the controller
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(closeScreen)
        )
        
        // Make the navigation title match the selected tab
        navigationItem.title = tabBar.selectedItem?.title ?? "Stats"
    }
    
    @objc private func closeScreen() {
        // Call dismiss on self or the navigation controller if present
        if let navController = navigationController {
            navController.dismiss(animated: true) { [weak self] in
                self?.onDismiss?()
            }
        } else {
            dismiss(animated: true) { [weak self] in
                self?.onDismiss?()
            }
        }
    }
    
    private func setupViewControllers() {
        let weightVC = WeightViewController()
        weightVC.tabBarItem = UITabBarItem(
            title: "Weight",
            image: UIImage(systemName: "scalemass"),
            selectedImage: UIImage(systemName: "scalemass.fill")
        )
        
        let stepsVC = StepsViewController()
        stepsVC.tabBarItem = UITabBarItem(
            title: "Steps",
            image: UIImage(systemName: "figure.walk"),
            selectedImage: UIImage(systemName: "figure.walk.circle.fill")
        )
        
        let macrosVC = MacrosViewController()
        macrosVC.tabBarItem = UITabBarItem(
            title: "Macros",
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
        )
        
        // Wrap each view controller in a navigation controller to allow for proper nav bar setup
        viewControllers = [
            UINavigationController(rootViewController: weightVC),
            UINavigationController(rootViewController: stepsVC),
            UINavigationController(rootViewController: macrosVC)
        ]
        
        // Add tab bar delegate to update navigation title
        delegate = self
    }
    
    private func setupAppearance() {
        // Modern appearance for iOS 15+
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = tabBar.standardAppearance
            
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithDefaultBackground()
            navigationController?.navigationBar.standardAppearance = navAppearance
            navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        }
        
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = .systemBackground
    }
    
    func navigateToSection(_ section: String) {
        switch section.lowercased() {
        case "weight":
            selectedIndex = 0
        case "steps":
            selectedIndex = 1
        case "macros":
            selectedIndex = 2
        default:
            selectedIndex = 0
        }
        
        // Update navigation title to match selected tab
        if let title = tabBar.selectedItem?.title {
            navigationItem.title = title
        }
    }
}

// MARK: - UITabBarControllerDelegate
extension StatsTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // Update navigation title when tab changes
        if let title = tabBarController.tabBar.selectedItem?.title {
            navigationItem.title = title
        }
    }
}