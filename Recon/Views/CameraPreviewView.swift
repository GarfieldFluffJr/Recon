//
//  CameraPreviewView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-11.
//

// Purpose: take the session and display the live camera feed on the screen

import SwiftUI
import AVFoundation // Audio/Video framework

// Custom UIView that keeps the preview layer sized correctly
class VideoPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    // Create the view and connect the session
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill // Take up entire screen
        return view
    }

    // Nothing to update
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}
