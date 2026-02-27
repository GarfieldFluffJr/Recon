//
//  ProfileView.swift
//  Recon
//
//  Created by Louie Yin on 2026-02-26.
//

// Profile Page — optional user info attached to reports

import SwiftUI

struct ProfileView: View {
    // Personal info
    @AppStorage("profile_fullName") private var fullName = ""
    @AppStorage("profile_age") private var age = ""
    @AppStorage("profile_email") private var email = ""
    @AppStorage("profile_phone") private var phone = ""
    @AppStorage("profile_address") private var address = ""
    @AppStorage("profile_postalCode") private var postalCode = ""
    @AppStorage("profile_city") private var city = ""
    @AppStorage("profile_state") private var state = ""
    @AppStorage("profile_country") private var country = ""

    // Trusted contact
    @AppStorage("contact_fullName") private var contactName = ""
    @AppStorage("contact_relationship") private var contactRelationship = ""
    @AppStorage("contact_email") private var contactEmail = ""
    @AppStorage("contact_phone") private var contactPhone = ""

    @AppStorage("selectedLanguage") private var selectedLanguage = "en-US"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        Text(AppStrings.get("profile.title", selectedLanguage))
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)

                    HStack {
                        (Text(AppStrings.get("profile.desc", selectedLanguage)) + Text(AppStrings.get("profile.optional", selectedLanguage)).bold() + Text("."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, -10)

                    // Personal Information
                    sectionHeader(AppStrings.get("profile.personal", selectedLanguage))

                    profileField(AppStrings.get("profile.fullName", selectedLanguage), text: $fullName)
                    profileField(AppStrings.get("profile.age", selectedLanguage), text: $age, keyboard: .numberPad)
                    profileField(AppStrings.get("profile.email", selectedLanguage), text: $email, keyboard: .emailAddress)
                    profileField(AppStrings.get("profile.phone", selectedLanguage), text: $phone, keyboard: .phonePad)
                    profileField(AppStrings.get("profile.address", selectedLanguage), text: $address)
                    profileField(AppStrings.get("profile.postal", selectedLanguage), text: $postalCode)
                    profileField(AppStrings.get("profile.city", selectedLanguage), text: $city)
                    profileField(AppStrings.get("profile.state", selectedLanguage), text: $state)
                    profileField(AppStrings.get("profile.country", selectedLanguage), text: $country)

                    // Trusted Contact
                    sectionHeader(AppStrings.get("profile.trusted", selectedLanguage))

                    profileField(AppStrings.get("profile.fullName", selectedLanguage), text: $contactName)
                    profileField(AppStrings.get("profile.relationship", selectedLanguage), text: $contactRelationship)
                    profileField(AppStrings.get("profile.email", selectedLanguage), text: $contactEmail, keyboard: .emailAddress)
                    profileField(AppStrings.get("profile.phone", selectedLanguage), text: $contactPhone, keyboard: .phonePad)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 4)
    }

    private func profileField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocorrectionDisabled()

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
