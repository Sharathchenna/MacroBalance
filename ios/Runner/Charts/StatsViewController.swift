import UIKit

class StatsViewController: UITabBarController {
    private let methodHandler: StatsMethodHandler
    
    init(messenger: FlutterBinaryMessenger) {
        self.methodHandler = StatsMethodHandler(messenger: messenger)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }
    
    private func setupTabs() {
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
        
        let caloriesVC = CaloriesViewController()
        caloriesVC.tabBarItem = UITabBarItem(
            title: "Calories",
            image: UIImage(systemName: "flame"),
            selectedImage: UIImage(systemName: "flame.fill")
        )
        
        let macrosVC = MacrosViewController()
        macrosVC.tabBarItem = UITabBarItem(
            title: "Macros",
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
        )
        
        viewControllers = [
            UINavigationController(rootViewController: weightVC),
            UINavigationController(rootViewController: stepsVC),
            UINavigationController(rootViewController: caloriesVC),
            UINavigationController(rootViewController: macrosVC)
        ]
    }
    
    private func setupAppearance() {
        // Setup tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Apply blur effect
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        
        // Configure colors
        appearance.backgroundColor = .clear
        
        // Configure item appearances
        let itemAppearance = UITabBarItemAppearance()
        
        // Normal state
        itemAppearance.normal.iconColor = .secondaryLabel
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        // Selected state
        itemAppearance.selected.iconColor = .systemBlue
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        
        // Setup navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        navBarAppearance.backgroundColor = .clear
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
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