import Combine
import AVFoundation
import CoreGraphics
import Foundation
import SwiftUI
import UIKit

enum BrowserChromePlacement: String, CaseIterable, Identifiable {
    case top
    case bottom
    case left
    case right
    case floating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .floating:
            return "Floating"
        }
    }

    var symbolName: String {
        switch self {
        case .top:
            return "rectangle.topthird.inset.filled"
        case .bottom:
            return "rectangle.bottomthird.inset.filled"
        case .left:
            return "sidebar.left"
        case .right:
            return "sidebar.right"
        case .floating:
            return "rectangle.center.inset.filled"
        }
    }
}

enum BrowserToolbarAction: String, CaseIterable, Identifiable {
    case back
    case forward
    case reload
    case tabFinder
    case closeAllTabs
    case containedTabs
    case downloadCurrent
    case history
    case downloads
    case browserMusic
    case placement
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .back:
            return "Back"
        case .forward:
            return "Forward"
        case .reload:
            return "Reload / Stop"
        case .tabFinder:
            return "Tab Finder"
        case .closeAllTabs:
            return "Close All Tabs"
        case .containedTabs:
            return "Contained Tabs"
        case .downloadCurrent:
            return "Download Current Tab"
        case .history:
            return "History"
        case .downloads:
            return "Downloads"
        case .browserMusic:
            return "Browser Music"
        case .placement:
            return "Chrome Placement"
        case .settings:
            return "Settings"
        }
    }

    var menuTitle: String {
        switch self {
        case .downloadCurrent:
            return "Download Current Tab"
        case .reload:
            return "Reload / Stop"
        default:
            return title
        }
    }

    var symbolName: String {
        switch self {
        case .back:
            return "chevron.left"
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .closeAllTabs:
            return "xmark.square"
        case .containedTabs:
            return "rectangle.on.rectangle"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .history:
            return "clock.arrow.circlepath"
        case .downloads:
            return "arrow.down.circle"
        case .browserMusic:
            return "music.note"
        case .placement:
            return "rectangle.split.2x1"
        case .settings:
            return "gearshape"
        }
    }
}

enum BrowserCustomIconSlot: String, CaseIterable, Identifiable {
    case brand
    case search
    case go
    case newTab
    case normalTab
    case privateTab
    case containedTabs
    case essentials
    case ai
    case more
    case back
    case forward
    case reload
    case tabFinder
    case closeAllTabs
    case downloadCurrent
    case downloads
    case history
    case browserMusic
    case placement
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brand:
            return "Brand"
        case .search:
            return "Search"
        case .go:
            return "Go"
        case .newTab:
            return "New Tab"
        case .normalTab:
            return "Normal Tab"
        case .privateTab:
            return "Private Tab"
        case .containedTabs:
            return "Contained Tabs"
        case .essentials:
            return "Essentials"
        case .ai:
            return "AI"
        case .more:
            return "More"
        case .back:
            return "Back"
        case .forward:
            return "Forward"
        case .reload:
            return "Reload"
        case .tabFinder:
            return "Tab Finder"
        case .closeAllTabs:
            return "Close All Tabs"
        case .downloadCurrent:
            return "Download Current"
        case .downloads:
            return "Downloads"
        case .history:
            return "History"
        case .browserMusic:
            return "Browser Music"
        case .placement:
            return "Placement"
        case .settings:
            return "Settings"
        }
    }

    var defaultSymbol: String {
        switch self {
        case .brand:
            return "globe"
        case .search:
            return "magnifyingglass"
        case .go:
            return "arrow.up.circle.fill"
        case .newTab:
            return "plus.circle.fill"
        case .normalTab:
            return "globe"
        case .privateTab:
            return "theatermasks"
        case .containedTabs:
            return "rectangle.on.rectangle"
        case .essentials:
            return "sparkle"
        case .ai:
            return "sparkles"
        case .more:
            return "ellipsis"
        case .back:
            return "chevron.left"
        case .forward:
            return "chevron.right"
        case .reload:
            return "arrow.clockwise"
        case .tabFinder:
            return "square.grid.2x2"
        case .closeAllTabs:
            return "xmark.square"
        case .downloadCurrent:
            return "arrow.down.doc"
        case .downloads:
            return "arrow.down.circle"
        case .history:
            return "clock.arrow.circlepath"
        case .browserMusic:
            return "music.note"
        case .placement:
            return "rectangle.split.2x1"
        case .settings:
            return "gearshape"
        }
    }
}

enum BrowserTopSearchBarPlacement: String, CaseIterable, Identifiable {
    case top
    case center
    case bottom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .top:
            return "Top"
        case .center:
            return "Center"
        case .bottom:
            return "Bottom"
        }
    }

    var symbolName: String {
        switch self {
        case .top:
            return "rectangle.topthird.inset.filled"
        case .center:
            return "rectangle.center.inset.filled"
        case .bottom:
            return "rectangle.bottomthird.inset.filled"
        }
    }
}

enum BrowserPrivateModeAuthAction: Equatable {
    case enter
    case exit

    var title: String {
        switch self {
        case .enter:
            return "Unlock Private Mode"
        case .exit:
            return "Close Private Mode"
        }
    }

    var prompt: String {
        switch self {
        case .enter:
            return "Enter your Glide PIN to hide normal tabs and open Private Mode."
        case .exit:
            return "Close Private Mode and hide private tabs until Private Mode is unlocked again."
        }
    }

    var buttonTitle: String {
        switch self {
        case .enter:
            return "Enter Private Mode"
        case .exit:
            return "Close Private Mode"
        }
    }
}

enum BrowserAddOnLibrary: String, CaseIterable, Identifiable {
    case firefox
    case brave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firefox:
            return "Firefox Add-ons"
        case .brave:
            return "Brave Add-ons"
        }
    }

    var subtitle: String {
        switch self {
        case .firefox:
            return "Browse Mozilla's extension and theme library."
        case .brave:
            return "Browse the Chrome Web Store used by Brave desktop."
        }
    }

    var symbolName: String {
        switch self {
        case .firefox:
            return "flame"
        case .brave:
            return "shield.lefthalf.filled"
        }
    }

    var url: URL {
        switch self {
        case .firefox:
            return URL(string: "https://addons.mozilla.org/firefox/")!
        case .brave:
            return URL(string: "https://chromewebstore.google.com/category/extensions")!
        }
    }
}

extension BrowserToolbarAction {
    var customIconSlot: BrowserCustomIconSlot {
        switch self {
        case .back:
            return .back
        case .forward:
            return .forward
        case .reload:
            return .reload
        case .tabFinder:
            return .tabFinder
        case .closeAllTabs:
            return .closeAllTabs
        case .containedTabs:
            return .containedTabs
        case .downloadCurrent:
            return .downloadCurrent
        case .history:
            return .history
        case .downloads:
            return .downloads
        case .browserMusic:
            return .browserMusic
        case .placement:
            return .placement
        case .settings:
            return .settings
        }
    }
}

final class BrowserMusicPlayer {
    private struct Parameters {
        var baseFrequency: Double
        var harmonyRatio: Double
        var shimmerFrequency: Double
        var pulseSpeed: Double
        var noiseLevel: Float
        var toneLevel: Float
        var shimmerLevel: Float
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private var sampleTime = 0.0
    private var noiseSeed: UInt64 = 0x1234ABCD
    private var filteredNoise: Float = 0
    private var currentTrack: BrowserMusicTrack = .focus
    private var currentVolume: Float = 0.32
    private var parameters = Parameters(
        baseFrequency: 92,
        harmonyRatio: 1.5,
        shimmerFrequency: 440,
        pulseSpeed: 0.07,
        noiseLevel: 0.01,
        toneLevel: 0.18,
        shimmerLevel: 0.015
    )

    deinit {
        stop()
    }

    func update(isEnabled: Bool, track: BrowserMusicTrack, volume: Double) {
        currentVolume = Float(max(0, min(1, volume)))
        engine.mainMixerNode.outputVolume = currentVolume

        if track != currentTrack || sourceNode == nil {
            let wasRunning = engine.isRunning
            stopEngineOnly()
            currentTrack = track
            parameters = Self.parameters(for: track)
            configureSourceNode()
            if wasRunning || isEnabled {
                start()
            }
            return
        }

        if isEnabled {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        stopEngineOnly()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func start() {
        if sourceNode == nil {
            configureSourceNode()
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if engine.isRunning == false {
                engine.prepare()
                try engine.start()
            }
        } catch {
            stopEngineOnly()
        }
    }

    private func stopEngineOnly() {
        if engine.isRunning {
            engine.stop()
        }

        if let sourceNode {
            engine.disconnectNodeOutput(sourceNode)
            engine.detach(sourceNode)
        }

        sourceNode = nil
    }

    private func configureSourceNode() {
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        sampleTime = 0
        filteredNoise = 0

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            self.render(frameCount: frameCount, audioBufferList: audioBufferList, sampleRate: sampleRate)
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = currentVolume
        sourceNode = node
    }

    private func render(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>,
        sampleRate: Double
    ) {
        let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let frameTotal = Int(frameCount)
        let twoPi = Double.pi * 2

        for frame in 0..<frameTotal {
            let time = sampleTime / sampleRate
            let pulse = 0.55 + 0.45 * sin(twoPi * parameters.pulseSpeed * time)
            let fundamental = sin(twoPi * parameters.baseFrequency * time)
            let harmony = sin(twoPi * parameters.baseFrequency * parameters.harmonyRatio * time + 0.4)
            let sub = sin(twoPi * parameters.baseFrequency * 0.5 * time + 1.2)
            let shimmerMod = sin(twoPi * 0.045 * time) * 0.8
            let shimmer = sin(twoPi * parameters.shimmerFrequency * time + shimmerMod)

            noiseSeed = noiseSeed &* 2862933555777941757 &+ 3037000493
            let white = Float(Double(noiseSeed & 0xFFFF) / 32768.0 - 1.0)
            filteredNoise = filteredNoise * 0.985 + white * 0.015

            let tone = Float((fundamental * 0.52 + harmony * 0.32 + sub * 0.16) * pulse)
            let mixed = tone * parameters.toneLevel +
                Float(shimmer) * parameters.shimmerLevel +
                filteredNoise * parameters.noiseLevel
            let sample = max(-0.8, min(0.8, mixed))

            for bufferIndex in 0..<buffers.count {
                guard let data = buffers[bufferIndex].mData else { continue }
                let samples = data.bindMemory(to: Float.self, capacity: frameTotal)
                samples[frame] = bufferIndex == 0 ? sample : sample * 0.92
            }

            sampleTime += 1
        }
    }

    private static func parameters(for track: BrowserMusicTrack) -> Parameters {
        switch track {
        case .focus:
            return Parameters(
                baseFrequency: 96,
                harmonyRatio: 1.5,
                shimmerFrequency: 384,
                pulseSpeed: 0.08,
                noiseLevel: 0.006,
                toneLevel: 0.18,
                shimmerLevel: 0.012
            )
        case .rain:
            return Parameters(
                baseFrequency: 74,
                harmonyRatio: 1.33,
                shimmerFrequency: 296,
                pulseSpeed: 0.045,
                noiseLevel: 0.052,
                toneLevel: 0.09,
                shimmerLevel: 0.006
            )
        case .midnight:
            return Parameters(
                baseFrequency: 58,
                harmonyRatio: 2.0,
                shimmerFrequency: 232,
                pulseSpeed: 0.032,
                noiseLevel: 0.012,
                toneLevel: 0.22,
                shimmerLevel: 0.018
            )
        case .drift:
            return Parameters(
                baseFrequency: 112,
                harmonyRatio: 1.25,
                shimmerFrequency: 512,
                pulseSpeed: 0.055,
                noiseLevel: 0.01,
                toneLevel: 0.12,
                shimmerLevel: 0.026
            )
        }
    }
}

@MainActor
final class BrowserViewModel: ObservableObject {
    static let minimumForcedFPS = 15.0
    static let maximumFiniteForcedFPS = 240.0
    static let infiniteForcedFPSValue = 241.0

    @Published var tabs: [BrowserTab]
    @Published var selectedTabID: BrowserTab.ID?
    @Published var containedTabs: [BrowserTab] = []
    @Published var selectedContainedTabID: BrowserTab.ID?
    @Published var isContainedBrowserPresented = false
    @Published var chromePlacement: BrowserChromePlacement {
        didSet {
            vault.save(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        }
    }
    @Published var isFloatingSearchPresented = false
    @Published var floatingSearchText = ""
    @Published var shouldSelectFloatingSearchText = false
    @Published var isTabFinderPresented = false
    @Published var isSettingsPresented = false
    @Published var isHistoryPresented = false
    @Published var isDownloadsPresented = false
    @Published var isVPNPresented = false
    @Published var isAddOnsPresented = false
    @Published var isAdvancedConfigPresented = false
    @Published var isCustomIconsPresented = false
    @Published var isPrivateModeEnabled = false
    @Published var isPrivateModeAuthPresented = false
    @Published var isCloseAllTabsWarningPresented = false
    @Published var privateModeAuthAction: BrowserPrivateModeAuthAction = .enter
    @Published var privateModeAuthMessage = ""
    @Published var isWebFileImporterPresented = false
    @Published var allowsMultipleWebFileImport = false
    @Published var isLocalAIImporterPresented = false
    @Published var isTutorialPresented: Bool
    @Published var isDarkReaderEnabled: Bool
    @Published var darkReaderTheme: BrowserDarkReaderTheme {
        didSet {
            vault.save(darkReaderTheme.rawValue, forKey: Self.StorageKey.darkReaderTheme)
            for tab in tabs {
                tab.setDarkReaderTheme(darkReaderTheme)
            }
            for tab in containedTabs {
                tab.setDarkReaderTheme(darkReaderTheme)
            }
        }
    }
    @Published var isStylusCatppuccinEnabled: Bool {
        didSet {
            vault.save(isStylusCatppuccinEnabled, forKey: Self.StorageKey.stylusCatppuccinEnabled)
            for tab in tabs {
                tab.setStylusCatppuccinEnabled(isStylusCatppuccinEnabled)
            }
            for tab in containedTabs {
                tab.setStylusCatppuccinEnabled(isStylusCatppuccinEnabled)
            }
        }
    }
    @Published var isFPSForcerEnabled: Bool {
        didSet {
            vault.save(isFPSForcerEnabled, forKey: Self.StorageKey.fpsForcerEnabled)
            for tab in tabs {
                tab.setFPSForcerEnabled(isFPSForcerEnabled)
            }
            for tab in containedTabs {
                tab.setFPSForcerEnabled(isFPSForcerEnabled)
            }
        }
    }
    @Published var forcedFPS: Double {
        didSet {
            let clamped = Self.clampedForcedFPS(forcedFPS)
            if clamped != forcedFPS {
                forcedFPS = clamped
                return
            }
            vault.save(forcedFPS, forKey: Self.StorageKey.forcedFPS)
            for tab in tabs {
                tab.setForcedFPS(forcedFPS)
            }
            for tab in containedTabs {
                tab.setForcedFPS(forcedFPS)
            }
        }
    }
    @Published var isAdBlockerEnabled: Bool
    @Published var isBrowserMusicEnabled: Bool {
        didSet {
            vault.save(isBrowserMusicEnabled, forKey: Self.StorageKey.browserMusicEnabled)
            updateBrowserMusicPlayer()
        }
    }
    @Published var browserMusicTrack: BrowserMusicTrack {
        didSet {
            vault.save(browserMusicTrack.rawValue, forKey: Self.StorageKey.browserMusicTrack)
            updateBrowserMusicPlayer()
        }
    }
    @Published var browserMusicVolume: Double {
        didSet {
            let clamped = Self.clampedUnit(browserMusicVolume)
            if clamped != browserMusicVolume {
                browserMusicVolume = clamped
                return
            }
            vault.save(browserMusicVolume, forKey: Self.StorageKey.browserMusicVolume)
            updateBrowserMusicPlayer()
        }
    }
    @Published var newTabOpensSearch: Bool {
        didSet {
            vault.save(newTabOpensSearch, forKey: Self.StorageKey.newTabOpensSearch)
        }
    }
    @Published var isTopSearchBarEnabled: Bool {
        didSet {
            vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        }
    }
    @Published var topSearchBarPlacement: BrowserTopSearchBarPlacement {
        didSet {
            vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        }
    }
    @Published var topSearchBarPositionX: Double {
        didSet {
            let clamped = Self.clampedUnit(topSearchBarPositionX)
            if clamped != topSearchBarPositionX {
                topSearchBarPositionX = clamped
                return
            }
            vault.save(topSearchBarPositionX, forKey: Self.StorageKey.topSearchBarPositionX)
        }
    }
    @Published var topSearchBarPositionY: Double {
        didSet {
            let clamped = Self.clampedUnit(topSearchBarPositionY)
            if clamped != topSearchBarPositionY {
                topSearchBarPositionY = clamped
                return
            }
            vault.save(topSearchBarPositionY, forKey: Self.StorageKey.topSearchBarPositionY)
        }
    }
    @Published var isTopSearchBarMoveMode = false
    @Published var topSearchBarDraftX = 0.5
    @Published var topSearchBarDraftY = 0.0
    @Published var areSideTabsCollapsed: Bool {
        didSet {
            vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        }
    }
    @Published var searchEngine: BrowserSearchEngine {
        didSet {
            vault.save(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        }
    }
    @Published var customSearchTemplate: String {
        didSet {
            vault.save(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        }
    }
    @Published var moreMenuActionIDs: Set<String> {
        didSet {
            vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        }
    }
    @Published var customIconNames: [String: String] {
        didSet {
            vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        }
    }
    @Published var history: [BrowserHistoryItem]
    @Published var essentials: [BrowserEssentialItem]
    @Published var downloads: [BrowserDownloadItem]
    @Published var localAIName: String {
        didSet {
            vault.save(localAIName, forKey: Self.StorageKey.localAIName)
        }
    }
    @Published var localAIURLText: String {
        didSet {
            vault.save(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        }
    }
    @Published var vpnProfile: CustomVPNProfile {
        didSet {
            persistVPNProfile()
        }
    }
    @Published var vpnStatusMessage = "Custom VPN profile not configured."
    @Published var downloadStatusMessage = ""
    @Published private var customIconImageDataBySlot: [String: Data] {
        didSet {
            vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        }
    }
    private let vault: SecureBrowserVault
    private let browserMusicPlayer = BrowserMusicPlayer()
    private var pendingWebFileImportCompletion: (([URL]?) -> Void)?

    init(vault: SecureBrowserVault) {
        self.vault = vault
        let darkReaderEnabled = vault.load(Bool.self, forKey: Self.StorageKey.darkReaderEnabled, default: false)
        let savedDarkReaderTheme = BrowserDarkReaderTheme(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.darkReaderTheme, default: "")
        ) ?? .zenCopy
        let stylusCatppuccinEnabled = vault.load(Bool.self, forKey: Self.StorageKey.stylusCatppuccinEnabled, default: false)
        let fpsForcerEnabled = vault.load(Bool.self, forKey: Self.StorageKey.fpsForcerEnabled, default: false)
        let savedForcedFPS = Self.clampedForcedFPS(
            vault.load(Double.self, forKey: Self.StorageKey.forcedFPS, default: 60)
        )
        let adBlockerEnabled = vault.load(Bool.self, forKey: Self.StorageKey.adBlockerEnabled, default: true)
        let placement = BrowserChromePlacement(rawValue: vault.load(String.self, forKey: Self.StorageKey.chromePlacement, default: "")) ?? .left
        let selectedSearchEngine = BrowserSearchEngine(rawValue: vault.load(String.self, forKey: Self.StorageKey.searchEngine, default: "")) ?? .duckDuckGo
        let savedCustomSearch = vault.load(String.self, forKey: Self.StorageKey.customSearchTemplate, default: BrowserSearchEngine.defaultCustomTemplate)
        let savedMoreMenuActionIDs = vault.load(Set<String>.self, forKey: Self.StorageKey.moreMenuActionIDs, default: [])
        let savedCustomIconNames = vault.load([String: String].self, forKey: Self.StorageKey.customIconNames, default: [:])
        let savedCustomIconImageData = vault.load([String: Data].self, forKey: Self.StorageKey.customIconImageDataBySlot, default: [:])
        let savedHistory = Self.loadHistory(vault: vault)
        let savedEssentials = Self.loadEssentials(vault: vault)
        let savedDownloads = Self.loadDownloads(vault: vault)
        let savedVPNProfile = Self.loadVPNProfile(vault: vault)
        let savedBrowserMusicTrack = BrowserMusicTrack(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.browserMusicTrack, default: "")
        ) ?? .focus
        let restoredTabs = Self.loadTabs(
            vault: vault,
            isDarkReaderEnabled: darkReaderEnabled,
            darkReaderTheme: savedDarkReaderTheme,
            isStylusCatppuccinEnabled: stylusCatppuccinEnabled,
            isFPSForcerEnabled: fpsForcerEnabled,
            forcedFPS: savedForcedFPS,
            isAdBlockerEnabled: adBlockerEnabled
        )
        let savedTopSearchBarPlacement = BrowserTopSearchBarPlacement(
            rawValue: vault.load(String.self, forKey: Self.StorageKey.topSearchBarPlacement, default: "")
        ) ?? .top
        let savedTopSearchBarPositionX = Self.clampedUnit(
            vault.load(Double.self, forKey: Self.StorageKey.topSearchBarPositionX, default: 0.5)
        )
        let savedTopSearchBarPositionY = Self.clampedUnit(
            vault.load(
                Double.self,
                forKey: Self.StorageKey.topSearchBarPositionY,
                default: Self.defaultTopSearchBarY(for: savedTopSearchBarPlacement)
            )
        )

        self.chromePlacement = placement
        self.areSideTabsCollapsed = vault.load(Bool.self, forKey: Self.StorageKey.sideTabsCollapsed, default: false)
        self.searchEngine = selectedSearchEngine
        self.customSearchTemplate = savedCustomSearch
        self.moreMenuActionIDs = savedMoreMenuActionIDs
        self.isTopSearchBarEnabled = vault.load(Bool.self, forKey: Self.StorageKey.topSearchBarEnabled, default: false)
        self.topSearchBarPlacement = savedTopSearchBarPlacement
        self.topSearchBarPositionX = savedTopSearchBarPositionX
        self.topSearchBarPositionY = savedTopSearchBarPositionY
        self.topSearchBarDraftX = savedTopSearchBarPositionX
        self.topSearchBarDraftY = savedTopSearchBarPositionY
        self.customIconNames = Self.sanitizedIconNames(savedCustomIconNames)
        self.customIconImageDataBySlot = Self.sanitizedIconImageData(savedCustomIconImageData)
        self.history = savedHistory
        self.essentials = savedEssentials
        self.downloads = savedDownloads
        self.isTutorialPresented = vault.load(Bool.self, forKey: Self.StorageKey.hasCompletedTutorial, default: false) == false
        self.isDarkReaderEnabled = darkReaderEnabled
        self.darkReaderTheme = savedDarkReaderTheme
        self.isStylusCatppuccinEnabled = stylusCatppuccinEnabled
        self.isFPSForcerEnabled = fpsForcerEnabled
        self.forcedFPS = savedForcedFPS
        self.isAdBlockerEnabled = adBlockerEnabled
        self.isBrowserMusicEnabled = vault.load(Bool.self, forKey: Self.StorageKey.browserMusicEnabled, default: false)
        self.browserMusicTrack = savedBrowserMusicTrack
        self.browserMusicVolume = Self.clampedUnit(vault.load(Double.self, forKey: Self.StorageKey.browserMusicVolume, default: 0.34))
        self.newTabOpensSearch = vault.load(Bool.self, forKey: Self.StorageKey.newTabOpensSearch, default: true)
        self.localAIName = vault.load(String.self, forKey: Self.StorageKey.localAIName, default: "Local AI")
        self.localAIURLText = vault.load(String.self, forKey: Self.StorageKey.localAIURLText, default: "")
        self.vpnProfile = savedVPNProfile
        self.vpnStatusMessage = savedVPNProfile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
        self.tabs = restoredTabs.tabs
        self.selectedTabID = restoredTabs.selectedTabID

        for tab in tabs {
            configure(tab)
        }
        migrateLoadedStateToEncryptedVault()
        updateBrowserMusicPlayer()
    }

    var forcedFPSLabel: String {
        forcedFPS >= Self.infiniteForcedFPSValue ? "Infinite" : "\(Int(forcedFPS.rounded())) FPS"
    }

    var selectedTab: BrowserTab? {
        let visibleTabs = isPrivateModeEnabled ? privateTabs : normalTabs
        guard let selectedTabID = selectedTabID else { return visibleTabs.first }
        return visibleTabs.first { $0.id == selectedTabID } ?? visibleTabs.first
    }

    var selectedContainedTab: BrowserTab? {
        guard let selectedContainedTabID = selectedContainedTabID else { return containedTabs.first }
        return containedTabs.first { $0.id == selectedContainedTabID } ?? containedTabs.first
    }

    var normalTabs: [BrowserTab] {
        tabs.filter { !$0.isPrivate }
    }

    var privateTabs: [BrowserTab] {
        tabs.filter { $0.isPrivate }
    }

    var chromeTabs: [BrowserTab] {
        isPrivateModeEnabled ? privateTabs : normalTabs
    }

    var visibleNormalTabs: [BrowserTab] {
        isPrivateModeEnabled ? [] : normalTabs
    }

    var visiblePrivateTabs: [BrowserTab] {
        isPrivateModeEnabled ? privateTabs : []
    }

    var visibleEssentials: [BrowserEssentialItem] {
        isPrivateModeEnabled ? [] : essentials
    }

    var visibleContainedTabs: [BrowserTab] {
        isPrivateModeEnabled ? [] : containedTabs
    }

    var closeAllTabsWarningMessage: String {
        let summary = [
            Self.countLabel(normalTabs.count, singular: "normal tab"),
            Self.countLabel(privateTabs.count, singular: "private tab"),
            Self.countLabel(containedTabs.count, singular: "contained tab")
        ].joined(separator: ", ")
        let replacementKind = isPrivateModeEnabled ? "private" : "normal"
        return "This will close \(summary). History, downloads, saved themes, and settings will stay. A fresh \(replacementKind) tab will open."
    }

    func select(_ tab: BrowserTab) {
        if isPrivateModeEnabled {
            guard tab.isPrivate else { return }
        } else {
            guard tab.isPrivate == false else { return }
        }

        selectedTabID = tab.id
        if isFloatingSearchPresented {
            floatingSearchText = tab.addressText
        }
        persistOpenTabs()
    }

    func selectFromFinder(_ tab: BrowserTab) {
        if containedTabs.contains(where: { $0.id == tab.id }) {
            guard isPrivateModeEnabled == false else { return }
            selectedContainedTabID = tab.id
            isContainedBrowserPresented = true
        } else {
            select(tab)
        }
        isTabFinderPresented = false
    }

    @discardableResult
    func openTab(startURL: URL = BrowserDefaults.homeURL, private isPrivate: Bool = false) -> BrowserTab {
        let shouldOpenPrivate = isPrivate || isPrivateModeEnabled
        let tab = BrowserTab(
            startURL: startURL,
            isPrivate: shouldOpenPrivate,
            usesPersistentStorage: shouldOpenPrivate == false,
            isDarkReaderEnabled: isDarkReaderEnabled,
            darkReaderTheme: darkReaderTheme,
            isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled,
            isFPSForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS
        )
        configure(tab)
        tabs.append(tab)
        selectedTabID = tab.id
        persistOpenTabs()
        return tab
    }

    func openNewTabAndSearch(private isPrivate: Bool = false) {
        let tab = openTab(private: isPrivate || isPrivateModeEnabled)
        floatingSearchText = tab.addressText
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = newTabOpensSearch
    }

    func openPrivateTab() {
        guard isPrivateModeEnabled else {
            requestPrivateModeToggle()
            return
        }

        openNewTabAndSearch(private: true)
    }

    @discardableResult
    func openContainedTab(startURL: URL = BrowserDefaults.containedBrowserStartURL) -> BrowserTab {
        let tab = BrowserTab(
            startURL: startURL,
            usesPersistentStorage: false,
            isContainedBrowser: true,
            isDarkReaderEnabled: isDarkReaderEnabled,
            darkReaderTheme: darkReaderTheme,
            isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            isAdBlockerEnabled: isAdBlockerEnabled,
            isFPSForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS
        )
        configureContained(tab)
        containedTabs.append(tab)
        selectedContainedTabID = tab.id
        isContainedBrowserPresented = true
        return tab
    }

    func showContainedTabs() {
        if containedTabs.isEmpty {
            openContainedTab()
        } else {
            isContainedBrowserPresented = true
        }
    }

    func selectContained(_ tab: BrowserTab) {
        selectedContainedTabID = tab.id
    }

    func closeContainedBrowser() {
        isContainedBrowserPresented = false
    }

    func closeContained(_ tab: BrowserTab) {
        containedTabs.removeAll { $0.id == tab.id }

        if containedTabs.isEmpty {
            selectedContainedTabID = nil
            isContainedBrowserPresented = false
            return
        }

        if selectedContainedTabID == tab.id {
            selectedContainedTabID = containedTabs.last?.id
        }
    }

    func closeFromFinder(_ tab: BrowserTab) {
        if containedTabs.contains(where: { $0.id == tab.id }) {
            closeContained(tab)
        } else {
            close(tab)
        }
    }

    func submitContainedAddress() {
        selectedContainedTab?.submitAddress(searchEngine: searchEngine, customSearchTemplate: customSearchTemplate)
    }

    func close(_ tab: BrowserTab) {
        if isPrivateModeEnabled, tab.isPrivate, privateTabs.count <= 1 {
            tab.load(BrowserTab.homeURL)
            selectedTabID = tab.id
            persistOpenTabs()
            return
        }

        guard tabs.count > 1 else {
            tab.load(BrowserTab.homeURL)
            persistOpenTabs()
            return
        }

        let wasSelected = selectedTabID.map { $0 == tab.id } ?? false
        tabs.removeAll { $0.id == tab.id }

        if wasSelected {
            if isPrivateModeEnabled {
                selectedTabID = privateTabs.last?.id
            } else if let normalTab = normalTabs.last {
                selectedTabID = normalTab.id
            } else {
                selectedTabID = openTab().id
            }
        }

        if isPrivateModeEnabled, privateTabs.isEmpty {
            openTab(private: true)
        }

        persistOpenTabs()
    }

    func requestCloseAllTabs() {
        isCloseAllTabsWarningPresented = true
    }

    func closeAllTabs() {
        isCloseAllTabsWarningPresented = false
        isFloatingSearchPresented = false
        isContainedBrowserPresented = false
        isTabFinderPresented = false
        selectedContainedTabID = nil
        containedTabs.removeAll()
        tabs.removeAll()
        selectedTabID = nil

        let replacement = openTab(private: isPrivateModeEnabled)
        floatingSearchText = replacement.addressText
        shouldSelectFloatingSearchText = false
        persistOpenTabs()
    }

    func goBack() {
        selectedTab?.goBack()
    }

    func goForward() {
        selectedTab?.goForward()
    }

    func reloadOrStop() {
        selectedTab?.reloadOrStop()
    }

    func submitAddress() {
        let submittedText = isFloatingSearchPresented ? floatingSearchText : selectedTab?.addressText ?? ""
        selectedTab?.addressText = submittedText
        selectedTab?.submitAddress(searchEngine: searchEngine, customSearchTemplate: customSearchTemplate)
        floatingSearchText = selectedTab?.addressText ?? submittedText
        shouldSelectFloatingSearchText = false
        isFloatingSearchPresented = false
    }

    func openFloatingSearch() {
        floatingSearchText = selectedTab?.addressText ?? ""
        shouldSelectFloatingSearchText = true
        isFloatingSearchPresented = true
    }

    func setDarkReaderEnabled(_ enabled: Bool) {
        isDarkReaderEnabled = enabled
        vault.save(enabled, forKey: Self.StorageKey.darkReaderEnabled)
        for tab in tabs {
            tab.setDarkReaderEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setDarkReaderEnabled(enabled)
        }
    }

    func setDarkReaderTheme(_ theme: BrowserDarkReaderTheme) {
        darkReaderTheme = theme
    }

    func setStylusCatppuccinEnabled(_ enabled: Bool) {
        isStylusCatppuccinEnabled = enabled
    }

    func setFPSForcerEnabled(_ enabled: Bool) {
        isFPSForcerEnabled = enabled
    }

    func setForcedFPS(_ fps: Double) {
        forcedFPS = fps
    }

    func setAdBlockerEnabled(_ enabled: Bool) {
        isAdBlockerEnabled = enabled
        vault.save(enabled, forKey: Self.StorageKey.adBlockerEnabled)
        for tab in tabs {
            tab.setAdBlockerEnabled(enabled)
        }
        for tab in containedTabs {
            tab.setAdBlockerEnabled(enabled)
        }
    }

    func setBrowserMusicEnabled(_ enabled: Bool) {
        isBrowserMusicEnabled = enabled
    }

    func toggleBrowserMusic() {
        isBrowserMusicEnabled.toggle()
    }

    private func updateBrowserMusicPlayer() {
        browserMusicPlayer.update(
            isEnabled: isBrowserMusicEnabled,
            track: browserMusicTrack,
            volume: browserMusicVolume
        )
    }

    func setTabBarCollapsed(_ collapsed: Bool) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            areSideTabsCollapsed = collapsed
        }
    }

    func toggleSideTabs() {
        setTabBarCollapsed(!areSideTabsCollapsed)
    }

    func handleTwoFingerSwipe(deltaX: CGFloat, deltaY: CGFloat) {
        let placement: BrowserChromePlacement
        if abs(deltaY) > abs(deltaX) {
            placement = deltaY < 0 ? .top : .bottom
        } else {
            placement = deltaX < 0 ? .right : .left
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            chromePlacement = placement
            areSideTabsCollapsed = false
        }
    }

    func completeTutorial() {
        isTutorialPresented = false
        vault.save(true, forKey: Self.StorageKey.hasCompletedTutorial)
    }

    func handleThreeFingerSwipe(deltaX: CGFloat) {
        if deltaX > 0 {
            goBack()
        } else {
            goForward()
        }
    }

    func openHistoryItem(_ item: BrowserHistoryItem) {
        guard let url = item.url else { return }
        selectedTab?.load(url)
        isHistoryPresented = false
    }

    func addEssential(from tab: BrowserTab) {
        guard tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else {
            return
        }

        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BrowserEssentialItem(
            title: title.isEmpty ? (url.host ?? url.absoluteString) : title,
            urlString: url.absoluteString
        )

        essentials.removeAll { $0.urlString == item.urlString }
        essentials.insert(item, at: 0)
        if essentials.count > 16 {
            essentials = Array(essentials.prefix(16))
        }
        saveEssentials()
    }

    func openEssential(_ item: BrowserEssentialItem) {
        guard let url = item.url else { return }
        selectedTab?.load(url)
    }

    func removeEssential(_ item: BrowserEssentialItem) {
        essentials.removeAll { $0.id == item.id }
        saveEssentials()
    }

    func clearHistory() {
        history = []
        saveHistory()
    }

    func clearDownloads() {
        for item in downloads {
            deleteDownloadFiles(for: item)
        }
        downloads = []
        saveDownloads()
    }

    func deleteDownload(_ item: BrowserDownloadItem) {
        deleteDownloadFiles(for: item)
        downloads.removeAll { $0.id == item.id }
        saveDownloads()
    }

    func canExportDownload(_ item: BrowserDownloadItem) -> Bool {
        guard item.state == .finished else { return false }

        if let encryptedURL = item.encryptedLocalURL {
            return FileManager.default.fileExists(atPath: encryptedURL.path)
        }

        return FileManager.default.fileExists(atPath: item.localPath)
    }

    func prepareDownloadForExport(_ item: BrowserDownloadItem) throws -> URL {
        guard item.state == .finished else {
            throw Self.downloadError("That download has not finished yet.")
        }

        let exportURL = try Self.temporaryExportURL(for: item.filename)
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        if let encryptedURL = item.encryptedLocalURL {
            guard FileManager.default.fileExists(atPath: encryptedURL.path) else {
                throw Self.downloadError("The encrypted download file is missing.")
            }
            let encryptedData = try Data(contentsOf: encryptedURL)
            let plaintextData = try vault.decryptData(encryptedData)
            try plaintextData.write(to: exportURL, options: [.atomic])
            downloadStatusMessage = "Created a temporary decrypted copy of \(item.filename)."
            return exportURL
        }

        guard FileManager.default.fileExists(atPath: item.localPath) else {
            throw Self.downloadError("The downloaded file is missing.")
        }

        try FileManager.default.copyItem(at: item.localURL, to: exportURL)
        downloadStatusMessage = "Created a temporary export copy of \(item.filename)."
        return exportURL
    }

    func cleanupPreparedExport(at url: URL) {
        guard url.deletingLastPathComponent().lastPathComponent == Self.temporaryExportDirectoryName else { return }
        try? FileManager.default.removeItem(at: url)
    }

    func downloadSelectedTab() {
        guard let url = selectedTab?.url,
              Self.shouldPersist(url: url) else {
            downloadStatusMessage = "Nothing downloadable on the current tab."
            isDownloadsPresented = true
            return
        }

        download(url: url)
    }

    func retryDownload(_ item: BrowserDownloadItem) {
        guard let url = URL(string: item.sourceURLString), Self.shouldPersist(url: url) else {
            downloadStatusMessage = "That download does not have a retryable source URL."
            return
        }

        download(url: url, suggestedFilename: item.filename)
    }

    func isInMoreMenu(_ action: BrowserToolbarAction) -> Bool {
        moreMenuActionIDs.contains(action.rawValue)
    }

    func setMoreMenuAction(_ action: BrowserToolbarAction, enabled: Bool) {
        if enabled {
            moreMenuActionIDs.insert(action.rawValue)
        } else {
            moreMenuActionIDs.remove(action.rawValue)
        }
        vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
    }

    func customIconName(for slot: BrowserCustomIconSlot) -> String {
        let value = customIconNames[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? slot.defaultSymbol : value
    }

    func customIconName(for slot: BrowserCustomIconSlot?, fallback: String) -> String {
        guard let slot else { return fallback }
        let value = customIconNames[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? fallback : value
    }

    func setCustomIconName(_ name: String, for slot: BrowserCustomIconSlot) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty || trimmedName == slot.defaultSymbol {
            customIconNames.removeValue(forKey: slot.rawValue)
        } else {
            customIconNames[slot.rawValue] = trimmedName
        }
    }

    func customIconImage(for slot: BrowserCustomIconSlot?) -> UIImage? {
        guard let slot,
              let data = customIconImageDataBySlot[slot.rawValue] else { return nil }
        return UIImage(data: data)
    }

    func hasCustomIconImage(for slot: BrowserCustomIconSlot) -> Bool {
        customIconImageDataBySlot[slot.rawValue] != nil
    }

    func setCustomIconImage(from url: URL, for slot: BrowserCustomIconSlot) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else { return }
        setCustomIconImage(fromImageData: data, for: slot)
    }

    func setCustomIconImage(fromImageData rawData: Data, for slot: BrowserCustomIconSlot) {
        guard let data = Self.normalizedIconData(from: rawData) else { return }
        customIconImageDataBySlot[slot.rawValue] = data
    }

    func clearCustomIconImage(for slot: BrowserCustomIconSlot) {
        customIconImageDataBySlot.removeValue(forKey: slot.rawValue)
    }

    func resetCustomIcons() {
        customIconNames = [:]
        customIconImageDataBySlot = [:]
    }

    func advancedConfigJSON(theme: BrowserTheme) -> String {
        let config = BrowserAdvancedConfig(
            topSearchBarEnabled: isTopSearchBarEnabled,
            topSearchBarPlacement: topSearchBarPlacement.rawValue,
            topSearchBarPositionX: topSearchBarPositionX,
            topSearchBarPositionY: topSearchBarPositionY,
            chromePlacement: chromePlacement.rawValue,
            sideTabsCollapsed: areSideTabsCollapsed,
            searchEngine: searchEngine.rawValue,
            customSearchTemplate: customSearchTemplate,
            newTabOpensSearch: newTabOpensSearch,
            darkReaderTheme: darkReaderTheme.rawValue,
            stylusCatppuccinEnabled: isStylusCatppuccinEnabled,
            fpsForcerEnabled: isFPSForcerEnabled,
            forcedFPS: forcedFPS,
            browserMusicEnabled: isBrowserMusicEnabled,
            browserMusicTrack: browserMusicTrack.rawValue,
            browserMusicVolume: browserMusicVolume,
            darkReaderEnabled: isDarkReaderEnabled,
            adBlockerEnabled: isAdBlockerEnabled,
            moreMenuActions: BrowserToolbarAction.allCases
                .map(\.rawValue)
                .filter { moreMenuActionIDs.contains($0) },
            customIcons: customIconNames,
            tabBarTransparencyEnabled: theme.isTabBarTransparencyEnabled,
            tabBarTransparency: theme.tabBarTransparency,
            userBackgroundEnabled: theme.isUserBackgroundEnabled,
            colors: theme.colorConfig,
            gradientColors: theme.gradientColorConfig
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(config),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return text
    }

    func applyAdvancedConfigJSON(_ text: String, theme: BrowserTheme) throws {
        guard let data = text.data(using: .utf8) else {
            throw Self.configError("Config text is not valid UTF-8.")
        }

        let decoder = JSONDecoder()
        let config = try decoder.decode(BrowserAdvancedConfig.self, from: data)

        if let placement = BrowserChromePlacement(rawValue: config.chromePlacement) {
            chromePlacement = placement
        }

        if let selectedSearchEngine = BrowserSearchEngine(rawValue: config.searchEngine) {
            searchEngine = selectedSearchEngine
        }

        isTopSearchBarEnabled = config.topSearchBarEnabled
        if let topSearchBarPlacementValue = config.topSearchBarPlacement,
           let placement = BrowserTopSearchBarPlacement(rawValue: topSearchBarPlacementValue) {
            topSearchBarPlacement = placement
        }
        if let topSearchBarPositionX = config.topSearchBarPositionX {
            self.topSearchBarPositionX = topSearchBarPositionX
            self.topSearchBarDraftX = Self.clampedUnit(topSearchBarPositionX)
        }
        if let topSearchBarPositionY = config.topSearchBarPositionY {
            self.topSearchBarPositionY = topSearchBarPositionY
            self.topSearchBarDraftY = Self.clampedUnit(topSearchBarPositionY)
            self.topSearchBarPlacement = Self.nearestTopSearchBarPlacement(for: topSearchBarPositionY)
        }
        areSideTabsCollapsed = config.sideTabsCollapsed
        customSearchTemplate = config.customSearchTemplate
        newTabOpensSearch = config.newTabOpensSearch ?? true
        if let darkReaderThemeValue = config.darkReaderTheme,
           let theme = BrowserDarkReaderTheme(rawValue: darkReaderThemeValue) {
            darkReaderTheme = theme
        }
        isStylusCatppuccinEnabled = config.stylusCatppuccinEnabled ?? false
        isFPSForcerEnabled = config.fpsForcerEnabled ?? false
        forcedFPS = Self.clampedForcedFPS(config.forcedFPS ?? 60)
        isBrowserMusicEnabled = config.browserMusicEnabled ?? false
        if let browserMusicTrackValue = config.browserMusicTrack,
           let track = BrowserMusicTrack(rawValue: browserMusicTrackValue) {
            browserMusicTrack = track
        }
        browserMusicVolume = Self.clampedUnit(config.browserMusicVolume ?? 0.34)
        moreMenuActionIDs = Set(config.moreMenuActions.filter { actionID in
            BrowserToolbarAction(rawValue: actionID) != nil
        })
        customIconNames = Self.sanitizedIconNames(config.customIcons)
        setDarkReaderEnabled(config.darkReaderEnabled)
        setAdBlockerEnabled(config.adBlockerEnabled)
        theme.applyAdvancedConfig(
            colors: config.colors,
            gradientColors: config.gradientColors,
            tabBarTransparencyEnabled: config.tabBarTransparencyEnabled,
            tabBarTransparency: config.tabBarTransparency,
            userBackgroundEnabled: config.userBackgroundEnabled
        )
    }

    func performToolbarAction(_ action: BrowserToolbarAction) {
        switch action {
        case .back:
            goBack()
        case .forward:
            goForward()
        case .reload:
            reloadOrStop()
        case .tabFinder:
            isTabFinderPresented = true
        case .closeAllTabs:
            requestCloseAllTabs()
        case .containedTabs:
            showContainedTabs()
        case .downloadCurrent:
            downloadSelectedTab()
        case .history:
            isHistoryPresented = true
        case .downloads:
            isDownloadsPresented = true
        case .browserMusic:
            toggleBrowserMusic()
        case .placement:
            break
        case .settings:
            isSettingsPresented = true
        }
    }

    func searchResults(for rawQuery: String) -> [BrowserSearchResult] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let canShowHistory = selectedTab?.isPrivate != true

        if query.isEmpty {
            guard canShowHistory else { return [] }
            return history.prefix(6).compactMap { item in
                guard let url = item.url else { return nil }
                return BrowserSearchResult(
                    title: item.title,
                    subtitle: item.urlString,
                    symbolName: "clock.arrow.circlepath",
                    url: url
                )
            }
        }

        var results: [BrowserSearchResult] = []

        func appendUnique(_ result: BrowserSearchResult) {
            if results.contains(where: { $0.url == result.url }) == false {
                results.append(result)
            }
        }

        let destination = BrowserTab.destinationURL(
            from: query,
            searchEngine: searchEngine,
            customSearchTemplate: customSearchTemplate
        )
        let searchURL = searchEngine.searchURL(for: query, customTemplate: customSearchTemplate)

        appendUnique(
            BrowserSearchResult(
                title: "Search \(searchEngine.title) for \(query)",
                subtitle: searchURL.absoluteString,
                symbolName: "magnifyingglass",
                url: searchURL
            )
        )

        if destination != searchURL {
            appendUnique(
                BrowserSearchResult(
                    title: "Open \(destination.host ?? query)",
                    subtitle: destination.absoluteString,
                    symbolName: "arrow.up.right.square",
                    url: destination
                )
            )
        }

        let quickSearches = [
            ("Images", "photo", "\(query) images"),
            ("News", "newspaper", "\(query) news"),
            ("Videos", "play.rectangle", "\(query) videos"),
            ("Maps", "map", "\(query) map")
        ]

        for quickSearch in quickSearches {
            appendUnique(
                BrowserSearchResult(
                    title: "\(quickSearch.0) for \(query)",
                    subtitle: "Search \(searchEngine.title)",
                    symbolName: quickSearch.1,
                    url: searchEngine.searchURL(for: quickSearch.2, customTemplate: customSearchTemplate)
                )
            )
        }

        if canShowHistory {
            let lowercasedQuery = query.lowercased()
            for item in history where results.count < 12 {
                let titleMatches = item.title.lowercased().contains(lowercasedQuery)
                let urlMatches = item.urlString.lowercased().contains(lowercasedQuery)
                guard (titleMatches || urlMatches), let url = item.url else { continue }
                appendUnique(
                    BrowserSearchResult(
                        title: item.title,
                        subtitle: item.urlString,
                        symbolName: "clock.arrow.circlepath",
                        url: url
                    )
                )
            }
        }

        return Array(results.prefix(12))
    }

    func openSearchResult(_ result: BrowserSearchResult) {
        floatingSearchText = result.url.absoluteString
        shouldSelectFloatingSearchText = false
        selectedTab?.addressText = result.url.absoluteString
        selectedTab?.load(result.url)
        isFloatingSearchPresented = false
    }

    func requestWebFileImport(allowsMultipleSelection: Bool, completion: @escaping ([URL]?) -> Void) {
        pendingWebFileImportCompletion?(nil)
        pendingWebFileImportCompletion = completion
        allowsMultipleWebFileImport = allowsMultipleSelection
        isWebFileImporterPresented = true
    }

    func completeWebFileImport(_ result: Result<[URL], Error>) {
        guard let completion = pendingWebFileImportCompletion else { return }
        pendingWebFileImportCompletion = nil
        allowsMultipleWebFileImport = false

        switch result {
        case .success(let urls):
            completion(urls)
        case .failure:
            completion(nil)
        }
    }

    func openAIShortcut(_ assistant: AIAssistant) {
        openTab(startURL: assistant.url)
    }

    func openLocalAI() {
        guard let url = Self.normalizedURL(from: localAIURLText) else {
            isLocalAIImporterPresented = true
            return
        }

        openTab(startURL: url)
    }

    func openAddOnLibrary(_ library: BrowserAddOnLibrary) {
        openTab(startURL: library.url)
        isAddOnsPresented = false
    }

    func importLocalAI(name: String, urlText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        localAIName = trimmedName.isEmpty ? "Local AI" : trimmedName
        localAIURLText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func saveVPNProfile(_ profile: CustomVPNProfile) {
        vpnProfile = profile
        vpnStatusMessage = profile.isConfigured ? "Custom VPN profile saved." : "Custom VPN profile not configured."
    }

    func installVPNProfile() {
        vpnStatusMessage = "Saving custom VPN profile to iOS..."
        let profile = vpnProfile

        Task {
            do {
                try await CustomVPNController.install(profile: profile)
                vpnStatusMessage = profile.isEnabled
                    ? "Custom VPN profile saved and enabled in iOS."
                    : "Custom VPN profile saved in iOS."
            } catch {
                vpnStatusMessage = "\(error.localizedDescription) Add the Personal VPN entitlement when signing if iOS rejects it."
            }
        }
    }

    func connectVPNProfile() {
        vpnStatusMessage = "Connecting custom VPN..."

        Task {
            do {
                try await CustomVPNController.connect()
                vpnStatusMessage = "Custom VPN connection requested."
            } catch {
                vpnStatusMessage = "\(error.localizedDescription) Make sure the VPN profile is saved, entitled, and points at a real server."
            }
        }
    }

    func disconnectVPNProfile() {
        CustomVPNController.disconnect()
        vpnStatusMessage = "Custom VPN disconnect requested."
    }

    func requestPrivateModeToggle() {
        privateModeAuthMessage = ""

        if isPrivateModeEnabled {
            leavePrivateMode()
            return
        }

        privateModeAuthAction = .enter
        isPrivateModeAuthPresented = true
    }

    func completePrivateModeAuthentication() {
        switch privateModeAuthAction {
        case .enter:
            enterPrivateMode()
        case .exit:
            leavePrivateMode()
        }
        privateModeAuthMessage = ""
        isPrivateModeAuthPresented = false
    }

    func enterPrivateMode() {
        isPrivateModeEnabled = true
        isHistoryPresented = false
        isContainedBrowserPresented = false
        isTabFinderPresented = false
        let shouldOpenSearchAfterEntry: Bool

        if privateTabs.isEmpty {
            openTab(private: true)
            shouldOpenSearchAfterEntry = newTabOpensSearch
        } else if selectedTab?.isPrivate != true {
            selectedTabID = privateTabs.last?.id
            shouldOpenSearchAfterEntry = false
        } else {
            shouldOpenSearchAfterEntry = false
        }

        floatingSearchText = selectedTab?.addressText ?? ""
        shouldSelectFloatingSearchText = shouldOpenSearchAfterEntry
        isFloatingSearchPresented = shouldOpenSearchAfterEntry
    }

    func leavePrivateMode() {
        isPrivateModeEnabled = false
        isFloatingSearchPresented = false
        isTabFinderPresented = false

        if selectedTab?.isPrivate == true {
            if let normalTab = normalTabs.last {
                selectedTabID = normalTab.id
            } else {
                selectedTabID = openTab().id
            }
        }

        floatingSearchText = selectedTab?.addressText ?? ""
    }

    func beginTopSearchBarMove() {
        isTopSearchBarEnabled = true
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = true
    }

    func updateTopSearchBarDraft(x: Double, y: Double) {
        topSearchBarDraftX = Self.clampedUnit(x)
        topSearchBarDraftY = Self.clampedUnit(y)
    }

    func saveTopSearchBarMove() {
        topSearchBarPositionX = topSearchBarDraftX
        topSearchBarPositionY = topSearchBarDraftY
        topSearchBarPlacement = Self.nearestTopSearchBarPlacement(for: topSearchBarDraftY)
        isTopSearchBarMoveMode = false
    }

    func cancelTopSearchBarMove() {
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = false
    }

    func resetTopSearchBarPosition() {
        topSearchBarDraftX = 0.5
        topSearchBarDraftY = 0.0
    }

    var displayedTopSearchBarX: Double {
        isTopSearchBarMoveMode ? topSearchBarDraftX : topSearchBarPositionX
    }

    var displayedTopSearchBarY: Double {
        isTopSearchBarMoveMode ? topSearchBarDraftY : topSearchBarPositionY
    }

    func resetToDefaults() {
        chromePlacement = .left
        areSideTabsCollapsed = false
        isTopSearchBarEnabled = false
        topSearchBarPlacement = .top
        topSearchBarPositionX = 0.5
        topSearchBarPositionY = 0.0
        topSearchBarDraftX = topSearchBarPositionX
        topSearchBarDraftY = topSearchBarPositionY
        isTopSearchBarMoveMode = false
        searchEngine = .duckDuckGo
        customSearchTemplate = BrowserSearchEngine.defaultCustomTemplate
        newTabOpensSearch = true
        isBrowserMusicEnabled = false
        browserMusicTrack = .focus
        browserMusicVolume = 0.34
        moreMenuActionIDs = []
        resetCustomIcons()
        localAIName = "Local AI"
        localAIURLText = ""
        setAdBlockerEnabled(true)
        setDarkReaderEnabled(false)
        darkReaderTheme = .zenCopy
        isStylusCatppuccinEnabled = false
        isFPSForcerEnabled = false
        forcedFPS = 60
        essentials = []
        saveEssentials()
        saveVPNProfile(.empty)
    }

    private func configure(_ tab: BrowserTab) {
        tab.onNavigationFinished = { [weak self] tab in
            self?.recordVisit(from: tab)
        }
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] deltaX, deltaY in
            self?.handleTwoFingerSwipe(deltaX: deltaX, deltaY: deltaY)
        }
        tab.onThreeFingerSwipe = { [weak self] deltaX in
            self?.handleThreeFingerSwipe(deltaX: deltaX)
        }
        tab.onFilePickerRequested = { [weak self] allowsMultipleSelection, completion in
            self?.requestWebFileImport(allowsMultipleSelection: allowsMultipleSelection, completion: completion)
        }
    }

    private func configureContained(_ tab: BrowserTab) {
        tab.onDownloadUpdated = { [weak self] item in
            self?.updateDownload(item)
        }
        tab.onTwoFingerSwipe = { [weak self] deltaX, deltaY in
            self?.handleTwoFingerSwipe(deltaX: deltaX, deltaY: deltaY)
        }
        tab.onThreeFingerSwipe = { [weak tab] deltaX in
            if deltaX > 0 {
                tab?.goBack()
            } else {
                tab?.goForward()
            }
        }
        tab.onFilePickerRequested = { [weak self] allowsMultipleSelection, completion in
            self?.requestWebFileImport(allowsMultipleSelection: allowsMultipleSelection, completion: completion)
        }
    }

    private func recordVisit(from tab: BrowserTab) {
        guard tab.isPrivate == false,
              let url = tab.url,
              Self.shouldPersist(url: url) else {
            return
        }

        let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = BrowserHistoryItem(
            title: title.isEmpty ? url.absoluteString : title,
            urlString: url.absoluteString
        )

        history.removeAll { $0.urlString == item.urlString }
        history.insert(item, at: 0)
        if history.count > 250 {
            history = Array(history.prefix(250))
        }

        saveHistory()
        persistOpenTabs()
    }

    private func persistOpenTabs() {
        let normalTabs = tabs.filter { $0.isPrivate == false }
        let selectedNormalID: BrowserTab.ID?
        if let selectedTabID = selectedTabID,
           normalTabs.contains(where: { $0.id == selectedTabID }) {
            selectedNormalID = selectedTabID
        } else {
            selectedNormalID = normalTabs.first?.id
        }

        let persistedTabs = normalTabs.compactMap { tab -> PersistedBrowserTab? in
            guard let url = tab.url, Self.shouldPersist(url: url) else { return nil }
            return PersistedBrowserTab(
                title: tab.title,
                urlString: url.absoluteString,
                isSelected: selectedNormalID.map { $0 == tab.id } ?? false
            )
        }

        vault.save(persistedTabs, forKey: Self.StorageKey.openTabs)
    }

    private func saveHistory() {
        vault.save(history, forKey: Self.StorageKey.history)
    }

    private func saveEssentials() {
        vault.save(essentials, forKey: Self.StorageKey.essentials)
    }

    private func updateDownload(_ item: BrowserDownloadItem) {
        if item.state == .finished, item.isEncrypted == false {
            finalizeDownloadedFile(item, plaintextURL: item.localURL)
            return
        }

        upsertDownload(item)
    }

    private func upsertDownload(_ item: BrowserDownloadItem) {
        downloads.removeAll { existing in
            existing.id == item.id
                || existing.localPath == item.localPath
                || (item.encryptedLocalPath != nil && existing.encryptedLocalPath == item.encryptedLocalPath)
        }
        downloads.insert(item, at: 0)
        if downloads.count > 100 {
            downloads = Array(downloads.prefix(100))
        }
        saveDownloads()
    }

    private func download(url: URL, suggestedFilename: String? = nil) {
        do {
            let destination = try BrowserTab.downloadDestination(for: BrowserTab.downloadFilename(for: url, suggestedFilename: suggestedFilename))
            let item = BrowserDownloadItem(
                filename: destination.lastPathComponent,
                sourceURLString: url.absoluteString,
                localPath: destination.path,
                state: .inProgress
            )
            updateDownload(item)
            downloadStatusMessage = "Downloading \(item.filename)..."
            isDownloadsPresented = true

            Task { [weak self] in
                do {
                    let (temporaryURL, _) = try await URLSession.shared.download(from: url)
                    await MainActor.run {
                        self?.finalizeDownloadedFile(item, plaintextURL: temporaryURL, displayURL: destination)
                    }
                } catch {
                    await MainActor.run {
                        var failed = item
                        failed.state = .failed
                        failed.errorMessage = error.localizedDescription
                        self?.downloadStatusMessage = error.localizedDescription
                        self?.updateDownload(failed)
                    }
                }
            }
        } catch {
            downloadStatusMessage = error.localizedDescription
            isDownloadsPresented = true
        }
    }

    private func finalizeDownloadedFile(_ item: BrowserDownloadItem, plaintextURL: URL, displayURL: URL? = nil) {
        var finished = item

        do {
            guard FileManager.default.fileExists(atPath: plaintextURL.path) else {
                throw Self.downloadError("The temporary download file is missing.")
            }

            let plaintextData = try Data(contentsOf: plaintextURL)
            let encryptedData = try vault.encryptData(plaintextData)
            let encryptedURL = try encryptedDownloadURL(for: item)

            if FileManager.default.fileExists(atPath: encryptedURL.path) {
                try FileManager.default.removeItem(at: encryptedURL)
            }

            try encryptedData.write(to: encryptedURL, options: [.atomic])
            #if os(iOS)
            try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: encryptedURL.path)
            #endif
            try? FileManager.default.removeItem(at: plaintextURL)

            let presentationURL = displayURL ?? (try? BrowserTab.downloadDestination(for: item.filename))
            finished.localPath = presentationURL?.path ?? item.localPath
            finished.state = .finished
            finished.errorMessage = nil
            finished.encryptedLocalPath = encryptedURL.path
            finished.originalByteCount = Int64(plaintextData.count)

            downloadStatusMessage = "Saved encrypted \(finished.filename)."
            upsertDownload(finished)
        } catch {
            try? FileManager.default.removeItem(at: plaintextURL)
            finished.state = .failed
            finished.errorMessage = "Download could not be encrypted: \(error.localizedDescription)"
            downloadStatusMessage = finished.errorMessage ?? error.localizedDescription
            upsertDownload(finished)
        }
    }

    private func deleteDownloadFiles(for item: BrowserDownloadItem) {
        var paths = Set<String>()
        paths.insert(item.localPath)
        if let encryptedLocalPath = item.encryptedLocalPath {
            paths.insert(encryptedLocalPath)
        }

        for path in paths where path.isEmpty == false && FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
        }
    }

    private func encryptedDownloadURL(for item: BrowserDownloadItem) throws -> URL {
        let directory = try Self.encryptedDownloadsDirectory()
        let filename = "\(item.id.uuidString)-\(Self.safeDownloadFilename(item.filename)).glidevault"
        return directory.appendingPathComponent(filename)
    }

    private static func encryptedDownloadsDirectory() throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("GlideEncryptedDownloads", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static let temporaryExportDirectoryName = "GlideExportCopies"

    private static func temporaryExportURL(for filename: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(temporaryExportDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(UUID().uuidString)-\(safeDownloadFilename(filename))")
    }

    private static func safeDownloadFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "download" : trimmed
        let illegal = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return fallback
            .components(separatedBy: illegal)
            .joined(separator: "-")
    }

    private static func downloadError(_ message: String) -> NSError {
        NSError(domain: "GlideDownloads", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func configError(_ message: String) -> NSError {
        NSError(domain: "GlideAdvancedConfig", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func sanitizedIconNames(_ names: [String: String]) -> [String: String] {
        var values: [String: String] = [:]

        for slot in BrowserCustomIconSlot.allCases {
            let value = names[slot.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.isEmpty == false, value != slot.defaultSymbol {
                values[slot.rawValue] = value
            }
        }

        return values
    }

    private static func sanitizedIconImageData(_ imageData: [String: Data]) -> [String: Data] {
        var values: [String: Data] = [:]

        for slot in BrowserCustomIconSlot.allCases {
            if let data = imageData[slot.rawValue], UIImage(data: data) != nil {
                values[slot.rawValue] = data
            }
        }

        return values
    }

    private static func normalizedIconData(from rawData: Data) -> Data? {
        guard let image = UIImage(data: rawData) else { return nil }

        let maxSide: CGFloat = 256
        let longestSide = max(image.size.width, image.size.height)
        let scale = longestSide > maxSide ? maxSide / longestSide : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        return normalizedImage.pngData()
    }

    private func saveDownloads() {
        vault.save(downloads, forKey: Self.StorageKey.downloads)
    }

    private func persistVPNProfile() {
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
    }

    private func migrateLoadedStateToEncryptedVault() {
        vault.save(chromePlacement.rawValue, forKey: Self.StorageKey.chromePlacement)
        vault.save(areSideTabsCollapsed, forKey: Self.StorageKey.sideTabsCollapsed)
        vault.save(isTopSearchBarEnabled, forKey: Self.StorageKey.topSearchBarEnabled)
        vault.save(topSearchBarPlacement.rawValue, forKey: Self.StorageKey.topSearchBarPlacement)
        vault.save(topSearchBarPositionX, forKey: Self.StorageKey.topSearchBarPositionX)
        vault.save(topSearchBarPositionY, forKey: Self.StorageKey.topSearchBarPositionY)
        vault.save(searchEngine.rawValue, forKey: Self.StorageKey.searchEngine)
        vault.save(customSearchTemplate, forKey: Self.StorageKey.customSearchTemplate)
        vault.save(moreMenuActionIDs, forKey: Self.StorageKey.moreMenuActionIDs)
        vault.save(customIconNames, forKey: Self.StorageKey.customIconNames)
        vault.save(customIconImageDataBySlot, forKey: Self.StorageKey.customIconImageDataBySlot)
        vault.save(history, forKey: Self.StorageKey.history)
        vault.save(essentials, forKey: Self.StorageKey.essentials)
        vault.save(downloads, forKey: Self.StorageKey.downloads)
        vault.save(localAIName, forKey: Self.StorageKey.localAIName)
        vault.save(localAIURLText, forKey: Self.StorageKey.localAIURLText)
        vault.save(isAdBlockerEnabled, forKey: Self.StorageKey.adBlockerEnabled)
        vault.save(isDarkReaderEnabled, forKey: Self.StorageKey.darkReaderEnabled)
        vault.save(darkReaderTheme.rawValue, forKey: Self.StorageKey.darkReaderTheme)
        vault.save(isStylusCatppuccinEnabled, forKey: Self.StorageKey.stylusCatppuccinEnabled)
        vault.save(isFPSForcerEnabled, forKey: Self.StorageKey.fpsForcerEnabled)
        vault.save(forcedFPS, forKey: Self.StorageKey.forcedFPS)
        vault.save(isBrowserMusicEnabled, forKey: Self.StorageKey.browserMusicEnabled)
        vault.save(browserMusicTrack.rawValue, forKey: Self.StorageKey.browserMusicTrack)
        vault.save(browserMusicVolume, forKey: Self.StorageKey.browserMusicVolume)
        vault.save(newTabOpensSearch, forKey: Self.StorageKey.newTabOpensSearch)
        vault.save(isTutorialPresented == false, forKey: Self.StorageKey.hasCompletedTutorial)
        vault.save(vpnProfile, forKey: Self.StorageKey.vpnProfile)
        persistOpenTabs()
    }

    private static func loadTabs(
        vault: SecureBrowserVault,
        isDarkReaderEnabled: Bool,
        darkReaderTheme: BrowserDarkReaderTheme,
        isStylusCatppuccinEnabled: Bool,
        isFPSForcerEnabled: Bool,
        forcedFPS: Double,
        isAdBlockerEnabled: Bool
    ) -> (tabs: [BrowserTab], selectedTabID: BrowserTab.ID?) {
        let savedTabs = vault.load([PersistedBrowserTab].self, forKey: StorageKey.openTabs, default: [])
        guard savedTabs.isEmpty == false else {
            let firstTab = BrowserTab(
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS
            )
            return ([firstTab], firstTab.id)
        }

        var restoredTabs: [BrowserTab] = []
        var selectedID: BrowserTab.ID?

        for savedTab in savedTabs {
            guard let url = URL(string: savedTab.urlString) else { continue }
            let tab = BrowserTab(
                startURL: url,
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS
            )
            restoredTabs.append(tab)
            if savedTab.isSelected {
                selectedID = tab.id
            }
        }

        if restoredTabs.isEmpty {
            let firstTab = BrowserTab(
                usesPersistentStorage: true,
                isDarkReaderEnabled: isDarkReaderEnabled,
                darkReaderTheme: darkReaderTheme,
                isStylusCatppuccinEnabled: isStylusCatppuccinEnabled,
                isAdBlockerEnabled: isAdBlockerEnabled,
                isFPSForcerEnabled: isFPSForcerEnabled,
                forcedFPS: forcedFPS
            )
            return ([firstTab], firstTab.id)
        }

        return (restoredTabs, selectedID ?? restoredTabs.first?.id)
    }

    private static func loadHistory(vault: SecureBrowserVault) -> [BrowserHistoryItem] {
        vault.load([BrowserHistoryItem].self, forKey: StorageKey.history, default: [])
    }

    private static func loadDownloads(vault: SecureBrowserVault) -> [BrowserDownloadItem] {
        vault.load([BrowserDownloadItem].self, forKey: StorageKey.downloads, default: [])
    }

    private static func loadEssentials(vault: SecureBrowserVault) -> [BrowserEssentialItem] {
        vault.load([BrowserEssentialItem].self, forKey: StorageKey.essentials, default: [])
    }

    private static func loadVPNProfile(vault: SecureBrowserVault) -> CustomVPNProfile {
        vault.load(CustomVPNProfile.self, forKey: StorageKey.vpnProfile, default: .empty)
    }

    private static func shouldPersist(url: URL) -> Bool {
        guard BrowserTab.isStartPageURL(url) == false,
              url.host != "browser.local" else {
            return false
        }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "file"].contains(scheme)
    }

    private static func normalizedURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           ["http", "https"].contains(scheme) {
            return url
        }

        return URL(string: "http://\(trimmed)")
    }

    private static func clampedUnit(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }

    private static func clampedForcedFPS(_ value: Double) -> Double {
        guard value.isFinite else { return infiniteForcedFPSValue }
        return min(max(value.rounded(), minimumForcedFPS), infiniteForcedFPSValue)
    }

    private static func countLabel(_ count: Int, singular: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(singular)s"
    }

    private static func defaultTopSearchBarY(for placement: BrowserTopSearchBarPlacement) -> Double {
        switch placement {
        case .top:
            return 0.0
        case .center:
            return 0.5
        case .bottom:
            return 1.0
        }
    }

    private static func nearestTopSearchBarPlacement(for y: Double) -> BrowserTopSearchBarPlacement {
        let clampedY = clampedUnit(y)
        if clampedY < 0.25 {
            return .top
        }
        if clampedY > 0.75 {
            return .bottom
        }
        return .center
    }

    private enum StorageKey {
        static let darkReaderEnabled = "ZenFireBrowser.darkReaderEnabled"
        static let chromePlacement = "ZenFireBrowser.chromePlacement"
        static let sideTabsCollapsed = "ZenFireBrowser.sideTabsCollapsed"
        static let topSearchBarEnabled = "ZenFireBrowser.topSearchBarEnabled"
        static let topSearchBarPlacement = "ZenFireBrowser.topSearchBarPlacement"
        static let topSearchBarPositionX = "ZenFireBrowser.topSearchBarPositionX"
        static let topSearchBarPositionY = "ZenFireBrowser.topSearchBarPositionY"
        static let searchEngine = "ZenFireBrowser.searchEngine"
        static let customSearchTemplate = "ZenFireBrowser.customSearchTemplate"
        static let moreMenuActionIDs = "ZenFireBrowser.moreMenuActionIDs"
        static let customIconNames = "ZenFireBrowser.customIconNames"
        static let customIconImageDataBySlot = "ZenFireBrowser.customIconImageDataBySlot"
        static let history = "ZenFireBrowser.history"
        static let essentials = "ZenFireBrowser.essentials"
        static let openTabs = "ZenFireBrowser.openTabs"
        static let localAIName = "ZenFireBrowser.localAIName"
        static let localAIURLText = "ZenFireBrowser.localAIURLText"
        static let adBlockerEnabled = "ZenFireBrowser.adBlockerEnabled"
        static let darkReaderTheme = "ZenFireBrowser.darkReaderTheme"
        static let stylusCatppuccinEnabled = "ZenFireBrowser.stylusCatppuccinEnabled"
        static let fpsForcerEnabled = "ZenFireBrowser.fpsForcerEnabled"
        static let forcedFPS = "ZenFireBrowser.forcedFPS"
        static let browserMusicEnabled = "ZenFireBrowser.browserMusicEnabled"
        static let browserMusicTrack = "ZenFireBrowser.browserMusicTrack"
        static let browserMusicVolume = "ZenFireBrowser.browserMusicVolume"
        static let newTabOpensSearch = "ZenFireBrowser.newTabOpensSearch"
        static let hasCompletedTutorial = "ZenFireBrowser.hasCompletedTutorial"
        static let downloads = "ZenFireBrowser.downloads"
        static let vpnProfile = "ZenFireBrowser.vpnProfile"
    }
}
