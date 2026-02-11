//
//  CameraService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-10.
//

import AVFoundation
import Combine

class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    // Pipeline manager, connecting inputs to outputs
    let session = AVCaptureSession()
    // Write video + audio to .mov file on disk
    let movieOutput = AVCaptureMovieFileOutput()
    
    func configure() {
        // Make changes to the session
        session.beginConfiguration()
        
        // Back camera (normal camera)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera found")
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
            }
        } catch {
            print("Failed to create video input: \(error)")
            return
        }
        
        // Movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        // Apply changes to the session
        session.commitConfiguration()
        session.startRunning()
    }
}
