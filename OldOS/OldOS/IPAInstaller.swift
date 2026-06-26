//
//  IPAInstaller.swift
//  OldOS
//

import SwiftUI
import UniformTypeIdentifiers
import Compression
import PureSwiftUITools

// MARK: - Model

struct IPAAppInfo {
    var displayName: String
    var bundleID: String
    var version: String
    var buildVersion: String
    var minimumOSVersion: String
    var icon: UIImage?
    var fileSize: Int64
}

// MARK: - ZIP parsing (no external library needed)

private extension Data {
    func u16LE(at i: Int) -> UInt16 {
        UInt16(self[i]) | (UInt16(self[i+1]) << 8)
    }
    func u32LE(at i: Int) -> UInt32 {
        UInt32(self[i]) | (UInt32(self[i+1]) << 8) | (UInt32(self[i+2]) << 16) | (UInt32(self[i+3]) << 24)
    }
}

private func rawDeflate(_ src: Data, outSize: Int) -> Data? {
    guard !src.isEmpty else { return nil }
    var dst = Data(count: max(outSize, src.count * 4))
    let n = src.withUnsafeBytes { s -> Int in
        guard let sp = s.baseAddress else { return 0 }
        return dst.withUnsafeMutableBytes { d -> Int in
            guard let dp = d.baseAddress else { return 0 }
            return compression_decode_buffer(
                dp.assumingMemoryBound(to: UInt8.self), dst.count,
                sp.assumingMemoryBound(to: UInt8.self), src.count,
                nil, COMPRESSION_ZLIB)
        }
    }
    return n > 0 ? dst.prefix(n) : nil
}

private func extractFromIPA(_ url: URL, predicate: (String) -> Bool) -> Data? {
    guard let zip = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
    let sig: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
    var eocd = -1
    let lo = max(0, zip.count - 65558)
    for i in stride(from: zip.count - 22, through: lo, by: -1) {
        if zip[i]==sig[0] && zip[i+1]==sig[1] && zip[i+2]==sig[2] && zip[i+3]==sig[3] { eocd = i; break }
    }
    guard eocd >= 0 else { return nil }
    let entries = Int(zip.u16LE(at: eocd + 8))
    var pos = Int(zip.u32LE(at: eocd + 16))
    let cd: [UInt8] = [0x50, 0x4B, 0x01, 0x02]
    for _ in 0..<entries {
        guard pos + 46 <= zip.count,
              zip[pos]==cd[0] && zip[pos+1]==cd[1] && zip[pos+2]==cd[2] && zip[pos+3]==cd[3] else { break }
        let comp   = Int(zip.u16LE(at: pos + 10))
        let csz    = Int(zip.u32LE(at: pos + 20))
        let usz    = Int(zip.u32LE(at: pos + 24))
        let nlen   = Int(zip.u16LE(at: pos + 28))
        let xlen   = Int(zip.u16LE(at: pos + 30))
        let clen   = Int(zip.u16LE(at: pos + 32))
        let loff   = Int(zip.u32LE(at: pos + 42))
        if pos + 46 + nlen <= zip.count {
            let nameData = zip[(pos+46)..<(pos+46+nlen)]
            let name = String(bytes: nameData, encoding: .utf8) ?? String(bytes: nameData, encoding: .isoLatin1) ?? ""
            if predicate(name) {
                let lh = loff
                guard lh + 30 <= zip.count else { break }
                let lfnlen = Int(zip.u16LE(at: lh + 26))
                let lfxlen = Int(zip.u16LE(at: lh + 28))
                let dataStart = lh + 30 + lfnlen + lfxlen
                guard dataStart + csz <= zip.count else { break }
                let chunk = Data(zip[dataStart..<dataStart+csz])
                if comp == 0 { return chunk }
                if comp == 8 { return rawDeflate(chunk, outSize: usz) }
                break
            }
        }
        pos += 46 + nlen + xlen + clen
    }
    return nil
}

func parseIPAInfo(url: URL) -> IPAAppInfo? {
    _ = url.startAccessingSecurityScopedResource()
    defer { url.stopAccessingSecurityScopedResource() }

    let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0

    // Find Info.plist path: Payload/AppName.app/Info.plist
    guard let plistData = extractFromIPA(url, predicate: { name in
        let parts = name.components(separatedBy: "/")
        return parts.count == 3 && parts[0] == "Payload" && parts[1].hasSuffix(".app") && parts[2] == "Info.plist"
    }) else { return nil }

    guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else { return nil }

    let displayName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? url.deletingPathExtension().lastPathComponent
    let bundleID    = (plist["CFBundleIdentifier"] as? String) ?? ""
    let version     = (plist["CFBundleShortVersionString"] as? String) ?? "1.0"
    let build       = (plist["CFBundleVersion"] as? String) ?? ""
    let minOS       = (plist["MinimumOSVersion"] as? String) ?? ""

    // Try to get icon — look for highest-res icon in the icons list
    var icon: UIImage? = nil
    let iconFiles = (plist["CFBundleIcons"] as? [String:Any])
                       .flatMap { $0["CFBundlePrimaryIcon"] as? [String:Any] }
                       .flatMap { $0["CFBundleIconFiles"] as? [String] }
                    ?? (plist["CFBundleIconFiles"] as? [String])
                    ?? []
    let candidates = iconFiles.flatMap { base -> [String] in
        ["\(base)@3x.png", "\(base)@2x.png", "\(base).png"]
    } + ["AppIcon60x60@3x.png", "AppIcon60x60@2x.png", "AppIcon@2x.png", "Icon-60@2x.png", "Icon@2x.png", "Icon.png"]
    for candidate in candidates {
        if let iconData = extractFromIPA(url, predicate: { name in
            let parts = name.components(separatedBy: "/")
            return parts.count == 3 && parts[0] == "Payload" && parts[1].hasSuffix(".app") && parts[2] == candidate
        }), let img = UIImage(data: iconData) {
            icon = img; break
        }
    }

    return IPAAppInfo(displayName: displayName, bundleID: bundleID, version: version,
                     buildVersion: build, minimumOSVersion: minOS, icon: icon, fileSize: fileSize)
}

// MARK: - Document Picker

struct IPADocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let vc: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
            vc = UIDocumentPickerViewController(forOpeningContentTypes: [UTType(filenameExtension: "ipa") ?? .data], asCopy: true)
        } else {
            vc = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa"], in: .import)
        }
        vc.delegate = context.coordinator
        vc.allowsMultipleSelection = false
        return vc
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: IPADocumentPicker
        init(_ p: IPADocumentPicker) { parent = p }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPick(url)
        }
    }
}

// MARK: - Home screen icon (programmatic, no asset needed)

struct ipa_installer_icon: View {
    var size: CGFloat = 60
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color(red: 0.18, green: 0.62, blue: 1.0), location: 0),
                .init(color: Color(red: 0.07, green: 0.38, blue: 0.88), location: 0.5),
                .init(color: Color(red: 0.03, green: 0.26, blue: 0.72), location: 0.5),
                .init(color: Color(red: 0.04, green: 0.30, blue: 0.76), location: 1)
            ]), startPoint: .top, endPoint: .bottom)
            VStack(spacing: size * 0.04) {
                Image(systemName: "arrow.down.circle.fill")
                    .resizable().scaledToFit()
                    .frame(width: size * 0.42)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                Text("IPA")
                    .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.4), radius: 0, x: 0, y: -0.5)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.225)
        .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
    }
}

// Home screen app button (mirrors the `app` struct but draws its icon programmatically)
struct app_ipa_installer: View {
    @Binding var current_view: String
    @Binding var apps_scale: CGFloat
    @Binding var dock_offset: CGFloat
    @Binding var folder_offset: CGFloat
    var is_folder_app: Bool = false
    var body: some View {
        Button(action: {
            if !is_folder_app {
                withAnimation(.linear(duration: 0.32)) { apps_scale = 4; dock_offset = 100 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                withAnimation(.linear(duration: 0.32)) { current_view = "IPA Installer" }
            }
        }) {
            VStack(spacing: 0) {
                ZStack {
                    ipa_installer_icon(size: UIScreen.main.bounds.width / (390/60))
                }
                .frame(width: UIScreen.main.bounds.width / (390/60), height: UIScreen.main.bounds.width / (390/60))
                Text("Installer")
                    .foregroundColor(.white)
                    .font(.custom("Helvetica Neue Medium", fixedSize: 11))
                    .shadow(color: Color.black.opacity(0.9), radius: 0.75, x: 0, y: 1.75)
                    .lineLimit(1)
            }
        }.background(Image("WallpaperIconShadow").resizable().scaledToFit()
            .frame(width: UIScreen.main.bounds.width / (390/104)).offset(y: 6))
    }
}

// MARK: - Main installer view

struct IPAInstaller: View {
    @State var selectedURL: URL? = nil
    @State var appInfo: IPAAppInfo? = nil
    @State var showDocPicker = false
    @State var showShareSheet = false
    @State var isLoading = false
    @Binding var instant_multitasking_change: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    status_bar().frame(minHeight: 24, maxHeight: 24)
                    ipa_title_bar(browse_action: { showDocPicker = true })
                        .frame(height: 60)
                    Spacer()
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Reading IPA…")
                                .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else if let info = appInfo, let url = selectedURL {
                        ScrollView(showsIndicators: false) {
                            ipa_detail_view(info: info, url: url, showShareSheet: $showShareSheet)
                                .padding()
                        }
                    } else {
                        ipa_empty_view(browse_action: { showDocPicker = true })
                    }
                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showDocPicker) {
            IPADocumentPicker { url in
                isLoading = true
                appInfo = nil
                selectedURL = url
                DispatchQueue.global(qos: .userInitiated).async {
                    let info = parseIPAInfo(url: url)
                    DispatchQueue.main.async {
                        appInfo = info
                        isLoading = false
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = selectedURL {
                ActivityShareSheet(items: [url], isPresented: $showShareSheet)
            }
        }
    }
}

// MARK: - Subviews

private struct ipa_title_bar: View {
    var browse_action: () -> Void
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(stops: [
                .init(color: Color(red: 0, green: 0, blue: 0), location: 0),
                .init(color: Color(red: 84/255, green: 84/255, blue: 84/255), location: 0.02),
                .init(color: Color(red: 59/255, green: 59/255, blue: 59/255), location: 0.04),
                .init(color: Color(red: 29/255, green: 29/255, blue: 29/255), location: 0.5),
                .init(color: Color(red: 7.5/255, green: 7.5/255, blue: 7.5/255), location: 0.51),
                .init(color: Color(red: 7.5/255, green: 7.5/255, blue: 7.5/255), location: 1)
            ]), startPoint: .top, endPoint: .bottom)
            .border_bottom(width: 1, edges: [.bottom], color: Color(red: 45/255, green: 48/255, blue: 51/255))
            .innerShadowBottom(color: Color(red: 230/255, green: 230/255, blue: 230/255), radius: 0.025)
            VStack {
                Spacer()
                Text("Installer").ps_innerShadow(Color.white, radius: 0, offset: 1, angle: 180.degrees, intensity: 0.07)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 22))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.21), radius: 0, x: 0, y: -1)
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: browse_action) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(LinearGradient(gradient: Gradient(stops: [
                                .init(color: Color(red: 120/255, green: 158/255, blue: 237/255), location: 0),
                                .init(color: Color(red: 55/255, green: 110/255, blue: 224/255), location: 0.51),
                                .init(color: Color(red: 34/255, green: 96/255, blue: 221/255), location: 0.52),
                                .init(color: Color(red: 36/255, green: 100/255, blue: 224/255), location: 1)
                            ]), startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 5)
                                .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0.08)]), startPoint: .top, endPoint: .bottom), lineWidth: 0.5))
                            .frame(width: 70, height: 30)
                        Text("Browse")
                            .font(.custom("Helvetica Neue Bold", fixedSize: 12))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.6), radius: 0, x: 0, y: -0.5)
                    }
                }.padding(.trailing, 10)
            }
        }
    }
}

private struct ipa_empty_view: View {
    var browse_action: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            ipa_installer_icon(size: 90)
            VStack(spacing: 8) {
                Text("IPA Installer")
                    .font(.custom("Helvetica Neue Bold", fixedSize: 22))
                    .foregroundColor(.white)
                Text("Select an IPA file to inspect and install it using Feather, AltStore, or TrollStore.")
                    .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button(action: browse_action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.18, green: 0.5, blue: 1), Color(red: 0.04, green: 0.3, blue: 0.82)]), startPoint: .top, endPoint: .bottom))
                    Text("Choose IPA File")
                        .font(.custom("Helvetica Neue Bold", fixedSize: 18))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: -0.5)
                }.frame(height: 50).padding(.horizontal, 40)
            }
        }
    }
}

private struct ipa_detail_view: View {
    var info: IPAAppInfo
    var url: URL
    @Binding var showShareSheet: Bool

    private func formatBytes(_ n: Int64) -> String {
        if n < 1024 { return "\(n) B" }
        if n < 1024*1024 { return String(format: "%.1f KB", Double(n)/1024) }
        return String(format: "%.1f MB", Double(n)/1024/1024)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Icon + name
            VStack(spacing: 10) {
                if let img = info.icon {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(width: 80, height: 80).cornerRadius(18)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                } else {
                    ipa_installer_icon(size: 80)
                }
                Text(info.displayName)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 24))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if !info.bundleID.isEmpty {
                    Text(info.bundleID)
                        .font(.custom("Helvetica Neue Regular", fixedSize: 13))
                        .foregroundColor(.white.opacity(0.5))
                }
            }.padding(.top, 8)

            // Info rows
            VStack(spacing: 0) {
                ipa_info_row(label: "Version", value: info.buildVersion.isEmpty ? info.version : "\(info.version) (\(info.buildVersion))")
                if !info.minimumOSVersion.isEmpty {
                    ipa_info_row(label: "Requires iOS", value: info.minimumOSVersion)
                }
                ipa_info_row(label: "File Size", value: formatBytes(info.fileSize))
                ipa_info_row(label: "File", value: url.lastPathComponent, isLast: true)
            }
            .background(Color.white.opacity(0.06))
            .cornerRadius(12)

            // Install instructions
            VStack(spacing: 8) {
                Text("To install, tap \"Open In\" and select your sideloading app:")
                    .font(.custom("Helvetica Neue Regular", fixedSize: 13))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                HStack(spacing: 16) {
                    ForEach(["Feather", "AltStore", "TrollStore"], id: \.self) { app in
                        Text(app)
                            .font(.custom("Helvetica Neue Bold", fixedSize: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }.padding(.top, 4)

            // Install button
            Button(action: { showShareSheet = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(red: 0.18, green: 0.5, blue: 1), Color(red: 0.04, green: 0.3, blue: 0.82)]), startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)]), startPoint: .top, endPoint: .bottom), lineWidth: 0.5))
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Open In…")
                            .font(.custom("Helvetica Neue Bold", fixedSize: 18))
                            .foregroundColor(.white)
                    }.shadow(color: .black.opacity(0.5), radius: 0, x: 0, y: -0.5)
                }.frame(height: 52)
            }.padding(.top, 4)

            // Try AltStore URL scheme directly
            Button(action: {
                let altstore = URL(string: "altstore://")
                if let u = altstore, UIApplication.shared.canOpenURL(u) {
                    // AltStore is installed — instruct user to use Open In
                }
                // Just open share sheet
                showShareSheet = true
            }) {
                Text("AltStore / Feather must be installed to complete installation.")
                    .font(.custom("Helvetica Neue Regular", fixedSize: 12))
                    .foregroundColor(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct ipa_info_row: View {
    var label: String
    var value: String
    var isLast: Bool = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.custom("Helvetica Neue Bold", fixedSize: 15))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.custom("Helvetica Neue Regular", fixedSize: 15))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            if !isLast {
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5).padding(.leading, 16)
            }
        }
    }
}
