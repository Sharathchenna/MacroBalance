import UIKit

class StatsTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewControllers()
        setupTabBarAppearance()
        
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
    
    private func setupTabBarAppearance() {
        // Modern tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // Customize colors
        appearance.backgroundColor = .systemBackground
        
        // Selected item appearance
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        appearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        
        // Normal item appearance
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.gray
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }
    
    @objc private func dismissController() {
        dismiss(animated: true)
    }
}