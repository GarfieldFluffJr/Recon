//
//  ContentView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var openReportID: UUID? = nil

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView(switchToReports: { reportID in
                openReportID = reportID
                selectedTab = 1
            })
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }
                .tag(0)

            ReportListView(openReportID: openReportID)
                .tabItem {
                    Label("Reports", systemImage: "doc.text.fill")
                }
                .tag(1)
        }
        .onChange(of: selectedTab) {
            // Clear the auto-open ID when switching away from reports
            if selectedTab != 1 {
                openReportID = nil
            }
        }
    }
}
