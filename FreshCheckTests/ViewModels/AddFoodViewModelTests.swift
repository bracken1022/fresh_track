// FreshCheckTests/ViewModels/AddFoodViewModelTests.swift
import XCTest
@testable import FreshCheck

final class AddFoodViewModelTests: XCTestCase {

    func test_isExpiredOnAdd_returnsTrue_whenExpiryDateInPast() {
        let vm = AddFoodViewModel()
        vm.expiryDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(vm.isExpiredOnAdd)
    }

    func test_isExpiredOnAdd_returnsFalse_whenExpiryDateInFuture() {
        let vm = AddFoodViewModel()
        vm.expiryDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertFalse(vm.isExpiredOnAdd)
    }

    func test_populate_setsFieldsFromAnalysis() {
        let vm = AddFoodViewModel()
        let analysis = FoodAnalysis(
            name: "Chicken Breast",
            category: .meat,
            expiryDate: "2026-03-01",
            confidenceSource: .shelfLife,
            shelfLifeDays: 3
        )
        vm.populate(from: analysis)
        XCTAssertEqual(vm.name, "Chicken Breast")
        XCTAssertEqual(vm.category, .meat)
        XCTAssertEqual(vm.confidenceSource, .shelfLife)
    }
}
