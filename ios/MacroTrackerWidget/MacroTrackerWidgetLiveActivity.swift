//
//  MacroTrackerWidgetLiveActivity.swift
//  MacroTrackerWidget
//
//  Created by Sharath Chenna on 3/14/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MacroTrackerWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

@available(iOS 16.1, *)
struct MacroTrackerWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MacroTrackerWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)
            
        } dynamicIsland: { context in
            // For iOS 16.1+, we need a simple implementation of dynamic island
            DynamicIsland {
                // Expanded UI goes here - simplified for iOS 16.1 compatibility
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("Min")
            }
        }
    }
}

extension MacroTrackerWidgetAttributes {
    fileprivate static var preview: MacroTrackerWidgetAttributes {
        MacroTrackerWidgetAttributes(name: "World")
    }
}

extension MacroTrackerWidgetAttributes.ContentState {
    fileprivate static var smiley: MacroTrackerWidgetAttributes.ContentState {
        MacroTrackerWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MacroTrackerWidgetAttributes.ContentState {
         MacroTrackerWidgetAttributes.ContentState(emoji: "🤩")
     }
}

// Commented out the Preview that uses iOS 18 features
// #Preview("Notification", as: .content, using: MacroTrackerWidgetAttributes.preview) {
//    MacroTrackerWidgetLiveActivity()
// } contentStates: {
//    MacroTrackerWidgetAttributes.ContentState.smiley
//    MacroTrackerWidgetAttributes.ContentState.starEyes
// }
