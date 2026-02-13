//
//  CameraService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-10.
//

import AVFoundation
import Combine
import CoreImage

class CameraService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0

    // Dual camera session (upgraded from AVCaptureSession)
    let session = AVCaptureMultiCamSession()

    // Services
    private let compositor = VideoCompositor()
    private let videoWriter = VideoWriter()
    let locationService = LocationService()

    // Raw frame outputs (one per camera + one for audio)
    private let backVideoOutput = AVCaptureVideoDataOutput()
    private let frontVideoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()

    // Background queue for processing frames ~30fps
    private let dataQueue = DispatchQueue(label: "com.recon.dataQueue")

    // Latest frame from each camera (they fire independently, not in sync, but combine as smoothly as possible)
    private var latestBackFrame: CIImage?
    private var latestFrontFrame: CIImage?

    // Recording state
    private var timer: Timer?
    private var currentFileURL: URL?

    // 720p
    private let videoSize = CGSize(width: 1280, height: 720)

    func configure() {
        print("configure() called")

        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported on this device")
            return
        }

        session.beginConfiguration()

        // Back camera
        guard let backDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No back camera found")
            return
        }

        do {
            let backInput = try AVCaptureDeviceInput(device: backDevice)
            if session.canAddInput(backInput) {
                session.addInput(backInput)
                print("Added back camera input")
            }
        } catch {
            print("Failed to create back camera input: \(error)")
            return
        }

        // Front camera
        guard let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("No front camera found")
            return
        }

        do {
            let frontInput = try AVCaptureDeviceInput(device: frontDevice)
            if session.canAddInput(frontInput) {
                session.addInput(frontInput)
                print("Added front camera input")
            }
        } catch {
            print("Failed to create front camera input: \(error)")
            return
        }

        // Microphone
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(audioInput) {
                    session.addInput(audioInput)
                    print("Added audio input")
                }
            } catch {
                print("Failed to create audio input: \(error)")
            }
        }

        // Back camera output — delegate sends raw frames to captureOutput()
        backVideoOutput.setSampleBufferDelegate(self, queue: dataQueue)
        if session.canAddOutput(backVideoOutput) {
            session.addOutput(backVideoOutput)
            print("Added back video output")
        }

        // Front camera output
        frontVideoOutput.setSampleBufferDelegate(self, queue: dataQueue)
        if session.canAddOutput(frontVideoOutput) {
            session.addOutput(frontVideoOutput)
            print("Added front video output")
        }

        // Audio output
        audioOutput.setSampleBufferDelegate(self, queue: dataQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
            print("Added audio output")
        }

        // Manually connect back camera input → back output
        if let backInput = session.inputs.first(where: {
            ($0 as? AVCaptureDeviceInput)?.device.position == .back
        }) as? AVCaptureDeviceInput {
            let backConnection = AVCaptureConnection(inputPorts: backInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .back), output: backVideoOutput)
            if session.canAddConnection(backConnection) {
                session.addConnection(backConnection)
                print("Connected back camera")
            }
        }

        // Manually connect front camera input → front output
        if let frontInput = session.inputs.first(where: {
            ($0 as? AVCaptureDeviceInput)?.device.position == .front
        }) as? AVCaptureDeviceInput {
            let frontConnection = AVCaptureConnection(inputPorts: frontInput.ports(for: .video, sourceDeviceType: .builtInWideAngleCamera, sourceDevicePosition: .front), output: frontVideoOutput)
            if session.canAddConnection(frontConnection) {
                session.addConnection(frontConnection)
                // Mirror front camera so it looks natural
                frontConnection.isVideoMirrored = true
                print("Connected front camera")
            }
        }

        session.commitConfiguration()
        print("Configuration committed, starting session...")

        // Start GPS
        locationService.requestPermission()
        locationService.startUpdating()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            print("Session running: \(self.session.isRunning)")
        }
    }

    func startRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "\(Date().timeIntervalSince1970).mov"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        currentFileURL = fileURL

        videoWriter.startWriting(to: fileURL, videoSize: videoSize)

        DispatchQueue.main.async {
            self.isRecording = true
            self.recordingTime = 0
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.recordingTime += 1
            }
        }
    }

    func stopRecording() {
        DispatchQueue.main.async {
            self.isRecording = false
            self.timer?.invalidate()
            self.timer = nil
        }

        videoWriter.stopWriting { url in
            if let url = url {
                print("Video saved to: \(url)")
            }
        }
    }
}

// Receives raw frames from both cameras and audio from mic
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Audio — write directly, no processing needed
        if output == audioOutput {
            if videoWriter.isWriting {
                videoWriter.writeAudioSample(sampleBuffer)
            }
            return
        }

        // Extract image from the frame
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Store frame based on which camera it came from
        if output == backVideoOutput {
            latestBackFrame = ciImage
        } else if output == frontVideoOutput {
            latestFrontFrame = ciImage
        }

        // Composite and write on back camera frames only (drives the frame rate)
        if output == backVideoOutput, videoWriter.isWriting,
           let backFrame = latestBackFrame,
           let frontFrame = latestFrontFrame {

            // Resize back frame to 720p
            let scaleX = videoSize.width / backFrame.extent.width
            let scaleY = videoSize.height / backFrame.extent.height
            let resizedBack = backFrame.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

            let composited = compositor.compose(backFrame: resizedBack, frontFrame: frontFrame)

            // Use absolute timestamp (audio uses absolute too, so they must match)
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            videoWriter.writeVideoFrame(composited, at: timestamp)
        }
    }
}
