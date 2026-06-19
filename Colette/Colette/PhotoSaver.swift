import Photos
import UIKit

enum PhotoSaver {
    /// Saves an image to the iPhone's Photos library using add-only access.
    /// Requires the "Privacy - Photo Library Additions Usage Description"
    /// (NSPhotoLibraryAddUsageDescription) key in the target's Info settings.
    static func saveToPhotoAlbum(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }
    }
}
