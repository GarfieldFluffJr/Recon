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
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                if viewModel.isAnalyzing {
                    // State 1 - analyzing (spinner)
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text(viewModel.uploadProgress)
                        .font(.headline)
                        .foregroundColor(.white)
                } else if let error = viewModel.error {
                    // State 2 - Error (warning icon + message)
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
                    // State 3 - Analysis success (checkmark + view report button)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Analysis Complete")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button("View Report") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                }
            }
        }
    }
}
