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
        
    }
}
