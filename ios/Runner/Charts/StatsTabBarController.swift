import UIKit

class StatsTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupAppearance()
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .plain,
            target: self,
            action: #selector(dismissController)
        )
    }
    
    private func setupViewControllers() {
        let weightVC = WeightViewController()
        weightVC.tabBarItem = UITabBarItem(
            title: "Weight",
            image: UIImage(systemName: "scalemass"),
            selectedImage: UIImage(systemName: "scalemass.fill")
        )
        
        let caloriesVC = CaloriesViewController()
        caloriesVC.tabBarItem = UITabBarItem(
            title: "Calories",
            image: UIImage(systemName: "flame"),
            selectedImage: UIImage(systemName: "flame.fill")
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
        
        viewControllers = [
            UINavigationController(rootViewController: weightVC),
            UINavigationController(rootViewController: caloriesVC),
            UINavigationController(rootViewController: stepsVC),
            UINavigationController(rootViewController: macrosVC)
        ]
    }
    
    private func setupAppearance() {
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = .systemBackground
        tabBar.isTranslucent = true
    }
    
    func navigateToSection(_ section: String) {
        switch section {
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
    
    @objc private func dismissController() {
        dismiss(animated: true)
    }
}