import SwiftUI
import SwiftData
import PhotosUI

private enum AppTab: Hashable {
    case home, groceries, dining, scan
}

/// Drives the Review sheet — either a freshly scanned/uploaded image, or a
/// blank manual-entry form when there's no image involved.
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

    // Drives the system photo library picker. The picker itself needs no
    // permission prompt — it runs out-of-process and only hands back the
    // photo the user actually picks.
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

    // App-wide appearance preference: "system", "light", or "dark". Shared
    // (same key) with the picker in HomeView's settings menu.
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil   // follow the system setting
        }
    }

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
        .preferredColorScheme(preferredColorScheme)
        .onChange(of: selectedTab) { previousTab, newTab in
            if newTab == .scan {
                selectedTab = previousTab
                showAddOptions = true
            }
        }
        // Lets the user pick how they want to add a receipt.
        .confirmationDialog("Add Receipt", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Scan Receipt") { showScanner = true }
            Button("Choose from Library") { showPhotoPicker = true }
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
        // System photo library picker. No UIViewControllerRepresentable
        // wrapper needed — PhotosUI gives us a SwiftUI-native modifier.
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // Same draft case the scanner uses — ReviewView and
                    // ReceiptParser don't need to know the image's source.
                    draft = .scanned(image)
                }
                // Reset so picking the same photo again still triggers onChange.
                photoPickerItem = nil
            }
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
