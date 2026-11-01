import UIKit
import SwiftUI
import Observation
import Photos

/// アートサインで撮った写真（本体は Application Support/Photos/ にJPEGで保存）
struct SignPhoto: Codable, Identifiable, Hashable {
    let id: UUID
    let signID: Int
    let date: Date

    var filename: String { "\(id.uuidString).jpg" }
    var sign: ArtSign? { ArtSign.all.first { $0.id == signID } }
}

/// 写真は端末内（このアプリの中）にだけ保存する。アプリを削除すると写真も消える。
@Observable
final class PhotoStore {
    private(set) var photos: [SignPhoto] = []

    @ObservationIgnored private let dir: URL
    @ObservationIgnored private let indexURL = FileStorage.url("photos.json")
    @ObservationIgnored private let thumbs = NSCache<NSString, UIImage>()

    init() {
        dir = FileStorage.url("Photos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        photos = FileStorage.load([SignPhoto].self, from: indexURL) ?? []
        // 本体のないデータは除く
        photos.removeAll { !FileManager.default.fileExists(atPath: fileURL($0).path) }
    }

    /// 新しい順
    var all: [SignPhoto] { photos.sorted { $0.date > $1.date } }

    func photos(for sign: ArtSign) -> [SignPhoto] {
        all.filter { $0.signID == sign.id }
    }

    @discardableResult
    func add(_ image: UIImage, for sign: ArtSign) -> SignPhoto? {
        let resized = image.resizedForStorage(maxDimension: 2400)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        let photo = SignPhoto(id: UUID(), signID: sign.id, date: Date())
        do {
            try data.write(to: fileURL(photo), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            return nil
        }
        photos.append(photo)
        saveIndex()
        return photo
    }

    /// 案内タブの「撮った写真を『写真』アプリにも保存」のオン／オフ（初期設定はオン）
    static let saveToLibraryKey = "photos.saveToLibrary.v1"

    static var saveToLibraryEnabled: Bool {
        UserDefaults.standard.object(forKey: saveToLibraryKey) as? Bool ?? true
    }

    /// 撮った写真を iPhone の「写真」アプリにも保存する（追加のみの許可。許可がなければ何もしない）
    static func saveToPhotoLibrary(_ image: UIImage) {
        guard saveToLibraryEnabled else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { _, _ in }
        }
    }

    func delete(_ photo: SignPhoto) {
        try? FileManager.default.removeItem(at: fileURL(photo))
        thumbs.removeObject(forKey: photo.id.uuidString as NSString)
        photos.removeAll { $0.id == photo.id }
        saveIndex()
    }

    func image(_ photo: SignPhoto) -> UIImage? {
        UIImage(contentsOfFile: fileURL(photo).path)
    }

    /// 一覧用の縮小画像（キャッシュあり）
    func thumbnail(_ photo: SignPhoto, maxSide: CGFloat = 360) -> UIImage? {
        let key = photo.id.uuidString as NSString
        if let cached = thumbs.object(forKey: key) { return cached }
        guard let full = image(photo) else { return nil }
        let scale = maxSide / max(full.size.width, full.size.height)
        let size = CGSize(width: full.size.width * scale, height: full.size.height * scale)
        let thumb = full.preparingThumbnail(of: size) ?? full
        thumbs.setObject(thumb, forKey: key)
        return thumb
    }

    private func fileURL(_ photo: SignPhoto) -> URL {
        dir.appendingPathComponent(photo.filename)
    }

    private func saveIndex() {
        FileStorage.save(photos, to: indexURL)
    }
}

extension UIImage {
    /// 長辺を maxDimension 以下に縮小し、向きも正しく揃える
    func resizedForStorage(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// カメラ撮影（UIImagePickerController）
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
