//
//  TranscriptionService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-13.
//

// Transcribe the audio from the video into a transcript for Nova processing

import Speech
import Combine

class TranscriptionService: ObservableObject {
    @Published var liveTranscript = ""
    
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask? // Gives results as speech is decteced - active recognition
    
    // Apple's on-device recognition stops after ~60s, restart transcription every 50s to refresh
    private var restartTimer: Timer?
    private let restartInterval: TimeInterval = 50.0
    
    // Each 50s segment's text gets saved here so nothing is lost during restart
    private var completedText = ""
    
    // Show the permission modal
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition authorization: \(status.rawValue)")
        }
    }
    
    func startTranscribing() {
        recognizer = SFSpeechRecognizer()
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.requiresOnDeviceRecognition = true // Force on-device transcription
        recognitionRequest?.shouldReportPartialResults = true // Get results as words are spoken, not when finished
        
        startRecognitionTask() // Start listening for speech
        startRestartTimer() // Start the 50s restart cycle
    }
    
    // Called from CameraService every time a new audio sample arrives
    // Converts camera audio format (CMSampleBuffer) into speech format (AVAudioPCMBuffer)
    func appendAudioBuffer(_ buffer: CMSampleBuffer) {
        guard let request = recognitionRequest else { return }
        
        // Get audio format description from sample
        guard let formatDesc = CMSampleBufferGetFormatDescription(buffer),
              let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc) else { return }
        
        // Extract sample rate and channel count
        let sampleRate = streamDesc.pointee.mSampleRate
        let channelCount = streamDesc.pointee.mChannelsPerFrame
        
        // Create AVAudioFormat
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channelCount)) else { return }
        
        // Create PCM buffer to hold converted audio
        let numSamples = CMSampleBufferGetNumSamples(buffer)
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(numSamples)) else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(numSamples)
        
        // Get a pointer to the raw audio bytes in sample buffer
        guard let blockBuffer = CMSampleBufferGetDataBuffer(buffer) else { return }
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        
        // Fills in the variables with the blockBuffer data pointer (since old C code)
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)
        
        if let dataPointer = dataPointer, let channelData = pcmBuffer.floatChannelData {
            let sampleCount = numSamples
            let sourcePtr = UnsafeRawPointer(dataPointer)
            
            // Audio can be float23 or int16 (needs conversion)
            if streamDesc.pointee.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
                // Float32
                memcpy(channelData[0], sourcePtr, sampleCount * MemoryLayout<Float>.size)
            } else {
                // Int16 - convert each sample to float (-1.0 to 1.0 range)
                let int16Ptr = sourcePtr.bindMemory(to: Int16.self, capacity: sampleCount)
                for i in 0..<sampleCount {
                    channelData[0][i] = Float(int16Ptr[i]) / Float(Int16.max)
                }
            }
        }
        
        // Feed converted audio to speech recognizer
        request.append(pcmBuffer)
    }
    
    func stopTranscribing() -> String {
        // Kill restart timer
        restartTimer?.invalidate()
        restartTimer = nil
        
        // Stop recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Tell request no more audio incoming
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Append new transcript to the existing one
        let finalTranscript = completedText + " " + (liveTranscript.isEmpty ? "" : liveTranscript)
        
        DispatchQueue.main.async {
            self.liveTranscript = ""
        }
        
        // Reset for next recording
        let result = finalTranscript.trimmingCharacters(in: .whitespaces)
        completedText = ""
        return result
    }
    
    // Start a recognition task - Apple calls the closure every time it detects new words (closure is callback)
    private func startRecognitionTask() {
        guard let recognizer = recognizer,
              let request = recognitionRequest else { return }
        
        // recognitionTask runs continuously, closure fires every time new words are detected
        // [weak self] prevents a memory leak - don't keep this object alive just because the task exists
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self ] result, error in
            guard let self = self else { return }
            
            if let result = result {
                // bestTranscription is Apple's best guess at what was said
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    // Update the published property, UI rerenders with new text
                    // We don't keep appending because text is the full transcription that is constantly being updated after each closure call
                    self.liveTranscript = text
                }
            }
            
            if let error = error {
                print("Recognition error: \(error)")
            }
        }
    }
    
    // Restart recognition every 50s to avoid the 60s on-device limit
    private func startRestartTimer() {
        DispatchQueue.main.async {
            self.restartTimer = Timer.scheduledTimer(withTimeInterval: self.restartInterval, repeats: true) { [weak self] _ in
                self?.restartRecognition()
            }
        }
    }
    
    // Save current text, kill task, start a fresh one
    private func restartRecognition() {
        let currentText = liveTranscript
        if !currentText.isEmpty {
            completedText += " " + currentText
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.requiresOnDeviceRecognition = true
        recognitionRequest?.shouldReportPartialResults = true
        
        DispatchQueue.main.async {
            self.liveTranscript = ""
        }
        
        startRecognitionTask()
    }
}
