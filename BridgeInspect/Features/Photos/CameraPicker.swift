import SwiftUI
import UIKit

/// Live camera capture for photo or video, wrapping UIImagePickerController.
///
/// UIImagePickerController rather than PhotosPicker because this is live
/// capture, not library selection, and it is the smallest thing that shoots
/// both stills and video with no third-party dependency.
struct CameraPicker: UIViewControllerRepresentable {
    let kind: MediaKind
    /// Called with the saved filename once the capture is written to disk.
    let onCapture: (String, MediaKind) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera
            : .photoLibrary
        switch kind {
        case .photo:
            picker.mediaTypes = ["public.image"]
        case .video:
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
        }
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(kind: kind, onCapture: onCapture) { dismiss() }
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let kind: MediaKind
        private let onCapture: (String, MediaKind) -> Void
        private let finish: () -> Void

        init(kind: MediaKind,
             onCapture: @escaping (String, MediaKind) -> Void,
             finish: @escaping () -> Void) {
            self.kind = kind
            self.onCapture = onCapture
            self.finish = finish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer { finish() }

            switch kind {
            case .photo:
                guard let image = info[.originalImage] as? UIImage,
                      let filename = try? MediaStore.saveImage(image) else { return }
                onCapture(filename, .photo)

            case .video:
                guard let url = info[.mediaURL] as? URL,
                      let filename = try? MediaStore.saveVideo(from: url) else { return }
                onCapture(filename, .video)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish()
        }
    }
}
