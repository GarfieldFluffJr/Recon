//
//  AnalysisViewModel.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-24.
//

// Controller that initiates analysis pipeline + loading screen message

import Foundation
import Combine

class AnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var uploadProgress = ""
    @Published var report: IncidentReport?
    @Published var error: String?
    
    private let apiService = APIService()
    private let storageService = ReportStorageService()
    
    func analyze(videoURL: URL, transcript: String, latitude: Double, longitude: Double, duration: Double) {
        isAnalyzing = true
        error = nil
        uploadProgress = "Getting upload URL..."
        
        // Launch an async block
        Task {
            do {
                // Get presigned URL
                let (uploadURL, videoKey) = try await apiService.getUploadURL()
                
                // DispatchQueue.main.async for async await code (shift back to synchronous code)
                await MainActor.run {
                    uploadProgress = "Uploading video..."
                }
                
                // Upload video to S3
                try await apiService.uploadVideo(fileURL: videoURL, uploadURL: uploadURL)
                
                await MainActor.run {
                    uploadProgress = "Analyzing with Nova..."
                }
                
                // Analyze with Nova 2 Lite
                var report = try await apiService.analyzeVideo(videoKey: videoKey, transcript: transcript, latitude: latitude, longitude: longitude, duration: duration)
                // Attach local video file name so user can replay with the report
                report.localVideoFileName = videoURL.lastPathComponent
                
                // Save report locally
                storageService.save(report: report)
                
                await MainActor.run {
                    self.report = report
                    self.isAnalyzing = false
                    self.uploadProgress = ""
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isAnalyzing = false
                    self.uploadProgress = ""
                }
            }
        }
    }
}
