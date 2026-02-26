//
//  AnalysisProgressView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-25.
//

// Overlay that appears once recording is done, which displays the loading screen with processing messages

import SwiftUI

struct AnalysisProgressView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    var onDismiss: () -> Void
    var onViewReport: () -> Void

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Background — tappable to dismiss when not analyzing
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .allowsHitTesting(!viewModel.isAnalyzing)
                    .onTapGesture {
                        onDismiss()
                    }

                VStack(spacing: 24) {
                    if viewModel.isAnalyzing {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text(viewModel.uploadProgress)
                            .font(.headline)
                            .foregroundColor(.white)
                    } else if let error = viewModel.error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.yellow)

                        Text("Analysis Failed")
                            .font(.headline)
                            .foregroundColor(.white)

                        Text(error)
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button("Dismiss") {
                            onDismiss()
                        }
                        .foregroundColor(.white)
                        .padding()
                    } else if viewModel.report != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.green)

                        Text("Analysis Complete")
                            .font(.headline)
                            .foregroundColor(.white)

                        Button {
                            onViewReport()
                        } label: {
                            Text("View Report")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }
}
