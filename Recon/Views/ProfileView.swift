//
//  ProfileView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-26.
//

// Profile Page

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text("Profile")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 60)

                HStack {
                    Text("Provide supplementary information to your reports. Complete the fields you consent on sharing.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, -10)

                Spacer()
            }
        }
    }
}

#Preview {
    ContentView()
}
