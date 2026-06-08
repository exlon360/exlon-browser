import SwiftUI

struct ContentView: View {
    @StateObject private var model = BrowserViewModel()
    @StateObject private var theme = BrowserTheme()

    var body: some View {
        BrowserShell()
            .environmentObject(model)
            .environmentObject(theme)
            .preferredColorScheme(.dark)
    }
}

private struct BrowserShell: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BrowserBackground()

                switch model.chromePlacement {
                case .left:
                    SideBrowserLayout(edge: .left, sideWidth: sideWidth(for: proxy))
                case .right:
                    SideBrowserLayout(edge: .right, sideWidth: sideWidth(for: proxy))
                case .top:
                    VStack(spacing: 0) {
                        HorizontalChrome(edge: .top)
                        BrowserContent()
                    }
                case .bottom:
                    VStack(spacing: 0) {
                        BrowserContent()
                        HorizontalChrome(edge: .bottom)
                    }
                case .floating:
                    BrowserContent()
                    FloatingChrome()
                }

                if model.isFloatingSearchPresented {
                    FloatingSearchOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.86), value: model.isFloatingSearchPresented)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(isPresented: $model.isSettingsPresented) {
                BrowserSettingsView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isHistoryPresented) {
                BrowserHistoryView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $model.isLocalAIImporterPresented) {
                LocalAIImportView()
                    .environmentObject(model)
                    .environmentObject(theme)
                    .preferredColorScheme(.dark)
            }
        }
        .tint(theme.color(.accent))
    }

    private func sideWidth(for proxy: GeometryProxy) -> CGFloat {
        min(max(proxy.size.width * 0.3, 286), 360)
    }
}

private struct BrowserContent: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            theme.color(.canvas)

            if let tab = model.selectedTab {
                BrowserWebView(tab: tab)
                    .id(tab.id)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .top) {
                        LoadingProgress(tab: tab)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.color(.border).opacity(0.5), lineWidth: 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        AITabButton()
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    .padding(browserPadding)
            }
        }
    }

    private var browserPadding: EdgeInsets {
        model.chromePlacement == .floating
            ? EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            : EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    }
}

private struct LoadingProgress: View {
    @ObservedObject var tab: BrowserTab
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        GeometryReader { proxy in
            if tab.isLoading {
                Rectangle()
                    .fill(theme.color(.accent))
                    .frame(width: max(12, proxy.size.width * tab.estimatedProgress), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeOut(duration: 0.18), value: tab.estimatedProgress)
            }
        }
        .frame(height: 2)
    }
}

private enum SideChromeEdge {
    case left
    case right
}

private struct SideBrowserLayout: View {
    @EnvironmentObject private var model: BrowserViewModel
    let edge: SideChromeEdge
    let sideWidth: CGFloat

    var body: some View {
        ZStack(alignment: alignment) {
            HStack(spacing: 0) {
                if edge == .left {
                    if model.areSideTabsCollapsed == false {
                        SideChrome(edge: .left)
                            .frame(width: sideWidth)
                    }
                    BrowserContent()
                } else {
                    BrowserContent()
                    if model.areSideTabsCollapsed == false {
                        SideChrome(edge: .right)
                            .frame(width: sideWidth)
                    }
                }
            }

            SideTabHandle(edge: edge)
                .offset(x: handleOffset)
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.88), value: model.areSideTabsCollapsed)
    }

    private var alignment: Alignment {
        edge == .left ? .leading : .trailing
    }

    private var handleOffset: CGFloat {
        if model.areSideTabsCollapsed {
            return edge == .left ? -4 : 4
        }

        return edge == .left ? sideWidth - 14 : -(sideWidth - 14)
    }
}

private struct SideTabHandle: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: SideChromeEdge

    var body: some View {
        Button {
            model.toggleSideTabs()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14, weight: .semibold))
                Image(systemName: chevronName)
                    .font(.system(size: 13, weight: .black))
            }
            .frame(width: 30, height: 78)
            .foregroundStyle(theme.color(.text))
            .background(theme.color(.surface), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.color(.border).opacity(0.8), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.areSideTabsCollapsed ? "Show tabs" : "Hide tabs")
    }

    private var chevronName: String {
        if model.areSideTabsCollapsed {
            return edge == .left ? "chevron.right" : "chevron.left"
        }

        return edge == .left ? "chevron.left" : "chevron.right"
    }
}

private struct SideChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: SideChromeEdge

    var body: some View {
        VStack(spacing: 12) {
            ChromeHeader(compact: true)

            SearchTrigger(style: .sidebar)

            TabSection(title: "Tabs", tabs: model.normalTabs)

            if model.privateTabs.isEmpty == false {
                TabSection(title: "Private", tabs: model.privateTabs)
            }

            Spacer(minLength: 8)

            ChromeFooter()
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .padding(.horizontal, 12)
        .background(theme.color(.chrome))
        .overlay(alignment: edge == .left ? .trailing : .leading) {
            Rectangle()
                .fill(theme.color(.border).opacity(0.65))
                .frame(width: 1)
        }
    }
}

private struct HorizontalChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let edge: VerticalEdge

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ChromeHeader(compact: false)
                SearchTrigger(style: .bar)
                ChromeFooter()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.tabs) { tab in
                        TabPill(tab: tab, layout: .horizontal)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.color(.chrome))
        .overlay(alignment: edge == .top ? .bottom : .top) {
            Rectangle()
                .fill(theme.color(.border).opacity(0.65))
                .frame(height: 1)
        }
    }
}

private struct FloatingChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        VStack {
            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ChromeButton(symbol: "magnifyingglass", label: "Search") {
                        model.openFloatingSearch()
                    }

                    ChromeButton(symbol: "chevron.left", label: "Back") {
                        model.goBack()
                    }
                    .disabled(model.selectedTab?.canGoBack != true)

                    ChromeButton(symbol: "chevron.right", label: "Forward") {
                        model.goForward()
                    }
                    .disabled(model.selectedTab?.canGoForward != true)

                    FloatingTabSwitcher()

                    ChromeButton(symbol: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", label: "Reload") {
                        model.reloadOrStop()
                    }

                    ChromeButton(symbol: "clock.arrow.circlepath", label: "History") {
                        model.isHistoryPresented = true
                    }

                    ChromeButton(symbol: "gearshape", label: "Settings") {
                        model.isSettingsPresented = true
                    }
                }
                .padding(8)
            }
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.color(.border).opacity(0.75), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
    }
}

private struct ChromeHeader: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            BrandMark()

            if compact == false {
                Text("Exlon Browser")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(theme.color(.text))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            ChromeButton(symbol: "plus", label: "New Tab") {
                model.openTab()
            }

            ChromeButton(symbol: "theatermasks", label: "Private Tab") {
                model.openPrivateTab()
            }
        }
    }
}

private struct ChromeFooter: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ChromeButton(symbol: "chevron.left", label: "Back") {
                    model.goBack()
                }
                .disabled(model.selectedTab?.canGoBack != true)

                ChromeButton(symbol: "chevron.right", label: "Forward") {
                    model.goForward()
                }
                .disabled(model.selectedTab?.canGoForward != true)

                ChromeButton(symbol: model.selectedTab?.isLoading == true ? "xmark" : "arrow.clockwise", label: "Reload") {
                    model.reloadOrStop()
                }

                ChromeButton(symbol: "clock.arrow.circlepath", label: "History") {
                    model.isHistoryPresented = true
                }

                PlacementMenu()

                ChromeButton(symbol: "gearshape", label: "Settings") {
                    model.isSettingsPresented = true
                }
            }
        }
    }
}

private struct PlacementMenu: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            ForEach(BrowserChromePlacement.allCases) { placement in
                Button {
                    model.chromePlacement = placement
                } label: {
                    Label(placement.title, systemImage: placement.symbolName)
                }
            }
        } label: {
            Image(systemName: model.chromePlacement.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.color(.text))
                .background(theme.color(.field), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityLabel("Change chrome placement")
    }
}

private enum SearchTriggerStyle {
    case sidebar
    case bar
}

private struct SearchTrigger: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    let style: SearchTriggerStyle

    var body: some View {
        Button {
            model.openFloatingSearch()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(model.selectedTab?.isPrivate == true ? theme.color(.privateAccent) : theme.color(.accent))

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedTab?.url?.host ?? "Search \(model.searchEngine.title)")
                        .font(.system(size: style == .sidebar ? 13 : 15, weight: .semibold))
                        .foregroundStyle(theme.color(.text))
                        .lineLimit(1)

                    if style == .sidebar {
                        Text("Search or enter address")
                            .font(.caption2)
                            .foregroundStyle(theme.color(.mutedText))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "command")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.color(.mutedText))
            }
            .padding(.horizontal, 12)
            .frame(height: style == .sidebar ? 46 : 48)
            .background(theme.color(.field), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.color(.border).opacity(0.65), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum AddressFieldStyle {
    case floating
}

private struct AddressField: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @FocusState private var isFocused: Bool
    let style: AddressFieldStyle
    let focusOnAppear: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(model.selectedTab?.isPrivate == true ? theme.color(.privateAccent) : theme.color(.accent))

            TextField("Search \(model.searchEngine.title) or enter address", text: addressBinding)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit {
                    model.submitAddress()
                }
                .foregroundStyle(theme.color(.text))
                .font(.system(size: 18, weight: .medium))

            if model.selectedTab?.isPrivate == true {
                Text("Private")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.color(.text))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(theme.color(.privateAccent).opacity(0.72), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .frame(maxWidth: 680)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.color(.border).opacity(0.9), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.38), radius: 22, y: 12)
        .onAppear {
            if focusOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            }
        }
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.selectedTab?.addressText ?? "" },
            set: { model.selectedTab?.addressText = $0 }
        )
    }
}

private struct FloatingSearchOverlay: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    model.isFloatingSearchPresented = false
                }

            VStack(spacing: 12) {
                AddressField(style: .floating, focusOnAppear: true)

                if let tab = model.selectedTab {
                    HStack(spacing: 8) {
                        Image(systemName: tab.isPrivate ? "theatermasks" : "globe")
                        Text(tab.title)
                            .lineLimit(1)
                        Spacer()
                        Text(tab.url?.host ?? model.searchEngine.title)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.color(.mutedText))
                    .padding(.horizontal, 14)
                    .frame(maxWidth: 680)
                }
            }
            .padding(.top, 18)
            .padding(.horizontal, 16)
        }
    }
}

private struct AITabButton: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            ForEach(AIAssistant.allCases) { assistant in
                Button {
                    model.openAIShortcut(assistant)
                } label: {
                    Label(assistant.menuTitle, systemImage: assistant.symbolName)
                }
            }

            Divider()

            if model.localAIURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button {
                    model.openLocalAI()
                } label: {
                    Label(model.localAIName, systemImage: "desktopcomputer")
                }
            }

            Button {
                model.isLocalAIImporterPresented = true
            } label: {
                Label("Import Local AI", systemImage: "square.and.arrow.down")
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 38, height: 38)
                .foregroundStyle(theme.color(.text))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.65), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.25), radius: 10, y: 5)
        }
        .accessibilityLabel("AI shortcuts")
    }
}

private struct BrowserHistoryView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34, weight: .semibold))
                        Text("No history yet")
                            .font(.headline)
                    }
                    .foregroundStyle(theme.color(.mutedText))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.color(.canvas))
                } else {
                    List {
                        ForEach(model.history) { item in
                            Button {
                                model.openHistoryItem(item)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(theme.color(.text))
                                        .lineLimit(1)

                                    Text(item.urlString)
                                        .font(.caption)
                                        .foregroundStyle(theme.color(.mutedText))
                                        .lineLimit(1)

                                    Text(item.visitedAt, style: .relative)
                                        .font(.caption2)
                                        .foregroundStyle(theme.color(.mutedText))
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .listRowBackground(theme.color(.surface))
                    }
                    .scrollContentBackground(.hidden)
                    .background(theme.color(.canvas))
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") {
                        model.clearHistory()
                    }
                    .disabled(model.history.isEmpty)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LocalAIImportView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Local AI") {
                    TextField("Name", text: $name)
                    TextField("URL or host", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section {
                    Button("Import Local AI") {
                        model.importLocalAI(name: name, urlText: urlText)
                        model.openLocalAI()
                        dismiss()
                    }
                    .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Import Local AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = model.localAIName
                urlText = model.localAIURLText
            }
        }
    }
}

private struct TabSection: View {
    @EnvironmentObject private var theme: BrowserTheme
    let title: String
    let tabs: [BrowserTab]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.color(.mutedText))
                .padding(.horizontal, 4)

            ForEach(tabs) { tab in
                TabPill(tab: tab, layout: .vertical)
            }
        }
    }
}

private enum TabPillLayout {
    case vertical
    case horizontal
}

private struct TabPill: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @ObservedObject var tab: BrowserTab
    let layout: TabPillLayout

    private var isSelected: Bool {
        model.selectedTabID.map { $0 == tab.id } ?? false
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.select(tab)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tab.isPrivate ? theme.color(.privateAccent).opacity(0.82) : theme.color(.accent).opacity(0.24))
                        Image(systemName: tab.isPrivate ? "theatermasks" : "globe")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.color(.text))
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.color(.text))
                            .lineLimit(1)

                        if layout == .vertical {
                            Text(tab.url?.host ?? model.searchEngine.title)
                                .font(.caption2)
                                .foregroundStyle(theme.color(.mutedText))
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Button {
                model.close(tab)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.color(.mutedText))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: layout == .horizontal ? 210 : nil, height: 46)
        .background(isSelected ? theme.color(.surface) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.color(.accent).opacity(0.72) : theme.color(.border).opacity(0.35), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FloatingTabSwitcher: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        Menu {
            Button {
                model.openTab()
            } label: {
                Label("New Tab", systemImage: "plus")
            }

            Button {
                model.openPrivateTab()
            } label: {
                Label("New Private Tab", systemImage: "theatermasks")
            }

            Divider()

            ForEach(model.tabs) { tab in
                Button {
                    model.select(tab)
                } label: {
                    Label(tab.title, systemImage: tab.isPrivate ? "lock.shield" : "globe")
                }
            }

            Divider()

            PlacementMenuContent()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.on.square")
                Text("\(model.tabs.count)")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(height: 36)
            .padding(.horizontal, 12)
            .foregroundStyle(theme.color(.text))
            .background(theme.color(.field), in: Capsule())
        }
    }
}

private struct PlacementMenuContent: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ForEach(BrowserChromePlacement.allCases) { placement in
            Button {
                model.chromePlacement = placement
            } label: {
                Label(placement.title, systemImage: placement.symbolName)
            }
        }
    }
}

private struct ChromeButton: View {
    @EnvironmentObject private var theme: BrowserTheme
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(theme.color(.text))
                .background(theme.color(.field), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.border).opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct BrandMark: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.color(.surface))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(theme.color(.accent).opacity(0.8), lineWidth: 1)
                }
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(theme.color(.accent))
        }
        .frame(width: 36, height: 36)
    }
}

private struct BrowserBackground: View {
    @EnvironmentObject private var theme: BrowserTheme

    var body: some View {
        LinearGradient(
            colors: [
                theme.color(.canvas),
                theme.color(.chrome),
                theme.color(.canvas)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct BrowserSettingsView: View {
    @EnvironmentObject private var model: BrowserViewModel
    @EnvironmentObject private var theme: BrowserTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Browsing") {
                    Toggle("Dark Reader style pages", isOn: darkReaderBinding)
                    Toggle("Hide side tabs", isOn: $model.areSideTabsCollapsed)
                    Picker("Chrome placement", selection: $model.chromePlacement) {
                        ForEach(BrowserChromePlacement.allCases) { placement in
                            Label(placement.title, systemImage: placement.symbolName)
                                .tag(placement)
                        }
                    }
                    Picker("Search engine", selection: $model.searchEngine) {
                        ForEach(BrowserSearchEngine.allCases) { engine in
                            Text(engine.title)
                                .tag(engine)
                        }
                    }

                    if model.searchEngine == .custom {
                        TextField("Search URL with {query}", text: $model.customSearchTemplate)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                }

                Section("Local AI") {
                    TextField("Name", text: $model.localAIName)
                    TextField("URL or host", text: $model.localAIURLText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button("Import Local AI") {
                        model.isLocalAIImporterPresented = true
                    }
                }

                Section("Colors") {
                    ForEach(BrowserThemeToken.allCases) { token in
                        ColorPicker(token.title, selection: theme.binding(for: token), supportsOpacity: false)
                    }

                    Button("Reset to Zen dark defaults") {
                        theme.resetToZenDefaults()
                    }
                }

                Section("Reset") {
                    Button("Reset to default") {
                        model.resetToDefaults()
                        theme.resetToZenDefaults()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.color(.canvas))
            .foregroundStyle(theme.color(.text))
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var darkReaderBinding: Binding<Bool> {
        Binding(
            get: { model.isDarkReaderEnabled },
            set: { model.setDarkReaderEnabled($0) }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
