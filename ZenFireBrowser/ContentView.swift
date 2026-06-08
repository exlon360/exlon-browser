import SwiftUI

struct ContentView: View {
    @StateObject private var model = BrowserViewModel()

    var body: some View {
        BrowserShell()
            .environmentObject(model)
            .preferredColorScheme(.dark)
    }
}

private struct BrowserShell: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BrowserBackground()

                switch model.chromePlacement {
                case .left:
                    HStack(spacing: 0) {
                        SideChrome(edge: .left)
                            .frame(width: sideWidth(for: proxy))
                        BrowserContent()
                    }
                case .right:
                    HStack(spacing: 0) {
                        BrowserContent()
                        SideChrome(edge: .right)
                            .frame(width: sideWidth(for: proxy))
                    }
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
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .tint(.cyan)
    }

    private func sideWidth(for proxy: GeometryProxy) -> CGFloat {
        min(max(proxy.size.width * 0.28, 260), 340)
    }
}

private struct BrowserContent: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        ZStack {
            Color.browserCanvas

            if let tab = model.selectedTab {
                BrowserWebView(tab: tab)
                    .id(tab.id)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .top) {
                        LoadingProgress(tab: tab)
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

    var body: some View {
        GeometryReader { proxy in
            if tab.isLoading {
                Rectangle()
                    .fill(.cyan)
                    .frame(width: max(12, proxy.size.width * tab.estimatedProgress), height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeOut(duration: 0.18), value: tab.estimatedProgress)
            }
        }
        .frame(height: 2)
    }
}

private struct SideChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    let edge: HorizontalEdge

    var body: some View {
        VStack(spacing: 12) {
            ChromeHeader(compact: true)

            AddressField(style: .sidebar)

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
        .background(Color.browserChrome)
        .overlay(alignment: edge == .left ? .trailing : .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }
}

private struct HorizontalChrome: View {
    @EnvironmentObject private var model: BrowserViewModel
    let edge: VerticalEdge

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ChromeHeader(compact: false)
                AddressField(style: .bar)
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
        .background(Color.browserChrome)
        .overlay(alignment: edge == .top ? .bottom : .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct FloatingChrome: View {
    @EnvironmentObject private var model: BrowserViewModel

    var body: some View {
        VStack {
            AddressField(style: .floating)
                .padding(.top, 12)
                .padding(.horizontal, 16)

            Spacer()

            HStack(spacing: 10) {
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
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .padding(.bottom, 14)
        }
    }
}

private struct ChromeHeader: View {
    @EnvironmentObject private var model: BrowserViewModel
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            BrandMark()

            if compact == false {
                Text("ZenFire")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
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

            PlacementMenu()
        }
    }
}

private struct PlacementMenu: View {
    @EnvironmentObject private var model: BrowserViewModel

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
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityLabel("Change chrome placement")
    }
}

private enum AddressFieldStyle {
    case sidebar
    case bar
    case floating
}

private struct AddressField: View {
    @EnvironmentObject private var model: BrowserViewModel
    let style: AddressFieldStyle

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: model.selectedTab?.isPrivate == true ? "lock.shield" : "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(model.selectedTab?.isPrivate == true ? .purple : .cyan)

            TextField("Search or enter address", text: addressBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit {
                    model.submitAddress()
                }
                .foregroundStyle(.white)
                .font(.system(size: style == .sidebar ? 14 : 16, weight: .medium))

            if model.selectedTab?.isPrivate == true {
                Text("Private")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.purple.opacity(0.72), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .frame(height: style == .sidebar ? 44 : 48)
        .frame(maxWidth: style == .floating ? 640 : .infinity)
        .background(fieldBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(style == .floating ? 0.22 : 0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(style == .floating ? 0.35 : 0), radius: 18, y: 10)
    }

    private var fieldBackground: AnyShapeStyle {
        style == .floating ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.08))
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { model.selectedTab?.addressText ?? "" },
            set: { model.selectedTab?.addressText = $0 }
        )
    }
}

private struct TabSection: View {
    let title: String
    let tabs: [BrowserTab]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
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
    @ObservedObject var tab: BrowserTab
    let layout: TabPillLayout

    private var isSelected: Bool {
        model.selectedTabID == tab.id
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.select(tab)
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tab.isPrivate ? Color.purple.opacity(0.8) : Color.cyan.opacity(0.22))
                        Image(systemName: tab.isPrivate ? "theatermasks" : "globe")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tab.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if layout == .vertical {
                    Text(tab.url?.host ?? "Start")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.52))
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
            .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(width: layout == .horizontal ? 210 : nil, height: 46)
        .background(isSelected ? Color.white.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.cyan.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct FloatingTabSwitcher: View {
    @EnvironmentObject private var model: BrowserViewModel

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
            .foregroundStyle(.white)
            .background(Color.white.opacity(0.1), in: Capsule())
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
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct BrandMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.cyan, .purple, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "flame.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
    }
}

private struct BrowserBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.025, green: 0.028, blue: 0.038),
                Color(red: 0.04, green: 0.045, blue: 0.06),
                Color(red: 0.028, green: 0.035, blue: 0.055)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private extension Color {
    static let browserChrome = Color(red: 0.047, green: 0.052, blue: 0.068)
    static let browserCanvas = Color(red: 0.018, green: 0.02, blue: 0.028)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
