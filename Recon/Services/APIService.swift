//
//  APIService.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-24.
//

// Handle HTTP requests to Lambda

import Foundation

class APIService {
    
    // Get presigned upload url from Lambda
    func getUploadURL() async throws -> (uploadUrl: String, videoKey: String) {
        let url = URL(string: APIConfig.uploadURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Generate the request
        
        let (data, _) = try await URLSession.shared.data(for: request) // asynchronous request
        let response = try JSONDecoder().decode(UploadURLResponse.self, from: data) // decode the JSON response through UploadURLResponse struct into Swift object
        return (response.uploadUrl, response.videoKey)
    }
    
    // Upload video directly to S3 using presigned URL
    func uploadVideo(fileURL: URL, uploadURL: String) async throws {
        let url = URL(string: uploadURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("video/quicktime", forHTTPHeaderField: "Content-Type")
        
        let videoData = try Data(contentsOf: fileURL)
        let (_, response) = try await URLSession.shared.upload(for: request, from: videoData)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    // Call analyze with video key + transcript + GPS
    func analyzeVideo(videoKey: String, transcript: String, latitude: Double, longitude: Double, duration: Double, language: String = "en-US") async throws -> IncidentReport {
        let url = URL(string: APIConfig.analyzeURL)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300.0 // 5 minutes
        
        let body: [String: Any] = [
            "videoKey": videoKey,
            "transcript": transcript,
            "gps": ["latitude": latitude, "longitude": longitude],
            "duration": duration,
            "language": language
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let report = try JSONDecoder().decode(IncidentReport.self, from: data)
        return report
    }
    
    private struct UploadURLResponse: Codable {
        let uploadUrl: String
        let videoKey: String
    }
}
