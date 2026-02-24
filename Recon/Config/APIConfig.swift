//
//  APIConfig.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-24.
//

import Foundation

enum APIConfig {
    // AWS API Gateway
    static let baseURL = "https://wfpzuuwq09.execute-api.us-east-1.amazonaws.com"
    // http paths
    static let uploadURL = "\(baseURL)/upload-url"
    static let analyzeURL = "\(baseURL)/analyze"
}
