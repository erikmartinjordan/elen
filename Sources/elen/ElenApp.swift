import SwiftUI

@main
struct ElenApp: App {
    var body: some Scene {
        WindowGroup("elen") {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
