import SwiftUI
import SwiftData

private enum AppTab: Hashable {
    case home, groceries, dining, scan
}

/// Drives the Review sheet — either a freshly scanned image, or a blank
/// manual-entry form when there's no image involved.
private enum ReceiptDraft: Identifiable {
    case scanned(UIImage)
    case manual

    var id: String {
        switch self {
        case .scanned: return "scanned"
        case .manual: return "manual"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    @State private var showScanner = false
    @State private var showAddOptions = false
    @State private var draft: ReceiptDraft?
    @State private var didAutoLaunch = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)

            ReceiptListView(category: .grocery)
                .tabItem { Label("Groceries", systemImage: "cart") }
                .tag(AppTab.groceries)

            ReceiptListView(category: .diningOut)
                .tabItem { Label("Dining Out", systemImage: "fork.knife") }
                .tag(AppTab.dining)

            // Placeholder — selecting this tab never actually shows it. The
            // onChange below immediately bounces back to whichever tab was
            // active before, and opens the add-receipt options instead.
            Color.clear
                .tabItem { Label("Scan", systemImage: "camera") }
                .tag(AppTab.scan)
        }
        .onChange(of: selectedTab) { previousTab, newTab in
            if newTab == .scan {
                selectedTab = previousTab
                showAddOptions = true
            }
        }
        // Lets the user pick how they want to add a receipt.
        .confirmationDialog("Add Receipt", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Scan Receipt") { showScanner = true }
            Button("Enter Manually") { draft = .manual }
            Button("Cancel", role: .cancel) {}
        }
        // Document scanner: auto-detects the receipt's edges, straightens, and
        // crops it for clean OCR. Its Cancel button returns to whichever tab
        // was active before Scan was tapped.
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner(
                onComplete: { image in
                    showScanner = false
                    draft = .scanned(image)
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
        // The review/manual-entry screen. This is where the receipt gets
        // tagged Groceries or Dining Out.
        .sheet(item: $draft) { draft in
            switch draft {
            case .scanned(let image):
                ReviewView(image: image)
            case .manual:
                ReviewView(image: nil)
            }
        }
        // Open the add-receipt options on launch. Remove this block to land
        // on Home first.
        .onAppear {
            if !didAutoLaunch {
                didAutoLaunch = true
                showAddOptions = true
            }
        }
    }
}
