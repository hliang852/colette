import SwiftUI
import SwiftData
import PhotosUI

private enum AppTab: Hashable {
    case home, groceries, dining, scan
}

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

    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?

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
        .confirmationDialog("Add Receipt", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Scan Receipt") { showScanner = true }
            Button("Choose from Library") { showPhotoPicker = true }
            Button("Enter Manually") { draft = .manual }
            Button("Cancel", role: .cancel) {}
        }
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
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    draft = .scanned(image)
                }
                photoPickerItem = nil
            }
        }
        .sheet(item: $draft) { draft in
            switch draft {
            case .scanned(let image):
                ReviewView(image: image)
            case .manual:
                ReviewView(image: nil)
            }
        }
        .onAppear {
            if !didAutoLaunch {
                didAutoLaunch = true
                showAddOptions = true
            }
        }
    }
}
