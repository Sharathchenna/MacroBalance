import UIKit

class StatsViewController: UITabBarController {
    private let methodHandler: StatsMethodHandler
    
    init(messenger: FlutterBinaryMessenger, parentViewController: FlutterViewController) {
        self.methodHandler = StatsMethodHandler(messenger: messenger, parentViewController: parentViewController)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
        setupNavigationBar()
    }
    
    private func setupTabs() {
        // Create view controllers lazily to improve initial load time
        let viewControllers = [
            lazyNavigationController(for: WeightViewController.self, title: "Weight", 
                                   image: "scalemass", selectedImage: "scalemass.fill"),
            lazyNavigationController(for: StepsViewController.self, title: "Steps", 
                                   image: "figure.walk", selectedImage: "figure.walk.circle.fill"),
            lazyNavigationController(for: CaloriesViewController.self, title: "Calories", 
                                   image: "flame", selectedImage: "flame.fill"),
            lazyNavigationController(for: MacrosViewController.self, title: "Macros", 
                                   image: "chart.pie", selectedImage: "chart.pie.fill")
        ]
        
        self.viewControllers = viewControllers
    }
    
    private func lazyNavigationController<T: UIViewController>(
        for viewControllerType: T.Type,
        title: String,
        image: String,
        selectedImage: String
    ) -> UINavigationController {
        // Create a placeholder view controller that will be replaced with the actual one when needed
        let placeholderVC = UIViewController()
        placeholderVC.title = title
        placeholderVC.tabBarItem = UITabBarItem(
            title: title,
            image: UIImage(systemName: image),
            selectedImage: UIImage(systemName: selectedImage)
        )
        
        let navController = UINavigationController(rootViewController: placeholderVC)
        
        // Replace placeholder with actual view controller when the tab is selected
        navController.viewControllers.first?.loadViewIfNeeded()
        navController.delegate = self
        
        return navController
    }
    
    private func setupAppearance() {
        // Apply appearance settings in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            appearance.backgroundColor = .clear
            
            let itemAppearance = UITabBarItemAppearance()
            itemAppearance.normal.iconColor = .secondaryLabel
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.secondaryLabel
            ]
            itemAppearance.selected.iconColor = .systemBlue
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.systemBlue
            ]
            
            appearance.stackedLayoutAppearance = itemAppearance
            appearance.inlineLayoutAppearance = itemAppearance
            appearance.compactInlineLayoutAppearance = itemAppearance
            
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithDefaultBackground()
            navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
            navBarAppearance.backgroundColor = .clear
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self?.tabBar.standardAppearance = appearance
                if #available(iOS 15.0, *) {
                    self?.tabBar.scrollEdgeAppearance = appearance
                }
                
                UINavigationBar.appearance().standardAppearance = navBarAppearance
                UINavigationBar.appearance().compactAppearance = navBarAppearance
                UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            }
        }
    }
    
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    func navigateToSection(_ section: String) {
        switch section.lowercased() {
        case "weight":
            selectedIndex = 0
        case "steps":
            selectedIndex = 1
        case "calories":
            selectedIndex = 2
        case "macros":
            selectedIndex = 3
        default:
            selectedIndex = 0
        }
    }
}

// MARK: - UINavigationControllerDelegate

extension StatsViewController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // Check if we need to replace the placeholder
        if viewController is UIViewController,
           !(viewController is WeightViewController),
           !(viewController is StepsViewController),
           !(viewController is CaloriesViewController),
           !(viewController is MacrosViewController) {
            
            // Create the actual view controller based on the navigation controller's index
            let index = viewControllers?.firstIndex(of: navigationController) ?? 0
            let actualVC: UIViewController
            
            switch index {
            case 0:
                actualVC = WeightViewController()
            case 1:
                actualVC = StepsViewController()
            case 2:
                actualVC = CaloriesViewController()
            case 3:
                actualVC = MacrosViewController()
            default:
                return
            }
            
            // Transfer the title and tab bar item
            actualVC.title = viewController.title
            actualVC.tabBarItem = viewController.tabBarItem
            
            // Replace the placeholder with the actual view controller
            navigationController.setViewControllers([actualVC], animated: false)
        }
    }
}