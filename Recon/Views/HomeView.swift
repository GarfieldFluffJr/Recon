//
//  HomeView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-25.
//

// Homepage

import SwiftUI

struct HomeView: View {
    @State private var isRecording = false

    var body: some View {
        NavigationStack {
            VStack {
                // Header — icon + title, top left
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
                    Text(isRecording ? "Recording in progress" : "Ready to record")
                        .font(.system(size: 16, weight: .medium))

                    if isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("00:12")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.bottom, 40)

                // Large circular record button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isRecording.toggle()
                    }
                } label: {
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(isRecording ? Color.red : Color.red, lineWidth: 6)
                            .frame(width: 144, height: 144)
                            .background(
                                Circle()
                                    .fill(isRecording ? Color.red.opacity(0.1) : Color.red.opacity(0.05))
                            )

                        // Inner circle
                        Circle()
                            .fill(Color.red)
                            .frame(width: isRecording ? 64 : 96, height: isRecording ? 64 : 96)
                            .shadow(color: Color.red.opacity(0.3), radius: isRecording ? 8 : 16)

                        // Video icon when not recording
                        if !isRecording {
                            Image(systemName: "video.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }
                    }
                }

                Spacer().frame(height: 10)

                // Helper text
                Text(isRecording
                    ? "Recording is being sent to emergency services in real-time"
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
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Connected")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Spacer()
                    Text("GPS Active")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 16)

                Spacer().frame(height: 10)
            }
        }
    }
}

#Preview {
    ContentView()
}
