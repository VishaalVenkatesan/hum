import SwiftUI

@main
struct HumApp: App {
    @State private var app = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(app)
                .environment(app.store)
                .environment(app.artwork)
                .environment(app.sleepTimer)
                .environment(app.lyrics)
        } label: {
            MenuBarLabel()
                .environment(app)
                .environment(app.store)
        }
        .menuBarExtraStyle(.window)
    }
}
