import SwiftUI

@main
struct ParkingGateProApp: App {
    @StateObject private var settings = AppSettings()

    // splash state
    @State private var showSplash = true

    init() {
        print("BundleID:", Bundle.main.bundleIdentifier ?? "nil")
        print("NSLocalNetworkUsageDescription:",
              Bundle.main.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription") as Any)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeDashboardView()
                    .environmentObject(settings)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .transaction { $0.animation = nil }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        Image("LaunchImage")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}
