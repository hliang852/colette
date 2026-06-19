import SwiftUI
import VisionKit

/// Wraps Apple's built-in document scanner. It auto-detects the receipt's edges,
/// deskews it, and hands back a clean image — which makes OCR far more reliable
/// than scanning a plain camera photo.
struct DocumentScanner: UIViewControllerRepresentable {
    var onComplete: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(_ parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            // A receipt is a single page; grab the first scanned page.
            if scan.pageCount > 0 {
                parent.onComplete(scan.imageOfPage(at: 0))
            } else {
                parent.onCancel()
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
