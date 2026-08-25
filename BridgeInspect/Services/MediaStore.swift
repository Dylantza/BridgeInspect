import Foundation
import UIKit

/// Writes iPhone-captured photos and videos to disk and reads them back.
///
/// Files live in Application Support, not Caches: field media that iOS purges
/// under storage pressure before it has been uploaded is unrecoverable.
/// Only the filename is stored in the database — the directory is resolved
/// here at runtime, because iOS relocates the app container on reinstall.
enum MediaStore {

    enum StoreError: Error {
        case couldNotEncodeImage
        case directoryUnavailable
    }

    static var directory: URL {
        get throws {
            let base = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let media = base.appendingPathComponent("Media", isDirectory: true)
            if !FileManager.default.fileExists(atPath: media.path) {
                try FileManager.default.createDirectory(
                    at: media, withIntermediateDirectories: true
                )
                // Media is re-uploadable to Supabase; keep it out of iCloud backup.
                var mutable = media
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? mutable.setResourceValues(values)
            }
            return media
        }
    }

    static func url(for filename: String) throws -> URL {
        try directory.appendingPathComponent(filename)
    }

    /// Downscales and writes a captured image. Documentation shots do not need
    /// full sensor resolution, and full-size frames make sync unusable over a
    /// field hotspot.
    @discardableResult
    static func saveImage(_ image: UIImage, maxDimension: CGFloat = 2048) throws -> String {
        let scaled = downscale(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: 0.8) else {
            throw StoreError.couldNotEncodeImage
        }
        let filename = "\(UUID().uuidString).jpg"
        try data.write(to: try url(for: filename), options: .atomic)
        return filename
    }

    /// Moves a recorded video out of its temporary location into our directory.
    @discardableResult
    static func saveVideo(from temporaryURL: URL) throws -> String {
        let filename = "\(UUID().uuidString).mov"
        let destination = try url(for: filename)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return filename
    }

    static func loadImage(named filename: String) -> UIImage? {
        guard let fileURL = try? url(for: filename),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func delete(filename: String) {
        guard let fileURL = try? url(for: filename) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let target = CGSize(width: image.size.width * scale,
                            height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
