//
//  CameraPreviewView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-11.
//

// Purpose: take the session and display the live camera feed on the screen

import SwiftUI
import AVFoundation // Audio/Video framework

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    // Create a plain UIView, add camera preview layer
    // UIView is the basic canvas like an empty <div>, and AVCaptureVideoPreviewLayer is like <video> but needs to sit on a UIView
    func makeUIView(context:Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill // Take up entire screen
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    // Every time SwiftUI rerenders, resize preview layer to match the view
    // Underscore means no external label, only internal (uiView)
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
