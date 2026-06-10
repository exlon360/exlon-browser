import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ContentView: View {
    @StateObject private var library = EmuLibrary()
    @State private var isImporterPresented = false
    @State private var isBridgeSettingsPresented = false
    @State private var filter: PackageFilter = .all

    private var filteredPackages: [EmuPackage] {
        guard let kind = filter.kind else { return library.packages }
        return library.packages.filter { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EmuBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HeroHeader(
                            isBridgeConfigured: library.isBridgeConfigured,
                            importAction: { isImporterPresented = true },
                            bridgeAction: { isBridgeSettingsPresented = true }
                        )

                        Picker("Package type", selection: $filter) {
                            ForEach(PackageFilter.allCases) { filter in
                                Text(filter.title)
                                    .tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)

                        BridgeStatusView(openAction: { isBridgeSettingsPresented = true })

                        RuntimeMatrixView(isBridgeConfigured: library.isBridgeConfigured)

                        PackageLibraryView(
                            packages: filteredPackages,
                            selectedPackageID: library.selectedPackage?.id,
                            selectAction: library.select,
                            runAction: library.run,
                            deleteAction: library.delete
                        )

                        PackageDetailView(
                            package: library.selectedPackage,
                            runAction: library.run,
                            deleteAction: library.delete
                        )

                        SessionConsoleView(
                            session: library.activeSession,
                            openAction: { library.isVMSessionPresented = true },
                            clearAction: library.clearSession
                        )

                        if library.statusMessage.isEmpty == false {
                            Text(library.statusMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 18)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Glide Emu")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isBridgeSettingsPresented = true
                    } label: {
                        Label("VM Bridge", systemImage: "network")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: EmuImportContent.supportedTypes,
                allowsMultipleSelection: true
            ) { result in
                library.importFiles(result)
            }
            .sheet(isPresented: $isBridgeSettingsPresented) {
                BridgeSettingsView()
                    .environmentObject(library)
                    .preferredColorScheme(.dark)
            }
            .fullScreenCover(isPresented: $library.isVMSessionPresented) {
                VMSessionView()
                    .environmentObject(library)
                    .preferredColorScheme(.dark)
            }
            .onOpenURL { url in
                library.importExternalURL(url)
            }
        }
        .tint(Color(red: 0.57, green: 0.86, blue: 0.74))
        .environmentObject(library)
    }
}

private enum PackageFilter: String, CaseIterable, Identifiable {
    case all
    case dmg
    case apk
    case exe
    case deb

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .dmg:
            return "DMG"
        case .apk:
            return "APK"
        case .exe:
            return "EXE"
        case .deb:
            return "DEB"
        }
    }

    var kind: EmuPackageKind? {
        switch self {
        case .all:
            return nil
        case .dmg:
            return .dmg
        case .apk:
            return .apk
        case .exe:
            return .exe
        case .deb:
            return .deb
        }
    }
}

private enum EmuImportContent {
    static var supportedTypes: [UTType] {
        [
            UTType(filenameExtension: "dmg") ?? .data,
            UTType(filenameExtension: "apk") ?? .data,
            UTType(filenameExtension: "exe") ?? .data,
            UTType(filenameExtension: "deb") ?? .data
        ]
    }
}

private struct HeroHeader: View {
    let isBridgeConfigured: Bool
    let importAction: () -> Void
    let bridgeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "cpu")
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Glide Emu")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(isBridgeConfigured ? "Scrcpy VM Bridge connected" : "Scrcpy VM Bridge needed")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                Button(action: importAction) {
                    Label("Import", systemImage: "square.and.arrow.down")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: bridgeAction) {
                    Image(systemName: isBridgeConfigured ? "network.badge.shield.half.filled" : "network")
                        .font(.system(size: 16, weight: .black))
                        .frame(width: 42, height: 36)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("VM Bridge settings")
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}

private struct BridgeStatusView: View {
    @EnvironmentObject private var library: EmuLibrary
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: library.isBridgeConfigured ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(library.isBridgeConfigured ? Color(red: 0.57, green: 0.86, blue: 0.74) : .yellow)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(library.isBridgeConfigured ? "VM Bridge" : "No VM Bridge")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(.white)

                Text(library.isBridgeConfigured ? library.bridgeURLText : "Add a scrcpy/noVNC bridge URL")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: openAction) {
                Image(systemName: "slider.horizontal.3")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Edit VM Bridge")
        }
        .padding(12)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct RuntimeMatrixView: View {
    let isBridgeConfigured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Runtime Slots")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(EmuPackageKind.importable) { kind in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: kind.symbolName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))

                            Spacer()

                            Image(systemName: isBridgeConfigured ? "bolt.horizontal.fill" : "network.slash")
                                .font(.caption.weight(.black))
                                .foregroundStyle(isBridgeConfigured ? Color(red: 0.57, green: 0.86, blue: 0.74) : .secondary)
                        }

                        Text(kind.title)
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)

                        Text(kind.runtimeName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    }
                }
            }
        }
    }
}

private struct PackageLibraryView: View {
    let packages: [EmuPackage]
    let selectedPackageID: EmuPackage.ID?
    let selectAction: (EmuPackage) -> Void
    let runAction: (EmuPackage) -> Void
    let deleteAction: (EmuPackage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Library")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(packages.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(.secondary)
            }

            if packages.isEmpty {
                EmptyLibraryView()
            } else {
                VStack(spacing: 10) {
                    ForEach(packages) { package in
                        Button {
                            selectAction(package)
                        } label: {
                            PackageRow(package: package, isSelected: selectedPackageID == package.id)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                runAction(package)
                            } label: {
                                Label("Run in VM", systemImage: "play.fill")
                            }

                            Button(role: .destructive) {
                                deleteAction(package)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct PackageRow: View {
    let package: EmuPackage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.kind.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(package.filename)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(package.kind.longTitle) - \(Self.byteString(package.byteCount))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(package.kind.title)
                .font(.caption2.weight(.black))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(Color(red: 0.57, green: 0.86, blue: 0.74), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(12)
        .background(isSelected ? Color.white.opacity(0.1) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color(red: 0.57, green: 0.86, blue: 0.74).opacity(0.68) : Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private static func byteString(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: count)
    }
}

private struct PackageDetailView: View {
    let package: EmuPackage?
    let runAction: (EmuPackage) -> Void
    let deleteAction: (EmuPackage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Package")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            if let package = package {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: package.kind.symbolName)
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(package.filename)
                                .font(.title3.weight(.black))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(package.kind.runtimeNote)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LabeledContent("Runtime") {
                        Text(package.kind.runtimeName)
                            .lineLimit(1)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                    LabeledContent("Imported") {
                        Text(package.importedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            runAction(package)
                        } label: {
                            Label("Run in VM", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        ShareLink(item: package.localURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            deleteAction(package)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 28)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Delete package")
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                }
            } else {
                Text("Import a package to select it.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

private struct SessionConsoleView: View {
    let session: EmuSession?
    let openAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VM Session")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)

                Spacer()

                if let session = session {
                    Text(session.state.title)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(Color(red: 0.57, green: 0.86, blue: 0.74), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let session = session {
                    Text(session.packageName)
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(.white)

                    ForEach(session.logLines.suffix(5), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.76))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 10) {
                        Button("Open VM", action: openAction)
                            .buttonStyle(.borderedProminent)

                        Button("Clear", action: clearAction)
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                } else {
                    Text("No session yet. Choose a package and press Run in VM.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
    }
}

private struct BridgeSettingsView: View {
    @EnvironmentObject private var library: EmuLibrary
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Scrcpy VM Bridge") {
                    TextField("http://192.168.1.10:8787", text: $library.bridgeURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    LabeledContent("Status") {
                        Text(library.isBridgeConfigured ? "Configured" : "Missing")
                            .foregroundStyle(library.isBridgeConfigured ? Color(red: 0.57, green: 0.86, blue: 0.74) : .yellow)
                    }
                }

                Section("Bridge API") {
                    Text("POST /api/sessions accepts multipart fields kind, route, filename, touch, and package. Return JSON with streamURL and touchURL.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.03, green: 0.04, blue: 0.05))
            .foregroundStyle(.white)
            .navigationTitle("VM Bridge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct VMSessionView: View {
    @EnvironmentObject private var library: EmuLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var isTouchPadExpanded = true

    var body: some View {
        ZStack {
            EmuBackground()

            VStack(spacing: 10) {
                VMHeader(
                    session: library.activeSession,
                    toggleTouchPad: { isTouchPadExpanded.toggle() },
                    closeAction: {
                        library.isVMSessionPresented = false
                        dismiss()
                    }
                )

                if let session = library.activeSession {
                    VMStreamPanel(session: session)

                    if isTouchPadExpanded {
                        VMTouchControlsView { event in
                            library.sendTouch(event)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    VMLogStrip(lines: session.logLines)
                } else {
                    EmptyVMPanel()
                }
            }
            .padding(12)
        }
    }
}

private struct VMHeader: View {
    let session: EmuSession?
    let toggleTouchPad: () -> Void
    let closeAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: session?.packageKind.symbolName ?? "display")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(session?.packageName ?? "VM Session")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session?.state.title ?? "Ready")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(action: toggleTouchPad) {
                Image(systemName: "hand.tap")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Toggle touch controls")

            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Close VM")
        }
        .padding(10)
        .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct VMStreamPanel: View {
    let session: EmuSession

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.58))

            if let streamURL = session.streamURL {
                RemoteVMWebView(url: streamURL)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if session.state == .bridgeNeeded {
                VMMessageView(
                    symbolName: "network.slash",
                    title: "Bridge Needed",
                    message: "Set the VM Bridge URL, then run the package again."
                )
            } else {
                VMMessageView(
                    symbolName: "hourglass",
                    title: "Connecting",
                    message: "Waiting for the VM bridge to return a stream."
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 260, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct VMTouchControlsView: View {
    let sendEvent: (EmuTouchEvent) -> Void

    var body: some View {
        VStack(spacing: 10) {
            TouchPadView(sendEvent: sendEvent)
                .frame(height: 150)

            HStack(spacing: 8) {
                TouchCommandButton(title: "Back", symbolName: "chevron.left") {
                    sendEvent(.key("back"))
                }
                TouchCommandButton(title: "Home", symbolName: "house") {
                    sendEvent(.key("home"))
                }
                TouchCommandButton(title: "Menu", symbolName: "line.3.horizontal") {
                    sendEvent(.key("menu"))
                }
                TouchCommandButton(title: "Keys", symbolName: "keyboard") {
                    sendEvent(.key("keyboard"))
                }
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
    }
}

private struct TouchPadView: View {
    let sendEvent: (EmuTouchEvent) -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.055))

                VStack(spacing: 6) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))

                    Text("Touch Surface")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onEnded { value in
                        let normalized = normalizedPoint(value.location, size: proxy.size)
                        let dx = Double(value.translation.width / max(proxy.size.width, 1))
                        let dy = Double(value.translation.height / max(proxy.size.height, 1))

                        if abs(value.translation.width) < 8 && abs(value.translation.height) < 8 {
                            sendEvent(.tap(x: normalized.x, y: normalized.y))
                        } else {
                            sendEvent(.drag(x: normalized.x, y: normalized.y, dx: dx, dy: dy))
                        }
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onEnded { scale in
                        sendEvent(.pinch(scale: Double(scale)))
                    }
            )
        }
    }

    private func normalizedPoint(_ point: CGPoint, size: CGSize) -> (x: Double, y: Double) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let x = min(max(point.x / width, 0), 1)
        let y = min(max(point.y / height, 0), 1)
        return (Double(x), Double(y))
    }
}

private struct TouchCommandButton: View {
    let title: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.caption.weight(.black))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.bordered)
    }
}

private struct VMLogStrip: View {
    let lines: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(lines.suffix(4), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }
        }
    }
}

private struct VMMessageView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))

            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(.white)

            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
}

private struct EmptyVMPanel: View {
    var body: some View {
        VMMessageView(
            symbolName: "display.trianglebadge.exclamationmark",
            title: "No Session",
            message: "Open a package from the library."
        )
    }
}

private struct RemoteVMWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastURL != url else { return }
        context.coordinator.lastURL = url
        webView.load(URLRequest(url: url))
    }

    final class Coordinator {
        var lastURL: URL?
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color(red: 0.57, green: 0.86, blue: 0.74))

            Text("No imported packages")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            Text("Use Import or open a supported file from Files into Glide Emu.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct EmuBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.05),
                Color(red: 0.08, green: 0.1, blue: 0.11),
                Color(red: 0.02, green: 0.025, blue: 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
