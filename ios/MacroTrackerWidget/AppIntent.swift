//
//  AppIntent.swift
//  MacroTrackerWidget
//
//  Created by Sharath Chenna on 3/14/25.
//

import WidgetKit
import AppIntents
import UIKit
import SwiftUI  // Added import

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// Define our own URL opening intent
struct OpenURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open URL"
    static var description = IntentDescription("Opens a URL")
    
    @Parameter(title: "URL")
    var url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    init() {
        self.url = URL(string: "nutrino:///dashboard")!
    }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
    
    // Removed duplicate computed property 'url'
}

// Now use our custom URL opening intent
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "Open MacroTracker"
    static var description = IntentDescription("Opens the MacroTracker app")
    
    @Parameter(title: "Route")
    var route: String?
    
    init(route: String? = nil) {
        self.route = route
    }
    
    init() {
        self.route = nil
    }
    
    func perform() async throws -> some IntentResult {
        let urlString: String
        if let route = route, !route.isEmpty {
            urlString = "nutrino://\(route)"
        } else {
            urlString = "nutrino:///dashboard" // Default route
        }
        
        // Ensure the URL is valid; if not, throw an error.
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        return .result(value: url)
    }
}

struct GoToDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Dashboard"
    static var description = IntentDescription("Opens the dashboard in MacroTracker")
    
    func perform() async throws -> some IntentResult {
        return try await OpenAppIntent(route: "/dashboard").perform()
    }
}
