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
        print("configure() called")
        // Make changes to the session
        session.beginConfiguration()

        // Back camera (normal camera)
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera found")
            return
        }
        print("Got camera device")

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("Added video input")
            }
        } catch {
            print("Failed to create video input: \(error)")
            return
        }

        // Movie output
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            print("Added movie output")
        }

        // Apply changes to the session
        session.commitConfiguration()
        print("Configuration committed, starting session...")

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            print("Session running: \(self.session.isRunning)")
        }
    }
    
    func startRecording() {
        // Returns the first element in the array of urls at the documentDirectory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsPath.appendingPathComponent(fileName) // Combine documentsPath and fileName
        
        // Start writing video data to this file, and CameraService (self) has the method to call when done recording
        movieOutput.startRecording(to: fileURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        movieOutput.stopRecording()
        isRecording = false
    }
}

// Camera API's are written in obj-c, an extension is to separate the functionalities, code cleaner
@objc extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        } else {
            print("Video saved to: \(outputFileURL)")
        }
    }
}
