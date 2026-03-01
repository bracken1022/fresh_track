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
            Label("Add Food", systemImage: AppTheme.Icons.cameraTab)
                .font(AppTheme.Typography.headline)
                .padding()
                .background(AppTheme.Colors.accent)
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
