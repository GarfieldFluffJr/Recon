//
//  HomeView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-25.
//

// Homepage

import SwiftUI
import CoreLocation

struct HomeView: View {
    @ObservedObject var camera: CameraService
    @ObservedObject var analysisVM: AnalysisViewModel
    var switchToRecord: () -> Void = {}
    var switchToReports: (UUID?) -> Void = { _ in }

    @State private var showAnalysis = false
    @State private var selectedLanguage = "en-US"

    private let supportedLanguages: [(name: String, code: String, flag: String)] = [
        ("English (US)", "en-US", "\u{1F1FA}\u{1F1F8}"),
        ("English (UK)", "en-GB", "\u{1F1EC}\u{1F1E7}"),
        ("Spanish", "es-ES", "\u{1F1EA}\u{1F1F8}"),
        ("French", "fr-FR", "\u{1F1EB}\u{1F1F7}"),
        ("German", "de-DE", "\u{1F1E9}\u{1F1EA}"),
        ("Chinese (Mandarin)", "zh-CN", "\u{1F1E8}\u{1F1F3}"),
        ("Japanese", "ja-JP", "\u{1F1EF}\u{1F1F5}"),
        ("Korean", "ko-KR", "\u{1F1F0}\u{1F1F7}"),
        ("Portuguese", "pt-BR", "\u{1F1E7}\u{1F1F7}"),
        ("Arabic", "ar-SA", "\u{1F1F8}\u{1F1E6}"),
        ("Hindi", "hi-IN", "\u{1F1EE}\u{1F1F3}"),
        ("Italian", "it-IT", "\u{1F1EE}\u{1F1F9}"),
        ("Russian", "ru-RU", "\u{1F1F7}\u{1F1FA}"),
    ]

    private var selectedFlag: String {
        supportedLanguages.first { $0.code == selectedLanguage }?.flag ?? "\u{1F1FA}\u{1F1F8}"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    // Header — icon + title, top left; language picker top right
                    HStack {
                        Image("Recon Icon Square Small")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .cornerRadius(8)

                        Text("Recon")
                            .font(.largeTitle)
                            .bold()

                        Spacer()

                        // Language selector dropdown
                        Menu {
                            ForEach(supportedLanguages, id: \.code) { lang in
                                Button {
                                    selectedLanguage = lang.code
                                } label: {
                                    HStack {
                                        Text(lang.name)
                                        if lang.code == selectedLanguage {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(selectedFlag)
                                Text(selectedLanguage.uppercased())
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .disabled(camera.isRecording)
                        .opacity(camera.isRecording ? 0.4 : 1.0)
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)

                    HStack {
                        Text("Emergency Video Recording")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, -10)

                    Spacer()
                    Spacer()
                    Spacer()
                    Spacer()

                    // Status text
                    VStack(spacing: 6) {
                        Text(camera.isRecording ? "Recording in progress" : "Ready to record")
                            .font(.system(size: 16, weight: .medium))

                        if camera.isRecording {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text(formatTime(camera.recordingTime))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.bottom, 40)

                    // Large circular record button
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if camera.isRecording {
                                // Stop recording and analyze
                                stopAndAnalyze()
                            } else {
                                // Start recording and switch to record tab
                                camera.startRecording()
                                switchToRecord()
                            }
                        }
                    } label: {
                        ZStack {
                            // Outer ring
                            Circle()
                                .stroke(Color.red, lineWidth: 6)
                                .frame(width: 144, height: 144)
                                .background(
                                    Circle()
                                        .fill(camera.isRecording ? Color.red.opacity(0.1) : Color.red.opacity(0.05))
                                )

                            // Inner circle
                            Circle()
                                .fill(Color.red)
                                .frame(width: camera.isRecording ? 64 : 96, height: camera.isRecording ? 64 : 96)
                                .shadow(color: Color.red.opacity(0.3), radius: camera.isRecording ? 8 : 16)

                            // Video icon when not recording
                            if !camera.isRecording {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                        }
                        .opacity(camera.isReady ? 1.0 : 0.3)
                    }
                    .disabled(!camera.isReady)

                    Spacer().frame(height: 10)

                    // Helper text
                    Text(camera.isRecording
                        ? "Recording will be sent to emergency services after report analysis"
                        : "Tap the button to start recording and send an analysis to emergency services")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                        .padding(.top, 20)

                    Spacer()
                    Spacer()
                    Spacer()

                    // Status bar
                    HStack {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(camera.locationService.location != nil ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(camera.locationService.location != nil ? "Connected" : "Not Connected")
                                .font(.system(size: 14, weight: .medium))
                        }
                        Spacer()
                        Text(camera.locationService.location != nil ? "GPS Active" : "GPS Inactive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(camera.locationService.location != nil ? .green : .red)
                    }
                    .padding(16)
                    .background(camera.locationService.location != nil ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(camera.locationService.location != nil ? Color.green.opacity(0.3) : Color.red.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 16)

                    Spacer().frame(height: 10)
                }

                // Analysis progress overlay
                if showAnalysis {
                    AnalysisProgressView(viewModel: analysisVM, onDismiss: {
                        showAnalysis = false
                    }, onViewReport: {
                        showAnalysis = false
                        if let report = analysisVM.report {
                            switchToReports(report.id)
                        }
                    })
                }
            }
            .onChange(of: selectedLanguage) { _, newValue in
                camera.setTranscriptionLanguage(newValue)
            }
        }
    }

    func stopAndAnalyze() {
        camera.stopRecording { videoURL, transcript in
            guard let videoURL = videoURL else { return }

            let location = camera.locationService.location
            let latitude = location?.coordinate.latitude ?? 0
            let longitude = location?.coordinate.longitude ?? 0
            let duration = camera.recordingTime

            DispatchQueue.main.async {
                showAnalysis = true
                analysisVM.analyze(
                    videoURL: videoURL,
                    transcript: transcript,
                    latitude: latitude,
                    longitude: longitude,
                    duration: duration,
                    language: selectedLanguage
                )
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
