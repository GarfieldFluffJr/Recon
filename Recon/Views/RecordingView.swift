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
                Spacer()
                // Push button to bottom of screen
                
                Button {
                    if camera.isRecording {
                        camera.stopRecording()
                    } else {
                        camera.startRecording()
                    }
                } label: {
                    Circle()
                        .fill(camera.isRecording ? Color.red : Color.white)
                        .frame(width: 70, height: 70)
                        .overlay(Circle().stroke(Color.white, lineWidth: 3))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.configure()
        }
    }
}
