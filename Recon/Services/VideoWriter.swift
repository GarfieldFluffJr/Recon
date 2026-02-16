//
//  VideoWriter.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-12.
//

// Replace AVCaptureMovieFileOutput - instead of writing video to a file, manually feed it the composited frames and audio samples

import AVFoundation
import CoreImage

class VideoWriter {
    private var assetWriter: AVAssetWriter? // Write the .mov file
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor? // Converts images into raw pixel data the writer understands
    private let ciContext = CIContext()
    
    var isWriting = false
    private var sessionStarted = false
    
    func startWriting(to url: URL, videoSize: CGSize) {
        // Reset everything from previous recording
        assetWriter = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        sessionStarted = false
        isWriting = false

        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            print("Failed to create asset writer: \(error)")
            return
        }
        
        // Video input settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264, // H.264 standard compression format
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height)
        ]
        
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true
        
        // Pixel buffer adaptor - converts CIImage frames into pixel buffers the writer understands
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(videoSize.width),
                kCVPixelBufferHeightKey as String: Int(videoSize.height)
            ]
        )
        
        // Audio input settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true
    
        // Add inputs to writer
        if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        
        if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
        
        assetWriter?.startWriting()
        isWriting = true
        sessionStarted = false
    }
    
    func writeVideoFrame(_ image: CIImage, at time: CMTime) {
        guard isWriting,
              let adaptor = pixelBufferAdaptor,
              let pool = adaptor.pixelBufferPool,
              videoInput?.isReadyForMoreMediaData == true else { return }
        
        // Start session on first frame
        if !sessionStarted {
            assetWriter?.startSession(atSourceTime: time)
            sessionStarted = true
        }
        
        // Convert CIImage to pixel buffer
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
        guard let buffer = pixelBuffer else { return }
        
        ciContext.render(image, to: buffer)
        adaptor.append(buffer, withPresentationTime: time)
    }
    
    func writeAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard isWriting, sessionStarted,
              assetWriter?.status == .writing,
              audioInput?.isReadyForMoreMediaData == true else { return }

        audioInput?.append(sampleBuffer)
    }
    
    func stopWriting(completion: @escaping (URL?) -> Void) {
        guard isWriting else {
            completion(nil)
            return
        }
        isWriting = false
        
        let url = assetWriter?.outputURL
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        assetWriter?.finishWriting {
            completion(url)
        }
    }
}
