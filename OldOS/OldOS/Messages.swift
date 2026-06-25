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

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Search bar (iOS 4 style)
                ZStack {
                    Color(red: 199/255, green: 203/255, blue: 212/255)
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                                .font(.system(size: 14))
                            Text("Search")
                                .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                                .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(9)
                        .padding([.leading, .trailing], 8)
                        .padding([.top, .bottom], 6)
                    }
                }
                .frame(height: 44)

                // Empty state — iOS 4 didn't expose SMS database via public API
                // Show a prompt to start a new conversation
                VStack {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 54))
                        .foregroundColor(Color(red: 210/255, green: 210/255, blue: 215/255))
                        .padding(.bottom, 12)
                    Text("No Messages")
                        .font(.custom("Helvetica Neue Bold", fixedSize: 20))
                        .foregroundColor(Color(red: 128/255, green: 128/255, blue: 128/255))
                    Text("Tap the compose button to\nstart a new conversation.")
                        .font(.custom("Helvetica Neue Regular", fixedSize: 14))
                        .foregroundColor(Color(red: 160/255, green: 160/255, blue: 165/255))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(width: geometry.size.width)
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
