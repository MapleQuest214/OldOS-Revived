//
//  Messages.swift
//  OldOS
//
//  Created by Zane Kleinberg on 5/24/21.
//

import SwiftUI
import MessageUI
import Contacts

struct Messages: View {
    @State var current_nav_view: String = "Main"
    @State var forward_or_backward: Bool = false
    @State var show_compose: Bool = false
    @State var compose_recipients: [String] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.white
                VStack(spacing: 0) {
                    status_bar_in_app().frame(minHeight: 24, maxHeight: 24).zIndex(1)
                    messages_title_bar(title: "Messages", done_action: {
                        show_compose = true
                    }, show_done: true).frame(minWidth: geometry.size.width, maxWidth: geometry.size.width, minHeight: 60, maxHeight: 60).zIndex(1)

                    switch current_nav_view {
                    case "Compose":
                        messages_compose_view(
                            current_nav_view: $current_nav_view,
                            forward_or_backward: $forward_or_backward
                        )
                        .transition(AnyTransition.asymmetric(
                            insertion: .move(edge: forward_or_backward == false ? .trailing : .leading),
                            removal: .move(edge: forward_or_backward == false ? .leading : .trailing)
                        ))
                    default:
                        messages_conversation_list(
                            current_nav_view: $current_nav_view,
                            forward_or_backward: $forward_or_backward
                        )
                        .transition(AnyTransition.asymmetric(
                            insertion: .move(edge: forward_or_backward == false ? .trailing : .leading),
                            removal: .move(edge: forward_or_backward == false ? .leading : .trailing)
                        ))
                    }
                }
            }
            .compositingGroup()
            .clipped()
            .sheet(isPresented: $show_compose) {
                MessageComposeView(recipients: [], onDismiss: { show_compose = false })
            }
        }
        .onAppear { UIScrollView.appearance().bounces = true }
        .onDisappear { UIScrollView.appearance().bounces = false }
    }
}

// MARK: - Conversation List

struct messages_conversation_list: View {
    @Binding var current_nav_view: String
    @Binding var forward_or_backward: Bool
    @State var contacts: [CNContact] = []
    @State var contactsLoaded = false
    @State var contactsAccessDenied = false
    @State var searchText = ""

    var filteredContacts: [CNContact] {
        if searchText.isEmpty { return contacts }
        return contacts.filter {
            let name = CNContactFormatter.string(from: $0, style: .fullName) ?? ""
            return name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Search bar
                ZStack {
                    Color(red: 199/255, green: 203/255, blue: 212/255)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                                .font(.system(size: 14))
                            TextField("Search", text: $searchText)
                                .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .padding(.horizontal, 8)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(9)
                        .padding([.leading, .trailing], 8)
                        .padding([.top, .bottom], 6)
                    }
                }
                .frame(height: 44)

                // Open in system Messages
                Button(action: { UIApplication.shared.open(URL(string: "sms:")!) }) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(Color(red: 128/255, green: 149/255, blue: 175/255))
                            .font(.system(size: 16))
                            .frame(width: 32)
                        Text("View All Conversations in Messages")
                            .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                            .foregroundColor(Color(red: 48/255, green: 57/255, blue: 70/255))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color(red: 180/255, green: 180/255, blue: 185/255))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Color.white)
                }
                .buttonStyle(PlainButtonStyle())
                Rectangle().fill(Color(red: 171/255, green: 171/255, blue: 171/255)).frame(height: 0.5)

                if contactsAccessDenied {
                    VStack {
                        Spacer()
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 44))
                            .foregroundColor(Color(red: 210/255, green: 210/255, blue: 215/255))
                            .padding(.bottom, 8)
                        Text("Contacts Access Denied")
                            .font(.custom("Helvetica Neue Bold", fixedSize: 17))
                            .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                        Text("Enable Contacts in Settings to\nmessage people from your address book.")
                            .font(.custom("Helvetica Neue Regular", fixedSize: 13))
                            .foregroundColor(Color(red: 160/255, green: 160/255, blue: 165/255))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        Spacer()
                    }
                } else if !contactsLoaded {
                    VStack { Spacer(); ProgressView(); Spacer() }
                } else if filteredContacts.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 44))
                            .foregroundColor(Color(red: 210/255, green: 210/255, blue: 215/255))
                            .padding(.bottom, 8)
                        Text(searchText.isEmpty ? "No Contacts" : "No Results")
                            .font(.custom("Helvetica Neue Bold", fixedSize: 17))
                            .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredContacts, id: \.identifier) { contact in
                                let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                                let name = CNContactFormatter.string(from: contact, style: .fullName) ?? phone
                                Button(action: {
                                    let digits = phone.filter { "0123456789+".contains($0) }
                                    if let url = URL(string: "sms:\(digits)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 180/255, green: 191/255, blue: 205/255), Color(red: 128/255, green: 149/255, blue: 175/255)]), startPoint: .top, endPoint: .bottom))
                                                    .frame(width: 40, height: 40)
                                                Text(String(name.prefix(1)).uppercased())
                                                    .font(.custom("Helvetica Neue Bold", fixedSize: 18))
                                                    .foregroundColor(.white)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(name)
                                                    .font(.custom("Helvetica Neue Bold", fixedSize: 16))
                                                    .foregroundColor(.black)
                                                    .lineLimit(1)
                                                Text(phone)
                                                    .font(.custom("Helvetica Neue Regular", fixedSize: 13))
                                                    .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(Color(red: 180/255, green: 180/255, blue: 185/255))
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(height: 56)
                                        .background(Color.white)
                                        Rectangle().fill(Color(red: 200/255, green: 200/255, blue: 205/255))
                                            .frame(height: 0.5)
                                            .padding(.leading, 66)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadContacts() }
    }

    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { contactsAccessDenied = true; contactsLoaded = true }
                return
            }
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            do {
                var results: [CNContact] = []
                try store.enumerateContacts(with: request) { contact, _ in
                    if !contact.phoneNumbers.isEmpty { results.append(contact) }
                }
                let sorted = results.sorted {
                    let a = CNContactFormatter.string(from: $0, style: .fullName) ?? ""
                    let b = CNContactFormatter.string(from: $1, style: .fullName) ?? ""
                    return a < b
                }
                DispatchQueue.main.async { contacts = sorted; contactsLoaded = true }
            } catch {
                DispatchQueue.main.async { contactsLoaded = true }
            }
        }
    }
}

// MARK: - Compose View (new message destination inside app)

struct messages_compose_view: View {
    @Binding var current_nav_view: String
    @Binding var forward_or_backward: Bool
    @State var show_sheet = false
    @State var recipient_text = ""

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Compose title bar
                ZStack {
                    LinearGradient(gradient: Gradient(stops: [
                        .init(color: Color(red: 180/255, green: 191/255, blue: 205/255), location: 0.0),
                        .init(color: Color(red: 136/255, green: 155/255, blue: 179/255), location: 0.49),
                        .init(color: Color(red: 128/255, green: 149/255, blue: 175/255), location: 0.49),
                        .init(color: Color(red: 110/255, green: 133/255, blue: 162/255), location: 1.0)
                    ]), startPoint: .top, endPoint: .bottom)
                    .border_bottom(width: 1, edges: [.bottom], color: Color(red: 45/255, green: 48/255, blue: 51/255))
                    .innerShadowBottom(color: Color(red: 230/255, green: 230/255, blue: 230/255), radius: 0.025)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("New Message")
                                .ps_innerShadow(Color.white, radius: 0, offset: 1, angle: 180.degrees, intensity: 0.07)
                                .font(.custom("Helvetica Neue Bold", fixedSize: 22))
                                .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0.0, y: -1)
                            Spacer()
                        }
                        Spacer()
                    }
                    HStack {
                        Button(action: {
                            forward_or_backward = true
                            withAnimation(.linear(duration: 0.28)) { current_nav_view = "Main" }
                        }) {
                            ZStack {
                                Image("Button2").resizable().aspectRatio(contentMode: .fit).frame(width: 77)
                                HStack {
                                    Text("Cancel")
                                        .foregroundColor(.white)
                                        .font(.custom("Helvetica Neue Bold", fixedSize: 13))
                                        .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -0.6)
                                        .padding(.leading, 5)
                                        .offset(y: -1.1)
                                }
                            }
                        }.padding(.leading, 6)
                        Spacer()
                        Button(action: { show_sheet = true }) {
                            ZStack {
                                Image("Button2").resizable().aspectRatio(contentMode: .fit).frame(width: 77).scaleEffect(x: -1)
                                Text("Send")
                                    .foregroundColor(.white)
                                    .font(.custom("Helvetica Neue Bold", fixedSize: 13))
                                    .shadow(color: Color.black.opacity(0.45), radius: 0, x: 0, y: -0.6)
                                    .offset(y: -1.1)
                            }
                        }.padding(.trailing, 6)
                    }
                }.frame(height: 60)

                // To: field
                HStack {
                    Text("To:")
                        .font(.custom("Helvetica Neue Bold", fixedSize: 16))
                        .foregroundColor(.black)
                        .padding(.leading, 12)
                    TextField("", text: $recipient_text)
                        .font(.custom("Helvetica Neue Regular", fixedSize: 16))
                        .keyboardType(.phonePad)
                    Spacer()
                }
                .frame(height: 44)
                .background(Color.white)
                Rectangle().fill(Color(red: 171/255, green: 171/255, blue: 171/255)).frame(height: 1)

                // Tap to open Messages
                Button(action: { show_sheet = true }) {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "message.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(red: 180/255, green: 191/255, blue: 205/255))
                            Text("Tap to compose in Messages")
                                .font(.custom("Helvetica Neue Regular", fixedSize: 14))
                                .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                            Spacer()
                        }
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color(red: 239/255, green: 239/255, blue: 244/255))
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $show_sheet) {
            MessageComposeView(
                recipients: recipient_text.isEmpty ? [] : [recipient_text],
                onDismiss: { show_sheet = false }
            )
        }
    }
}

// MARK: - MFMessageComposeViewController wrapper

struct MessageComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            let alert = UIAlertController(
                title: "Messages Unavailable",
                message: "This device cannot send SMS messages.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in onDismiss() })
            return alert
        }
        let vc = MFMessageComposeViewController()
        vc.recipients = recipients
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true) { self.onDismiss() }
        }
    }
}

// MARK: - Title Bar (kept from original)

struct messages_title_bar: View {
    var title: String
    public var done_action: (() -> Void)?
    var show_done: Bool?
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color(red: 180/255, green: 191/255, blue: 205/255), location: 0.0),
                .init(color: Color(red: 136/255, green: 155/255, blue: 179/255), location: 0.49),
                .init(color: Color(red: 128/255, green: 149/255, blue: 175/255), location: 0.49),
                .init(color: Color(red: 110/255, green: 133/255, blue: 162/255), location: 1.0)
            ]), startPoint: .top, endPoint: .bottom)
            .border_bottom(width: 1, edges: [.bottom], color: Color(red: 45/255, green: 48/255, blue: 51/255))
            .innerShadowBottom(color: Color(red: 230/255, green: 230/255, blue: 230/255), radius: 0.025)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(title)
                        .ps_innerShadow(Color.white, radius: 0, offset: 1, angle: 180.degrees, intensity: 0.07)
                        .font(.custom("Helvetica Neue Bold", fixedSize: 22))
                        .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0.0, y: -1)
                        .id(title)
                    Spacer()
                }
                Spacer()
            }
            HStack {
                Spacer()
                tool_bar_rectangle_button_larger_image(
                    action: { done_action?() },
                    button_type: .blue_gray,
                    content: "compose",
                    use_image: true
                ).padding(.trailing, 5)
            }
        }
    }
}

struct Messages_Previews: PreviewProvider {
    static var previews: some View {
        Messages()
    }
}
