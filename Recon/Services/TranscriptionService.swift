//
//  TranscriptionService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-13.
//

// Transcribe the audio from the video into a transcript for Nova processing

import Speech
import AVFoundation
import Combine

class TranscriptionService: ObservableObject {
    @Published var liveTranscript = ""

    // Recognizer created with a specific locale (defaults to en-US)
    private var recognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask? // Gives results as speech is decteced - active recognition

    // Apple's on-device recognition stops after ~60s, restart transcription every 50s to refresh
    private var restartTimer: Timer?
    private let restartInterval: TimeInterval = 50.0

    // Each 50s segment's text gets saved here so nothing is lost during restart
    private var completedText = ""

    // Fallback audio engine for when capture session has no audio (e.g. phone call)
    private var audioEngine: AVAudioEngine?
    private var usingAudioEngine = false
    
    // Recreate the recognizer with a new locale (call before recording starts)
    func setLocale(_ identifier: String) {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
        recognizer?.defaultTaskHint = .dictation
    }

    // Show the permission modal
    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            print("Speech recognition authorization: \(status.rawValue)")
        }
    }
    
    /// Start transcribing. If `useAudioEngine` is true, taps the mic directly via AVAudioEngine
    /// instead of waiting for capture session audio buffers (used during phone calls).
    func startTranscribing(useAudioEngine: Bool = false) {
        guard let recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }

        usingAudioEngine = useAudioEngine

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.requiresOnDeviceRecognition = true // Force on-device transcription
        recognitionRequest?.shouldReportPartialResults = true // Get results as words are spoken, not when finished
        recognitionRequest?.addsPunctuation = true // Auto-add punctuation

        if useAudioEngine {
            startAudioEngine()
        }

        startRecognitionTask() // Start listening for speech
        startRestartTimer() // Start the 50s restart cycle
    }

    /// Tap the mic directly via AVAudioEngine (fallback when capture session has no audio)
    private func startAudioEngine() {
        // Configure audio session for recording before accessing the input node
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio engine: failed to configure audio session: \(error)")
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Validate format — during a phone call the input may report 0 Hz / 0 channels
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            print("Audio engine: mic unavailable (format: \(recordingFormat)) — transcription will not work during this call")
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
            audioEngine = engine
            print("Audio engine started for transcription (fallback mode)")
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
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

        // Stop audio engine if it was used
        stopAudioEngine()
        usingAudioEngine = false

        // Stop recognition task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Tell request no more audio incoming
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        // Capture live transcript before clearing
        let currentLive = liveTranscript

        // Append new transcript to the existing one
        let finalTranscript = completedText + (currentLive.isEmpty ? "" : " " + currentLive)

        // Reset everything for next recording
        completedText = ""
        DispatchQueue.main.async {
            self.liveTranscript = ""
        }

        return finalTranscript.trimmingCharacters(in: .whitespaces)
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
            
            if let error = error as? NSError, error.code != 1110 {
                // 1110 = "No speech detected" — harmless, ignore it
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

        // Stop audio engine tap before creating new request
        if usingAudioEngine {
            stopAudioEngine()
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.requiresOnDeviceRecognition = true
        recognitionRequest?.shouldReportPartialResults = true

        // Restart audio engine tap with the new request
        if usingAudioEngine {
            startAudioEngine()
        }

        DispatchQueue.main.async {
            self.liveTranscript = ""
        }

        startRecognitionTask()
    }
}
