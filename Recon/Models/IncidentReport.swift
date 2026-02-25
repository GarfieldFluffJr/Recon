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

    // Local video file name (saved to JSON so we can find the video later)
    var localVideoFileName: String?

    // Computed property — builds the full URL from the file name
    var localVideoURL: URL? {
        guard let fileName = localVideoFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(fileName)
    }

    enum CodingKeys: String, CodingKey {
        case id, incidentType, severity, confidenceLevel, locationDetails
        case timeline, peopleInvolved, hazardsObserved, transcriptHighlights
        case description, recommendedActions, location, videoKey
        case timestamp, duration, transcriptSource, parseError
        case localVideoFileName
    }

    // Custom decoder — id defaults to new UUID if not in JSON (from Lambda)
    // Uses saved id when loading from disk
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        incidentType = try container.decode(String.self, forKey: .incidentType)
        severity = try container.decode(String.self, forKey: .severity)
        confidenceLevel = try container.decode(String.self, forKey: .confidenceLevel)
        locationDetails = try container.decode(LocationDetails.self, forKey: .locationDetails)
        timeline = try container.decode([TimelineEvent].self, forKey: .timeline)
        peopleInvolved = try container.decode(PeopleInvolved.self, forKey: .peopleInvolved)
        hazardsObserved = try container.decode([String].self, forKey: .hazardsObserved)
        transcriptHighlights = try container.decode([String].self, forKey: .transcriptHighlights)
        description = try container.decode(String.self, forKey: .description)
        recommendedActions = try container.decode([String].self, forKey: .recommendedActions)
        location = try? container.decode(GPSLocation.self, forKey: .location)
        videoKey = try? container.decode(String.self, forKey: .videoKey)
        timestamp = try? container.decode(String.self, forKey: .timestamp)
        duration = try? container.decode(Double.self, forKey: .duration)
        transcriptSource = try? container.decode(String.self, forKey: .transcriptSource)
        parseError = try? container.decode(Bool.self, forKey: .parseError)
        localVideoFileName = try? container.decode(String.self, forKey: .localVideoFileName)
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
