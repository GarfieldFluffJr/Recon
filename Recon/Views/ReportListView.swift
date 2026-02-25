//
//  ReportListView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-25.
//

// A scrollable list of all saved reports

import SwiftUI

struct ReportListView: View {
    @State private var reports: [IncidentReport] = []
    private let storageService = ReportStorageService()

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No reports yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Record a video and analyze it to create a report")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(reports) { report in
                            NavigationLink(destination: ReportDetailView(report: report)) {
                                reportRow(report)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                storageService.delete(report: reports[index])
                            }
                            reports.remove(atOffsets: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("Reports")
            .onAppear {
                reports = storageService.loadAll()
            }
        }
    }

    private func reportRow(_ report: IncidentReport) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Category: \(report.incidentType)")
                    .font(.headline)
                if let timestamp = report.timestamp {
                    Text(formatTimestamp(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(report.severity)
                .font(.caption)
                .bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severityColor(report.severity))
                .foregroundColor(.white)
                .cornerRadius(6)
        }
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .gray
        }
    }

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
