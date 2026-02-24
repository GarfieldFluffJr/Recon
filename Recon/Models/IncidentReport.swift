//
//  IncidentReport.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-24.
//

// Match the JSON the lambda server returns

import Foundation

struct IncidentReport: Codable, Identifiable {
    var id = UUID()

    // Nova analysis fields
    let incidentType: String
    let severity: String
    let confidenceLevel: String
    let locationDetails: LocationDetails
    let timeline: [TimelineEvent]
    let peopleInvolved: PeopleInvolved
    let hazardsObserved: [String]
    let transcriptHighlights: [String]
    let description: String
    let recommendedActions: [String]

    // Metadata added by Lambda
    let location: GPSLocation?
    let videoKey: String?
    let timestamp: String?
    let duration: Double?
    let transcriptSource: String?
    let parseError: Bool?

    // Local-only (not from server)
    var localVideoURL: URL?

    // Tells Swift which fields come from JSON (id and localVideoURL are local-only)
    enum CodingKeys: String, CodingKey {
        case incidentType, severity, confidenceLevel, locationDetails
        case timeline, peopleInvolved, hazardsObserved, transcriptHighlights
        case description, recommendedActions, location, videoKey
        case timestamp, duration, transcriptSource, parseError
    }

    struct LocationDetails: Codable {
        let visibleStreetNames: [String]
        let visibleBusinessNames: [String]
        let landmarks: [String]
        let intersectionDescription: String
    }

    struct TimelineEvent: Codable {
        let timestamp: String
        let event: String
    }

    struct PeopleInvolved: Codable {
        let approximateCount: String
        let visibleInjuries: [String]
        let descriptions: [String]
    }

    struct GPSLocation: Codable {
        let latitude: Double
        let longitude: Double
    }
}
