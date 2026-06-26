import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` so we can present iOS's native share
/// sheet from SwiftUI and find out whether the share actually completed
/// (vs. the user cancelling) — that's what gates the "Backup saved" message.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
