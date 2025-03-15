//
//  AppIntent.swift
//  MacroTrackerWidget
//
//  Created by Sharath Chenna on 3/14/25.
//

import WidgetKit
import AppIntents

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is an example widget." }

    // An example configurable parameter.
    @Parameter(title: "Favorite Emoji", default: "😃")
    var favoriteEmoji: String

    // Add required perform() method for iOS 16.0 compatibility
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
