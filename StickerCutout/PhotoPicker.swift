import SwiftUI
import PhotosUI

/// アルバムから複数枚の写真を選ぶ PHPicker ラッパー。
struct PhotoPicker: UIViewControllerRepresentable {
    var onPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 0          // 0 = 無制限
        config.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPicked: onPicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: ([UIImage]) -> Void
        init(onPicked: @escaping ([UIImage]) -> Void) { self.onPicked = onPicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            // 選択順を保ったまま UIImage をロード。
            let group = DispatchGroup()
            var images = [UIImage?](repeating: nil, count: results.count)
            for (i, result) in results.enumerated() {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    images[i] = obj as? UIImage
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                self.onPicked(images.compactMap { $0 })
            }
        }
    }
}
