# FreshCheck Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an iOS app where users photograph fridge food, Claude Vision identifies it and sets expiry dates, and a daily digest notification warns about items going bad.

**Architecture:** SwiftUI frontend with SwiftData local persistence. A `ClaudeVisionService` sends resized photos to the Claude API and parses structured JSON back into `FoodItem` records. A `NotificationService` schedules one daily digest using `UserNotifications`.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, Anthropic Claude API (claude-sonnet-4-6), UserNotifications, AVFoundation (camera)

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `FreshCheck.xcodeproj` (via Xcode)
- Create: `FreshCheck/FreshCheckApp.swift`
- Create: `FreshCheck/ContentView.swift`
- Create: `FreshCheckTests/FreshCheckTests.swift`

**Step 1: Create the Xcode project**

Open Xcode → New Project → iOS → App
- Product Name: `FreshCheck`
- Interface: SwiftUI
- Storage: SwiftData
- Include Tests: YES
- Language: Swift

**Step 2: Add Anthropic API key to environment**

In Xcode: Edit Scheme → Run → Arguments → Environment Variables
- Name: `ANTHROPIC_API_KEY`
- Value: your API key

**Step 3: Add `.gitignore`**

Create `FreshCheck/.gitignore`:
```
*.xcuserstate
xcuserdata/
DerivedData/
.DS_Store
*.env
```

**Step 4: Verify the app builds and runs**

Run: Cmd+R on simulator
Expected: Default "Hello, World!" SwiftUI app launches

**Step 5: Commit**

```bash
git init
git add .
git commit -m "feat: initial Xcode project scaffold"
```

---

## Task 2: Data Models

**Files:**
- Create: `FreshCheck/Models/FoodItem.swift`
- Create: `FreshCheck/Models/WasteRecord.swift`
- Create: `FreshCheck/Models/Enums.swift`
- Test: `FreshCheckTests/Models/FoodItemTests.swift`

**Step 1: Write failing test**

Create `FreshCheckTests/Models/FoodItemTests.swift`:
```swift
import XCTest
@testable import FreshCheck

final class FoodItemTests: XCTestCase {

    func test_status_fresh_whenMoreThanThreeDaysRemaining() {
        let item = FoodItem(
            name: "Broccoli",
            category: .produce,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.status, .fresh)
    }

    func test_status_expiringSoon_whenThreeDaysOrLess() {
        let item = FoodItem(
            name: "Milk",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.status, .expiringSoon)
    }

    func test_status_expired_whenPastExpiryDate() {
        let item = FoodItem(
            name: "Chicken",
            category: .meat,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.status, .expired)
    }

    func test_daysRemaining_returnsCorrectCount() {
        let item = FoodItem(
            name: "Yogurt",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.daysRemaining, 4)
    }
}
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `FoodItem` not defined

**Step 3: Create `Enums.swift`**

```swift
// FreshCheck/Models/Enums.swift
import Foundation

enum FoodCategory: String, Codable, CaseIterable {
    case produce, meat, dairy, packaged, other

    var icon: String {
        switch self {
        case .produce:  return "🥦"
        case .meat:     return "🥩"
        case .dairy:    return "🥛"
        case .packaged: return "📦"
        case .other:    return "🍽️"
        }
    }
}

enum ConfidenceSource: String, Codable {
    case ocr, shelfLife
}

enum ItemStatus: String, Codable {
    case fresh, expiringSoon, expired, consumed, wasted
}

enum DisposalOutcome: String, Codable {
    case consumed, wasted
}
```

**Step 4: Create `FoodItem.swift`**

```swift
// FreshCheck/Models/FoodItem.swift
import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var category: FoodCategory
    var photoURL: String
    var addedDate: Date
    var expiryDate: Date
    var confidenceSource: ConfidenceSource
    var disposalStatus: ItemStatus

    init(
        name: String,
        category: FoodCategory,
        photoURL: String,
        addedDate: Date = Date(),
        expiryDate: Date,
        confidenceSource: ConfidenceSource
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.photoURL = photoURL
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.confidenceSource = confidenceSource
        self.disposalStatus = .fresh
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
    }

    var status: ItemStatus {
        if disposalStatus == .consumed || disposalStatus == .wasted {
            return disposalStatus
        }
        if expiryDate < Date() { return .expired }
        if daysRemaining <= 3  { return .expiringSoon }
        return .fresh
    }
}
```

**Step 5: Create `WasteRecord.swift`**

```swift
// FreshCheck/Models/WasteRecord.swift
import Foundation
import SwiftData

@Model
final class WasteRecord {
    var id: UUID
    var foodItemName: String
    var category: FoodCategory
    var addedDate: Date
    var expiryDate: Date
    var disposedDate: Date
    var outcome: DisposalOutcome

    init(
        foodItemName: String,
        category: FoodCategory,
        addedDate: Date,
        expiryDate: Date,
        disposedDate: Date = Date(),
        outcome: DisposalOutcome
    ) {
        self.id = UUID()
        self.foodItemName = foodItemName
        self.category = category
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.disposedDate = disposedDate
        self.outcome = outcome
    }
}
```

**Step 6: Run tests to verify they pass**

Run: Cmd+U
Expected: All 4 tests PASS

**Step 7: Commit**

```bash
git add FreshCheck/Models/ FreshCheckTests/Models/
git commit -m "feat: add FoodItem and WasteRecord SwiftData models with status logic"
```

---

## Task 3: Claude Vision Service

**Files:**
- Create: `FreshCheck/Services/ClaudeVisionService.swift`
- Create: `FreshCheck/Services/ClaudeResponse.swift`
- Test: `FreshCheckTests/Services/ClaudeVisionServiceTests.swift`

**Step 1: Write failing tests**

Create `FreshCheckTests/Services/ClaudeVisionServiceTests.swift`:
```swift
import XCTest
@testable import FreshCheck

final class ClaudeVisionServiceTests: XCTestCase {

    func test_parseResponse_validJSON_returnsFoodAnalysis() throws {
        let json = """
        {
            "name": "Broccoli",
            "category": "produce",
            "expiryDate": "2026-03-05",
            "confidenceSource": "shelfLife",
            "shelfLifeDays": 5
        }
        """
        let data = json.data(using: .utf8)!
        let result = try ClaudeVisionService.parseResponse(data)
        XCTAssertEqual(result.name, "Broccoli")
        XCTAssertEqual(result.category, .produce)
        XCTAssertEqual(result.confidenceSource, .shelfLife)
        XCTAssertEqual(result.shelfLifeDays, 5)
    }

    func test_parseResponse_ocrSource_hasNilShelfLifeDays() throws {
        let json = """
        {
            "name": "Whole Milk",
            "category": "dairy",
            "expiryDate": "2026-03-10",
            "confidenceSource": "ocr",
            "shelfLifeDays": null
        }
        """
        let data = json.data(using: .utf8)!
        let result = try ClaudeVisionService.parseResponse(data)
        XCTAssertEqual(result.confidenceSource, .ocr)
        XCTAssertNil(result.shelfLifeDays)
    }

    func test_resizeImage_reducesLargeImageToMaxDimension() {
        let largeImage = UIImage(systemName: "photo")!
        let resized = ClaudeVisionService.resizeImage(largeImage, maxDimension: 1024)
        let maxSide = max(resized.size.width, resized.size.height)
        XCTAssertLessThanOrEqual(maxSide, 1024)
    }

    func test_capShelfLife_clampsFreshProduceOver30Days() {
        let result = ClaudeVisionService.capShelfLifeDays(999, for: .produce)
        XCTAssertEqual(result, 30)
    }

    func test_capShelfLife_doesNotCapPackagedGoods() {
        let result = ClaudeVisionService.capShelfLifeDays(90, for: .packaged)
        XCTAssertEqual(result, 90)
    }
}
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `ClaudeVisionService` not defined

**Step 3: Create `ClaudeResponse.swift`**

```swift
// FreshCheck/Services/ClaudeResponse.swift
import Foundation

struct FoodAnalysis: Codable {
    let name: String
    let category: FoodCategory
    let expiryDate: String         // ISO 8601 string from Claude
    let confidenceSource: ConfidenceSource
    let shelfLifeDays: Int?

    var parsedExpiryDate: Date? {
        ISO8601DateFormatter().date(from: expiryDate)
    }
}
```

**Step 4: Create `ClaudeVisionService.swift`**

```swift
// FreshCheck/Services/ClaudeVisionService.swift
import Foundation
import UIKit

final class ClaudeVisionService {

    static let apiKey = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    private static let prompt = """
    You are analyzing a photo of food that will be stored in a fridge.

    1. Identify the food item(s) visible in the photo.
    2. If a printed expiry/best-before date is visible on packaging, extract it.
    3. If no printed date is visible, estimate shelf life in the fridge based on food safety standards.

    Today's date is \(ISO8601DateFormatter().string(from: Date())).

    Respond ONLY with JSON in this exact format:
    {
      "name": "Broccoli",
      "category": "produce",
      "expiryDate": "2026-03-05",
      "confidenceSource": "shelfLife",
      "shelfLifeDays": 5
    }

    category must be one of: produce | meat | dairy | packaged | other
    confidenceSource must be one of: ocr | shelfLife
    shelfLifeDays is null when confidenceSource is ocr
    """

    // MARK: - Public API

    static func analyze(image: UIImage) async throws -> FoodAnalysis {
        let resized = resizeImage(image, maxDimension: 1024)
        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
            throw AnalysisError.imageEncodingFailed
        }
        let base64 = imageData.base64EncodedString()
        let body = buildRequestBody(base64Image: base64)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AnalysisError.apiError
        }

        var analysis = try parseResponse(data)

        // Cap implausible shelf life for fresh produce
        if let days = analysis.shelfLifeDays {
            let capped = capShelfLifeDays(days, for: analysis.category)
            if capped != days {
                analysis = FoodAnalysis(
                    name: analysis.name,
                    category: analysis.category,
                    expiryDate: Calendar.current.date(
                        byAdding: .day, value: capped, to: Date()
                    ).map { ISO8601DateFormatter().string(from: $0) } ?? analysis.expiryDate,
                    confidenceSource: analysis.confidenceSource,
                    shelfLifeDays: capped
                )
            }
        }
        return analysis
    }

    // MARK: - Helpers (internal for testability)

    static func parseResponse(_ data: Data) throws -> FoodAnalysis {
        // Claude wraps response in messages structure — extract text content
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? [[String: Any]],
           let text = content.first?["text"] as? String,
           let jsonData = text.data(using: .utf8) {
            return try JSONDecoder().decode(FoodAnalysis.self, from: jsonData)
        }
        // Fallback: try to decode directly (for unit tests with raw JSON)
        return try JSONDecoder().decode(FoodAnalysis.self, from: data)
    }

    static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    static func capShelfLifeDays(_ days: Int, for category: FoodCategory) -> Int {
        switch category {
        case .produce, .meat: return min(days, 30)
        default:              return days
        }
    }

    // MARK: - Private

    private static func buildRequestBody(base64Image: String) -> [String: Any] {
        [
            "model": "claude-sonnet-4-6",
            "max_tokens": 256,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64Image
                    ]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
    }

    enum AnalysisError: Error {
        case imageEncodingFailed
        case apiError
        case unrecognizedFood
    }
}
```

**Step 5: Run tests to verify they pass**

Run: Cmd+U
Expected: All 5 service tests PASS

**Step 6: Commit**

```bash
git add FreshCheck/Services/ FreshCheckTests/Services/
git commit -m "feat: add ClaudeVisionService with image resize and JSON parsing"
```

---

## Task 4: Photo Storage Service

**Files:**
- Create: `FreshCheck/Services/PhotoStorageService.swift`
- Test: `FreshCheckTests/Services/PhotoStorageServiceTests.swift`

**Step 1: Write failing test**

```swift
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
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `PhotoStorageService` not defined

**Step 3: Implement `PhotoStorageService.swift`**

```swift
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
```

**Step 4: Run tests to verify they pass**

Run: Cmd+U
Expected: All 2 photo storage tests PASS

**Step 5: Commit**

```bash
git add FreshCheck/Services/PhotoStorageService.swift FreshCheckTests/Services/PhotoStorageServiceTests.swift
git commit -m "feat: add PhotoStorageService for local image persistence"
```

---

## Task 5: Camera Capture View

**Files:**
- Create: `FreshCheck/Views/Camera/CameraView.swift`
- Create: `FreshCheck/Views/Camera/ImagePicker.swift`

No unit tests for UIKit camera wrapper — test via UI manually.

**Step 1: Create `ImagePicker.swift` (UIViewControllerRepresentable)**

```swift
// FreshCheck/Views/Camera/ImagePicker.swift
import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

**Step 2: Create `CameraView.swift`**

```swift
// FreshCheck/Views/Camera/CameraView.swift
import SwiftUI

struct CameraView: View {
    @State private var capturedImage: UIImage?
    @State private var showingPicker = false
    var onImageCaptured: (UIImage) -> Void

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Label("Add Food", systemImage: "camera.fill")
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
        .sheet(isPresented: $showingPicker) {
            ImagePicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, image in
            if let image { onImageCaptured(image) }
        }
    }
}
```

**Step 3: Verify build**

Run: Cmd+B
Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add FreshCheck/Views/Camera/
git commit -m "feat: add camera capture view with UIImagePickerController bridge"
```

---

## Task 6: Food Analysis Result View

**Files:**
- Create: `FreshCheck/Views/Camera/AnalysisResultView.swift`
- Create: `FreshCheck/ViewModels/AddFoodViewModel.swift`
- Test: `FreshCheckTests/ViewModels/AddFoodViewModelTests.swift`

**Step 1: Write failing test**

```swift
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
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `AddFoodViewModel` not defined

**Step 3: Create `AddFoodViewModel.swift`**

```swift
// FreshCheck/ViewModels/AddFoodViewModel.swift
import Foundation
import SwiftUI

@Observable
final class AddFoodViewModel {
    var name: String = ""
    var category: FoodCategory = .other
    var expiryDate: Date = Date()
    var confidenceSource: ConfidenceSource = .shelfLife
    var isLoading: Bool = false
    var errorMessage: String?
    var analysisComplete: Bool = false

    var isExpiredOnAdd: Bool {
        expiryDate < Date()
    }

    func populate(from analysis: FoodAnalysis) {
        name = analysis.name
        category = analysis.category
        confidenceSource = analysis.confidenceSource
        expiryDate = analysis.parsedExpiryDate ?? Date()
        analysisComplete = true
    }
}
```

**Step 4: Create `AnalysisResultView.swift`**

```swift
// FreshCheck/Views/Camera/AnalysisResultView.swift
import SwiftUI

struct AnalysisResultView: View {
    @Bindable var vm: AddFoodViewModel
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Detected Food") {
                    HStack {
                        Text(vm.category.icon).font(.largeTitle)
                        TextField("Food name", text: $vm.name)
                    }
                    Picker("Category", selection: $vm.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.rawValue.capitalized)").tag(cat)
                        }
                    }
                }

                Section("Expiry Date") {
                    DatePicker("Expires", selection: $vm.expiryDate, displayedComponents: .date)
                    HStack {
                        Image(systemName: vm.confidenceSource == .ocr ? "text.viewfinder" : "sparkles")
                            .foregroundColor(.secondary)
                        Text(vm.confidenceSource == .ocr ? "Read from package" : "AI estimate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if vm.isExpiredOnAdd {
                    Section {
                        Label("This item may already be expired.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("Confirm Food Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: onConfirm)
                        .disabled(vm.name.isEmpty)
                }
            }
        }
    }
}
```

**Step 5: Run tests to verify they pass**

Run: Cmd+U
Expected: All 3 view model tests PASS

**Step 6: Commit**

```bash
git add FreshCheck/ViewModels/AddFoodViewModel.swift FreshCheck/Views/Camera/AnalysisResultView.swift FreshCheckTests/ViewModels/
git commit -m "feat: add AddFoodViewModel and analysis result confirmation view"
```

---

## Task 7: Add Food Flow (Wire Camera → Claude → Confirm → Save)

**Files:**
- Create: `FreshCheck/Views/Camera/AddFoodFlow.swift`

**Step 1: Create `AddFoodFlow.swift`**

```swift
// FreshCheck/Views/Camera/AddFoodFlow.swift
import SwiftUI
import SwiftData

struct AddFoodFlow: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var vm = AddFoodViewModel()
    @State private var capturedImage: UIImage?
    @State private var showingCamera = false
    @State private var showingResult = false
    @State private var showingManualFallback = false

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Analyzing your food...")
                    .padding()
            } else if showingResult {
                AnalysisResultView(vm: vm) {
                    saveItem()
                } onCancel: {
                    dismiss()
                }
            } else {
                cameraPrompt
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $capturedImage)
                .ignoresSafeArea()
        }
        .onChange(of: capturedImage) { _, image in
            guard let image else { return }
            Task { await analyzeImage(image) }
        }
        .alert("Couldn't identify this food", isPresented: $showingManualFallback) {
            TextField("Food name", text: $vm.name)
            Button("Add") { showingResult = true }
            Button("Cancel", role: .cancel) { dismiss() }
        } message: {
            Text("Please enter the food name manually.")
        }
        .onAppear { showingCamera = true }
    }

    private var cameraPrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.largeTitle)
            Text("Opening camera...").foregroundColor(.secondary)
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        vm.isLoading = true
        do {
            let analysis = try await ClaudeVisionService.analyze(image: image)
            let photoPath = try PhotoStorageService.save(image: image)
            vm.populate(from: analysis)
            // Override photoURL on the item we'll create
            capturedPhotoPath = photoPath
            showingResult = true
        } catch {
            showingManualFallback = true
        }
        vm.isLoading = false
    }

    @State private var capturedPhotoPath: String = ""

    private func saveItem() {
        let item = FoodItem(
            name: vm.name,
            category: vm.category,
            photoURL: capturedPhotoPath,
            expiryDate: vm.expiryDate,
            confidenceSource: vm.confidenceSource
        )
        context.insert(item)
        dismiss()
    }
}
```

**Step 2: Verify build**

Run: Cmd+B
Expected: Build succeeds

**Step 3: Manual test on simulator**

- Tap "Add Food" → camera opens
- Take a photo of a food item → loading spinner appears
- Result card shows detected name + expiry → tap Confirm
- Item appears in dashboard

**Step 4: Commit**

```bash
git add FreshCheck/Views/Camera/AddFoodFlow.swift
git commit -m "feat: wire camera → Claude API → confirm → SwiftData save flow"
```

---

## Task 8: Dashboard Screen

**Files:**
- Create: `FreshCheck/Views/Dashboard/DashboardView.swift`
- Create: `FreshCheck/Views/Dashboard/FoodItemRow.swift`

**Step 1: Create `FoodItemRow.swift`**

```swift
// FreshCheck/Views/Dashboard/FoodItemRow.swift
import SwiftUI

struct FoodItemRow: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail
            Group {
                if let image = PhotoStorageService.load(from: item.photoURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(item.category.icon).font(.title2)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text(item.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                daysLabel
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var daysLabel: some View {
        let days = item.daysRemaining
        let text = days < 0 ? "Expired" : days == 0 ? "Today" : "\(days)d"
        return Text(text).font(.subheadline).bold()
    }

    private var statusBadge: some View {
        let color: Color = switch item.status {
            case .fresh: .green
            case .expiringSoon: .orange
            case .expired: .red
            default: .gray
        }
        return Circle().fill(color).frame(width: 10, height: 10)
    }
}
```

**Step 2: Create `DashboardView.swift`**

```swift
// FreshCheck/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    @Environment(\.modelContext) private var context
    @State private var showingAddFood = false

    private var activeItems: [FoodItem] {
        items.filter { $0.status != .consumed && $0.status != .wasted }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(activeItems) { item in
                    FoodItemRow(item: item)
                        .swipeActions(edge: .trailing) {
                            Button("Wasted", role: .destructive) {
                                dispose(item, outcome: .wasted)
                            }
                            Button("Consumed") {
                                dispose(item, outcome: .consumed)
                            }
                            .tint(.green)
                        }
                }
            }
            .navigationTitle("My Fridge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodFlow()
            }
            .overlay {
                if activeItems.isEmpty {
                    ContentUnavailableView(
                        "Fridge is empty",
                        systemImage: "refrigerator",
                        description: Text("Tap the camera icon to add food.")
                    )
                }
            }
        }
    }

    private func dispose(_ item: FoodItem, outcome: DisposalOutcome) {
        let record = WasteRecord(
            foodItemName: item.name,
            category: item.category,
            addedDate: item.addedDate,
            expiryDate: item.expiryDate,
            outcome: outcome
        )
        context.insert(record)
        item.disposalStatus = outcome == .consumed ? .consumed : .wasted
        try? PhotoStorageService.delete(at: item.photoURL)
    }
}
```

**Step 3: Update `ContentView.swift` to show Dashboard**

```swift
// FreshCheck/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Fridge", systemImage: "refrigerator") }
            WasteStatsView()
                .tabItem { Label("Waste", systemImage: "chart.bar.fill") }
        }
    }
}
```

**Step 4: Verify build and manual test**

Run: Cmd+B, then Cmd+R
Expected: Dashboard with empty state, camera button in toolbar

**Step 5: Commit**

```bash
git add FreshCheck/Views/Dashboard/ FreshCheck/ContentView.swift
git commit -m "feat: add dashboard with color-coded food list and swipe-to-dispose actions"
```

---

## Task 9: Waste Stats Screen

**Files:**
- Create: `FreshCheck/Views/Stats/WasteStatsView.swift`
- Test: `FreshCheckTests/Views/WasteStatsViewModelTests.swift`

**Step 1: Write failing test**

```swift
// FreshCheckTests/Views/WasteStatsViewModelTests.swift
import XCTest
@testable import FreshCheck

final class WasteStatsTests: XCTestCase {

    func test_wastePercentage_calculatesCorrectly() {
        let records = [
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .wasted),
            makeRecord(outcome: .wasted),
        ]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 50.0, accuracy: 0.1)
    }

    func test_wastePercentage_zeroWhenEmpty() {
        let percentage = WasteStatsCalculator.wastePercentage(from: [])
        XCTAssertEqual(percentage, 0.0)
    }

    func test_countByCategory_groupsCorrectly() {
        let records = [
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .meat, outcome: .wasted),
        ]
        let counts = WasteStatsCalculator.wastedCountByCategory(from: records)
        XCTAssertEqual(counts[.produce], 2)
        XCTAssertEqual(counts[.meat], 1)
    }

    private func makeRecord(category: FoodCategory = .produce, outcome: DisposalOutcome) -> WasteRecord {
        WasteRecord(
            foodItemName: "Test",
            category: category,
            addedDate: Date(),
            expiryDate: Date(),
            outcome: outcome
        )
    }
}
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `WasteStatsCalculator` not defined

**Step 3: Create `WasteStatsView.swift`**

```swift
// FreshCheck/Views/Stats/WasteStatsView.swift
import SwiftUI
import SwiftData
import Charts

struct WasteStatsView: View {
    @Query private var records: [WasteRecord]

    private var thisMonth: [WasteRecord] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return records.filter { $0.disposedDate >= start }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("This Month") {
                    HStack {
                        statTile(title: "Logged", value: thisMonth.count)
                        statTile(title: "Consumed", value: thisMonth.filter { $0.outcome == .consumed }.count)
                        statTile(title: "Wasted", value: thisMonth.filter { $0.outcome == .wasted }.count)
                    }
                    let pct = WasteStatsCalculator.wastePercentage(from: thisMonth)
                    Text("Waste rate: \(Int(pct))%")
                        .font(.headline)
                        .foregroundColor(pct > 30 ? .red : .green)
                }

                Section("Wasted by Category") {
                    let counts = WasteStatsCalculator.wastedCountByCategory(from: thisMonth)
                    Chart(FoodCategory.allCases, id: \.self) { category in
                        BarMark(
                            x: .value("Category", category.rawValue.capitalized),
                            y: .value("Count", counts[category] ?? 0)
                        )
                        .foregroundStyle(Color.red.opacity(0.7))
                    }
                    .frame(height: 180)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Waste Tracker")
        }
    }

    private func statTile(title: String, value: Int) -> some View {
        VStack {
            Text("\(value)").font(.title).bold()
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calculator (pure logic, testable)

enum WasteStatsCalculator {
    static func wastePercentage(from records: [WasteRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        let wasted = records.filter { $0.outcome == .wasted }.count
        return Double(wasted) / Double(records.count) * 100
    }

    static func wastedCountByCategory(from records: [WasteRecord]) -> [FoodCategory: Int] {
        records
            .filter { $0.outcome == .wasted }
            .reduce(into: [:]) { counts, record in
                counts[record.category, default: 0] += 1
            }
    }
}
```

**Step 4: Run tests to verify they pass**

Run: Cmd+U
Expected: All 3 stats tests PASS

**Step 5: Commit**

```bash
git add FreshCheck/Views/Stats/ FreshCheckTests/Views/
git commit -m "feat: add waste stats screen with monthly summary and category chart"
```

---

## Task 10: Daily Digest Notifications

**Files:**
- Create: `FreshCheck/Services/NotificationService.swift`
- Test: `FreshCheckTests/Services/NotificationServiceTests.swift`

**Step 1: Write failing test**

```swift
// FreshCheckTests/Services/NotificationServiceTests.swift
import XCTest
@testable import FreshCheck

final class NotificationServiceTests: XCTestCase {

    func test_buildDigestMessage_listsSoonExpiringItems() {
        let items = [
            makeFoodItem(name: "Broccoli", daysUntilExpiry: 1),
            makeFoodItem(name: "Milk", daysUntilExpiry: 2),
            makeFoodItem(name: "Apple", daysUntilExpiry: 10),  // not expiring soon
        ]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertTrue(message.contains("Broccoli"))
        XCTAssertTrue(message.contains("Milk"))
        XCTAssertFalse(message.contains("Apple"))
    }

    func test_buildDigestMessage_returnsNil_whenNothingExpiringSoon() {
        let items = [makeFoodItem(name: "Apple", daysUntilExpiry: 10)]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNil(message)
    }

    private func makeFoodItem(name: String, daysUntilExpiry: Int) -> FoodItem {
        FoodItem(
            name: name,
            category: .produce,
            photoURL: "",
            expiryDate: Calendar.current.date(byAdding: .day, value: daysUntilExpiry, to: Date())!,
            confidenceSource: .shelfLife
        )
    }
}
```

**Step 2: Run test to verify it fails**

Run: Cmd+U
Expected: Compile error — `NotificationService` not defined

**Step 3: Create `NotificationService.swift`**

```swift
// FreshCheck/Services/NotificationService.swift
import Foundation
import UserNotifications

final class NotificationService {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleDailyDigest(hour: Int = 8, minute: Int = 0, items: [FoodItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-digest"])

        guard let message = buildDigestMessage(for: items) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fridge Check"
        content.body = message
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-digest",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // Internal for testability
    static func buildDigestMessage(for items: [FoodItem]) -> String? {
        let expiringSoon = items.filter { $0.status == .expiringSoon || $0.status == .expired }
        guard !expiringSoon.isEmpty else { return nil }
        let names = expiringSoon.prefix(5).map { $0.name }.joined(separator: ", ")
        let count = expiringSoon.count
        return "\(count) item\(count == 1 ? "" : "s") expiring soon: \(names)."
    }
}
```

**Step 4: Wire notification scheduling into App lifecycle**

Update `FreshCheckApp.swift`:
```swift
// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData

@main
struct FreshCheckApp: App {
    @Query private var items: [FoodItem]

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    let granted = await NotificationService.requestPermission()
                    if granted {
                        NotificationService.scheduleDailyDigest(items: items)
                    }
                }
        }
        .modelContainer(for: [FoodItem.self, WasteRecord.self])
    }
}
```

**Step 5: Run tests to verify they pass**

Run: Cmd+U
Expected: All 2 notification tests PASS

**Step 6: Commit**

```bash
git add FreshCheck/Services/NotificationService.swift FreshCheckTests/Services/NotificationServiceTests.swift FreshCheck/FreshCheckApp.swift
git commit -m "feat: add daily digest push notification scheduling"
```

---

## Task 11: Final Integration & Smoke Test

**Step 1: Run full test suite**

Run: Cmd+U
Expected: All tests PASS, 0 failures

**Step 2: Manual end-to-end test on device**

Checklist:
- [ ] Launch app → notification permission prompt appears
- [ ] Tap camera → camera opens → take photo of fresh produce → loading spinner → result card shows detected item with AI-estimated expiry → confirm → item appears in dashboard (green badge)
- [ ] Take photo of packaged item with visible date → result card shows "Read from package" badge
- [ ] Swipe left on item → tap "Consumed" → item disappears from list
- [ ] Swipe left on item → tap "Wasted" → item disappears, waste stats update
- [ ] Switch to Waste tab → this month's summary shows correct counts
- [ ] Take photo of unrecognizable item → manual fallback prompt appears
- [ ] Test with no internet → "Internet required" message shown

**Step 3: Final commit**

```bash
git add .
git commit -m "feat: FreshCheck v1 complete — photo-based fridge expiry tracker"
```
