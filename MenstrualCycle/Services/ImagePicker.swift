//
//  ImagePicker.swift
//  MenstrualCycle
//
//  UIViewControllerRepresentable bọc PHPickerViewController
//  để chọn ảnh từ thư viện. Tương thích iOS 15+.
//

import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

// MARK: - Avatar Image Helpers

struct AvatarHelper {
    /// Lưu ảnh đại diện vào Documents folder
    static func saveAvatar(_ image: UIImage, userId: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }

        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let fileName = "avatar_\(userId).jpg"
        let fileURL = documentsDir.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("❌ [Avatar] Không thể lưu ảnh: \(error)")
            return nil
        }
    }

    /// Load ảnh đại diện từ Documents folder
    static func loadAvatar(fileName: String) -> UIImage? {
        guard !fileName.isEmpty else { return nil }

        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let fileURL = documentsDir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        return UIImage(contentsOfFile: fileURL.path)
    }
}
