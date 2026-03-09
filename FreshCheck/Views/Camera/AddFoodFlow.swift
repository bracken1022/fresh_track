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
                ProgressView(L10n.tr("camera.loading"))
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
        .alert(L10n.tr("camera.service.error.title"), isPresented: $showingApiKeyError) {
            Button(L10n.tr("common.ok"), role: .cancel) { dismiss() }
        } message: {
            Text(apiKeyErrorDetail.isEmpty
                 ? L10n.tr("camera.service.error.default")
                 : apiKeyErrorDetail)
        }
        .alert(L10n.tr("camera.manual.title"), isPresented: $showingManualFallback) {
            TextField(L10n.tr("camera.field.foodName"), text: $vm.name)
            Button(L10n.tr("common.add")) { showingResult = true }
            Button(L10n.tr("common.cancel"), role: .cancel) { dismiss() }
        } message: {
            Text(L10n.tr("camera.manual.desc"))
        }
        .onAppear { showingCamera = true }
    }

    private var cameraPrompt: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: AppTheme.Icons.cameraTab)
                .font(.largeTitle)
                .foregroundColor(AppTheme.Colors.textSecondary)
            Text(L10n.tr("camera.opening"))
                .font(AppTheme.Typography.body)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        print("📷 analyzeImage called — proxy URL set: \(!ClaudeVisionService.proxyURLString.isEmpty)")
        vm.isLoading = true
        do {
            let analysis = try await ClaudeVisionService.analyze(image: image)
            let photoPath = try PhotoStorageService.save(image: image)
            vm.populate(from: analysis)
            capturedPhotoPath = photoPath
            showingResult = true
        } catch ClaudeVisionService.AnalysisError.invalidConfiguration(let detail) {
            print("❌ Proxy configuration error: \(detail)")
            apiKeyErrorDetail = detail
            showingApiKeyError = true
        } catch ClaudeVisionService.AnalysisError.invalidApiKey(let detail) {
            print("❌ Invalid proxy token/API key: \(detail)")
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
        StreakService.recordActivity()
        dismiss()
    }
}
