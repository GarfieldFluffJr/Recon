//
//  ContentView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-10.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecordingView()
                .tabItem {
                    Label("Record", systemImage: "video.fill")
                }

            ReportListView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text.fill")
                }
        }
    }
}
