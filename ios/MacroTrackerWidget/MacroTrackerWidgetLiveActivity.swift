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
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
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

#Preview("Notification", as: .content, using: MacroTrackerWidgetAttributes.preview) {
   MacroTrackerWidgetLiveActivity()
} contentStates: {
    MacroTrackerWidgetAttributes.ContentState.smiley
    MacroTrackerWidgetAttributes.ContentState.starEyes
}
