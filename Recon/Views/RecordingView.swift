//
//  RecordingView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-11.
//

// Main screen - combines the camera feed and the app features

import SwiftUI

struct RecordingView: View {
    @StateObject var camera = CameraService()
    
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
                
                Button {
                    if camera.isRecording {
                        camera.stopRecording()
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
        }
        .onAppear {
            camera.configure()
        }
    }

    // Format seconds into MM:SS
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
