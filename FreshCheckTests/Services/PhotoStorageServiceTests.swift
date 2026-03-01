// FreshCheckTests/Services/PhotoStorageServiceTests.swift
import XCTest
import UIKit
@testable import FreshCheck

final class PhotoStorageServiceTests: XCTestCase {

    func test_saveAndLoad_roundTripsImage() throws {
        let image = UIImage(systemName: "star")!
        let url = try PhotoStorageService.save(image: image)
        let loaded = PhotoStorageService.load(from: url)
        XCTAssertNotNil(loaded)
        try PhotoStorageService.delete(at: url)  // cleanup
    }

    func test_delete_removesFile() throws {
        let image = UIImage(systemName: "star")!
        let url = try PhotoStorageService.save(image: image)
        try PhotoStorageService.delete(at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url))
    }
}
