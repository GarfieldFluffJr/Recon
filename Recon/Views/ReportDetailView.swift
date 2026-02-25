//
//  ReportDetailView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-25.
//

// Full report screen after analysis — displays all fields from Nova's report

import SwiftUI
import AVKit

struct ReportDetailView: View {
    let report: IncidentReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header — incident type + severity
                HStack {
                    Text("Category: \(report.incidentType)")
                        .font(.title2)
                        .bold()
                    Spacer()
                    Text(report.severity)
                        .font(.subheadline)
                        .bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(severityColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                // Timestamp + confidence
                HStack {
                    if let timestamp = report.timestamp {
                        Text(formatTimestamp(timestamp))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Confidence: \(report.confidenceLevel)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Video player
                if let videoURL = report.localVideoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(height: 250)
                        .cornerRadius(12)
                }

                // Description
                sectionHeader("Description")
                Text(report.description)
                    .font(.body)

                // Timeline
                sectionHeader("Timeline")
                if report.timeline.isEmpty {
                    noneText()
                } else {
                    ForEach(Array(report.timeline.enumerated()), id: \.offset) { _, event in
                        HStack(alignment: .top) {
                            Text(event.timestamp)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.orange)
                                .frame(width: 70, alignment: .leading)
                            Text(event.event)
                                .font(.body)
                        }
                    }
                }

                // People involved
                sectionHeader("People Involved (\(report.peopleInvolved.approximateCount))")
                if report.peopleInvolved.descriptions.isEmpty {
                    noneText()
                } else {
                    ForEach(report.peopleInvolved.descriptions, id: \.self) { desc in
                        bulletPoint(desc)
                    }
                }
                if !report.peopleInvolved.visibleInjuries.isEmpty {
                    Text("Injuries:")
                        .font(.subheadline)
                        .bold()
                        .padding(.top, 4)
                    ForEach(report.peopleInvolved.visibleInjuries, id: \.self) { injury in
                        bulletPoint(injury)
                    }
                }

                // Hazards
                sectionHeader("Hazards Observed")
                if report.hazardsObserved.isEmpty {
                    noneText()
                } else {
                    ForEach(report.hazardsObserved, id: \.self) { hazard in
                        bulletPoint(hazard)
                    }
                }

                // Transcript highlights
                sectionHeader("Transcript Highlights")
                if report.transcriptHighlights.isEmpty {
                    noneText()
                } else {
                    ForEach(report.transcriptHighlights, id: \.self) { quote in
                        Text("\"\(quote)\"")
                            .font(.body)
                            .italic()
                            .foregroundColor(.secondary)
                    }
                }

                // Location details
                sectionHeader("Location Details")
                if report.locationDetails.visibleStreetNames.isEmpty && report.locationDetails.landmarks.isEmpty && report.locationDetails.intersectionDescription.isEmpty {
                    noneText()
                } else {
                    ForEach(report.locationDetails.visibleStreetNames, id: \.self) { street in
                        bulletPoint(street)
                    }
                    ForEach(report.locationDetails.visibleBusinessNames, id: \.self) { business in
                        bulletPoint(business)
                    }
                    ForEach(report.locationDetails.landmarks, id: \.self) { landmark in
                        bulletPoint(landmark)
                    }
                    if !report.locationDetails.intersectionDescription.isEmpty {
                        Text(report.locationDetails.intersectionDescription)
                            .font(.body)
                    }
                }

                // Recommended actions
                sectionHeader("Recommended Actions")
                if report.recommendedActions.isEmpty {
                    noneText()
                } else {
                    ForEach(report.recommendedActions, id: \.self) { action in
                        bulletPoint(action)
                    }
                }

                // GPS coordinates
                if let location = report.location {
                    sectionHeader("GPS Coordinates")
                    Text("\(location.latitude), \(location.longitude)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Incident Report")
    }

    // Severity badge color
    private var severityColor: Color {
        switch report.severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .gray
        }
    }

    // Section header helper
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.top, 8)
    }

    // "None observed/reported" text
    private func noneText() -> some View {
        Text("None observed")
            .font(.body)
            .foregroundColor(.secondary)
            .italic()
    }

    // Bullet point helper
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
            Text(text)
                .font(.body)
        }
    }

    // Format ISO timestamp to readable string
    private func formatTimestamp(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: iso) {
            let display = DateFormatter()
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return iso
    }
}
