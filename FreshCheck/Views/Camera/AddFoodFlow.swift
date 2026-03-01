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
    @State private var showingApiKeyError = false
    @State private var apiKeyErrorDetail = ""

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView("Analyzing your food...")
                    .padding(AppTheme.Spacing.lg)
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
        .alert("API Key Invalid", isPresented: $showingApiKeyError) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text(apiKeyErrorDetail.isEmpty
                 ? "The Anthropic API key is invalid. Please update it in ClaudeVisionService.swift."
                 : apiKeyErrorDetail)
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
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: AppTheme.Icons.cameraTab)
                .font(.largeTitle)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text("Opening camera...")
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        print("📷 analyzeImage called — apiKey empty: \(ClaudeVisionService.apiKey.isEmpty)")
        vm.isLoading = true
        do {
            let analysis = try await ClaudeVisionService.analyze(image: image)
            let photoPath = try PhotoStorageService.save(image: image)
            vm.populate(from: analysis)
            capturedPhotoPath = photoPath
            showingResult = true
        } catch ClaudeVisionService.AnalysisError.invalidApiKey(let detail) {
            print("❌ Invalid API key: \(detail)")
            apiKeyErrorDetail = detail
            showingApiKeyError = true
        } catch {
            print("❌ FreshCheck analysis error: \(error)")
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
