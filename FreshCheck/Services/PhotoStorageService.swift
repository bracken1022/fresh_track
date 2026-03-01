// FreshCheck/Services/PhotoStorageService.swift
import UIKit

final class PhotoStorageService {

    private static var storageDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("food-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func save(image: UIImage) throws -> String {
        let filename = UUID().uuidString + ".jpg"
        let fileURL = storageDirectory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw PhotoError.encodingFailed
        }
        try data.write(to: fileURL)
        return fileURL.path
    }

    static func load(from path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    static func delete(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try FileManager.default.removeItem(atPath: path)
    }

    enum PhotoError: Error {
        case encodingFailed
    }
}
