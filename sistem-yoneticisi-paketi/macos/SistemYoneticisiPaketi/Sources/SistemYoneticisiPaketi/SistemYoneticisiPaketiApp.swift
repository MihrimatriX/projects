import SwiftUI
// Görünümler ve MetricsViewModel ayrı kütüphane hedefinde (testler için); burada public olarak içe alınır.
import SistemYoneticisiPaketiLib

@main
struct SistemYoneticisiPaketiApp: App {
    @StateObject private var metrics = MetricsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metrics)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
