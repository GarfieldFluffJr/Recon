//
//  ContentView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-10.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var openReportID: UUID? = nil
    @StateObject private var camera = CameraService()
    @StateObject private var analysisVM = AnalysisViewModel()
    @AppStorage("selectedLanguage") private var selectedLanguage = "en-US"

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordingView(
                camera: camera,
                analysisVM: analysisVM,
                switchToReports: { reportID in
                    openReportID = reportID
                    selectedTab = 2
                }
            )
                .tabItem {
                    Label(AppStrings.get("tab.record", selectedLanguage), systemImage: "video.fill")
                }
                .tag(0)

            HomeView(
                camera: camera,
                analysisVM: analysisVM,
                switchToRecord: { selectedTab = 0 },
                switchToReports: { reportID in
                    openReportID = reportID
                    selectedTab = 2
                }
            )
                .tabItem {
                    Label(AppStrings.get("tab.home", selectedLanguage), systemImage: "house.fill")
                }
                .tag(1)

            ReportListView(openReportID: openReportID)
                .tabItem {
                    Label(AppStrings.get("tab.reports", selectedLanguage), systemImage: "doc.text.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label(AppStrings.get("tab.profile", selectedLanguage), systemImage: "person.fill")
                }
                .tag(3)
        }
        .onChange(of: selectedTab) {
            if selectedTab != 2 {
                openReportID = nil
            }
        }
        .onAppear {
            camera.configure()
        }
    }
}
