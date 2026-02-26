//
//  RecordingView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-11.
//

// Main screen - combines the camera feed and the app features

import SwiftUI
import CoreLocation

struct RecordingView: View {
    @ObservedObject var camera: CameraService
    @ObservedObject var analysisVM: AnalysisViewModel
    @State private var showAnalysis = false
    var switchToReports: (UUID?) -> Void = { _ in }

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session).ignoresSafeArea()
            VStack {
                // Recording timer at top
                if camera.isRecording {
                    Text(formatTime(camera.recordingTime))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.red.opacity(0.7))
                        .cornerRadius(8)
                        .padding(.top, 60)
                }

                Spacer()

                // Live transcript overlay
                if camera.isRecording && !camera.transcriptionService.liveTranscript.isEmpty {
                    Text(camera.transcriptionService.liveTranscript)
                        .font(.system(.body))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                Button {
                    if camera.isRecording {
                        stopAndAnalyze()
                    } else {
                        camera.startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .frame(width: 70, height: 70)

                        if camera.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 28, height: 28)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 58, height: 58)
                        }
                    }
                    .opacity(camera.isReady ? 1.0 : 0.3)
                }
                .disabled(!camera.isReady)
                .padding(.bottom, 40)
            }

            // Analysis progress overlay
            if showAnalysis {
                AnalysisProgressView(viewModel: analysisVM, onDismiss: {
                    showAnalysis = false
                    if let report = analysisVM.report {
                        switchToReports(report.id)
                    }
                })
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
                    duration: duration
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
