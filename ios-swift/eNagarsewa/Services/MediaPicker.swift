import UIKit
import UniformTypeIdentifiers

/// A file chosen by the user (`XFile` / `PlatformFile` equivalent).
struct PickedFile {
    let data: Data
    let filename: String
    var image: UIImage? { UIImage(data: data) }
    var sizeInBytes: Int { data.count }
    var fileExtension: String { (filename as NSString).pathExtension.lowercased() }

    var upload: UploadFile { UploadFile(data: data, filename: filename) }
}

/// Camera / photo library (`image_picker`) and document (`file_picker`) selection.
@MainActor
final class MediaPicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate,
                         UIDocumentPickerDelegate {

    enum Source { case camera, gallery }

    private static var active: MediaPicker?
    private var continuation: CheckedContinuation<PickedFile?, Never>?
    private var jpegQuality: CGFloat = 0.8

    /// `pickImage(source:, imageQuality:)` — returns a JPEG.
    static func pickImage(from vc: UIViewController, source: Source, quality: Int = 80) async -> PickedFile? {
        let sourceType: UIImagePickerController.SourceType = source == .camera ? .camera : .photoLibrary
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            vc.snack(source == .camera ? "Camera is not available on this device." : "Photo library is not available.", .error)
            return nil
        }
        let picker = MediaPicker()
        picker.jpegQuality = CGFloat(quality) / 100
        active = picker
        defer { active = nil }
        return await withCheckedContinuation { c in
            picker.continuation = c
            let controller = UIImagePickerController()
            controller.sourceType = sourceType
            controller.delegate = picker
            vc.topPresented.present(controller, animated: true)
        }
    }

    /// `FilePicker.pickFiles(type: custom, allowedExtensions:)`.
    static func pickDocument(from vc: UIViewController, extensions: [String]) async -> PickedFile? {
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        let picker = MediaPicker()
        active = picker
        defer { active = nil }
        return await withCheckedContinuation { c in
            picker.continuation = c
            let controller = UIDocumentPickerViewController(forOpeningContentTypes: types.isEmpty ? [.item] : types,
                                                            asCopy: true)
            controller.delegate = picker
            controller.allowsMultipleSelection = false
            vc.topPresented.present(controller, animated: true)
        }
    }

    private func finish(_ file: PickedFile?) {
        continuation?.resume(returning: file)
        continuation = nil
    }

    // MARK: UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [self] in
            guard let image, let data = image.normalizedOrientation().jpegData(compressionQuality: jpegQuality) else {
                finish(nil)
                return
            }
            finish(PickedFile(data: data, filename: "IMG_\(Int(Date().timeIntervalSince1970 * 1000)).jpg"))
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [self] in finish(nil) }
    }

    // MARK: UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { finish(nil); return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { finish(nil); return }
        finish(PickedFile(data: data, filename: url.lastPathComponent))
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(nil)
    }
}

extension UIImage {
    /// Bakes the EXIF orientation into the pixels so uploads aren't rotated server-side.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(at: .zero) }
    }
}

/// "Select Image Source" sheet with Camera / Gallery options (used by several screens).
final class ImageSourceSheet: BottomSheetController {
    private let onPick: (MediaPicker.Source) -> Void
    private let titleText: String

    init(title: String = "Select Image Source", onPick: @escaping (MediaPicker.Source) -> Void) {
        self.onPick = onPick
        self.titleText = title
        super.init()
        showsHandle = false
        cornerRadius = 20
        contentInsets = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func buildContent() {
        contentStack.alignment = .center
        contentStack.add(UILabel(titleText, font: .poppins(18, .bold), color: .black87))
        contentStack.addSpacer(20)
        let camera = option("camera.fill", "Camera") { [weak self] in self?.choose(.camera) }
        let gallery = option("photo.on.rectangle", "Gallery") { [weak self] in self?.choose(.gallery) }
        let row = UIStackView.h(0, alignment: .top, [camera, gallery])
        row.distribution = .fillEqually
        contentStack.add(row)
        row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        contentStack.addSpacer(20)
    }

    private func option(_ icon: String, _ label: String, action: @escaping () -> Void) -> UIView {
        let v = UIStackView.v(8, alignment: .center, [
            iconTile(icon, background: UIColor(argb: 0xFFFFF3E8), size: 62, iconSize: 28, radius: 31),
            UILabel(label, font: .poppins(14, .medium), color: .black87),
        ])
        v.onTap(action)
        return v
    }

    private func choose(_ source: MediaPicker.Source) {
        close { [onPick] in onPick(source) }
    }
}
