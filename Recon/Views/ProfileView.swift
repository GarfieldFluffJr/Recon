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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Profile")
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 60)

                    HStack {
                        (Text("Provide supplementary information to your reports. Complete the fields you consent on sharing.\nAll fields are ") + Text("optional").bold() + Text("."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, -10)

                    // Personal Information
                    sectionHeader("Personal Information")

                    profileField("Full Name", text: $fullName)
                    profileField("Age", text: $age, keyboard: .numberPad)
                    profileField("Email", text: $email, keyboard: .emailAddress)
                    profileField("Phone Number", text: $phone, keyboard: .phonePad)
                    profileField("Address", text: $address)
                    profileField("Postal Code", text: $postalCode)
                    profileField("City", text: $city)
                    profileField("State / Province", text: $state)
                    profileField("Country", text: $country)

                    // Trusted Contact
                    sectionHeader("Trusted Contact")

                    profileField("Full Name", text: $contactName)
                    profileField("Relationship", text: $contactRelationship)
                    profileField("Email", text: $contactEmail, keyboard: .emailAddress)
                    profileField("Phone Number", text: $contactPhone, keyboard: .phonePad)

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
