import SwiftUI

@main
struct XiaoYuanReaderPlusApp: App {
    @State private var store = ReaderAppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.bootstrap()
                }
        }
    }
}
