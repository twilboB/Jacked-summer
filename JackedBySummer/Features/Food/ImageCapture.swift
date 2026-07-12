import SwiftUI
import UIKit

// Reusable camera capture. Photo-library selection is done with SwiftUI's
// PhotosPicker directly in FoodView, so this file only needs the camera path.

/// Wraps `UIImagePickerController` in camera mode and hands back a `UIImage`.
/// Present it in a `.sheet`; it dismisses itself on capture or cancel.
struct CameraPicker: UIViewControllerRepresentable {
    /// Called with the captured image, or `nil` if the user cancelled.
    var onImage: (UIImage?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: { dismiss() })
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        // VERIFY camera availability at runtime — the simulator has no camera,
        // and privacy/hardware state can make `.camera` unavailable.
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            controller.sourceType = .camera
        } else {
            controller.sourceType = .photoLibrary
        }
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        let dismiss: () -> Void

        init(onImage: @escaping (UIImage?) -> Void, dismiss: @escaping () -> Void) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            onImage(image)
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
            dismiss()
        }
    }
}

extension UIImagePickerController {
    /// Convenience runtime check the UI can use to hide camera-only controls.
    static var cameraIsAvailable: Bool {
        isSourceTypeAvailable(.camera)
    }
}
