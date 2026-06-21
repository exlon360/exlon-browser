import Combine
import Foundation

enum MagnetScenario: String, CaseIterable, Identifiable {
    case fullCatalog = "Full Catalog"
    case gelLab = "Gel Lab"
    case electromagnet = "Electromagnet"
    case halbach = "Halbach"
    case compassRoom = "Compass Room"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .fullCatalog:
            return "square.grid.3x3.fill"
        case .gelLab:
            return "drop.fill"
        case .electromagnet:
            return "bolt.fill"
        case .halbach:
            return "arrow.triangle.2.circlepath"
        case .compassRoom:
            return "safari.fill"
        }
    }
}

enum MagnetKind: String, CaseIterable, Identifiable {
    case bar = "Bar"
    case horseshoe = "Horseshoe"
    case ring = "Ring"
    case disk = "Disk"
    case cube = "Cube"
    case sphere = "Sphere"
    case neodymiumBlock = "Neodymium"
    case solenoid = "Solenoid"
    case electromagnet = "Electromagnet"
    case halbachArray = "Halbach"
    case fridgeSheet = "Sheet"
    case compassNeedle = "Compass"
    case ferrofluid = "Ferrofluid"
    case magneticGel = "Magnetic Gel"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .bar:
            return "minus.rectangle.fill"
        case .horseshoe:
            return "u.square.fill"
        case .ring:
            return "circle.circle.fill"
        case .disk:
            return "record.circle.fill"
        case .cube:
            return "cube.fill"
        case .sphere:
            return "circle.fill"
        case .neodymiumBlock:
            return "shippingbox.fill"
        case .solenoid:
            return "scribble.variable"
        case .electromagnet:
            return "bolt.circle.fill"
        case .halbachArray:
            return "arrow.triangle.2.circlepath"
        case .fridgeSheet:
            return "rectangle.grid.1x2.fill"
        case .compassNeedle:
            return "safari.fill"
        case .ferrofluid:
            return "drop.triangle.fill"
        case .magneticGel:
            return "drop.fill"
        }
    }
}

struct MagnetSceneSnapshot: Equatable {
    var scenario: MagnetScenario
    var activeKind: MagnetKind
    var strength: Double
    var current: Double
    var gelViscosity: Double
    var fieldDensity: Double
    var showFieldLines: Bool
    var showGel: Bool
    var showCompasses: Bool
    var showForces: Bool
    var polarity: Double
    var animationSpeed: Double
    var isPaused: Bool
}

final class MagnetSimulatorStore: ObservableObject {
    @Published var scenario: MagnetScenario = .fullCatalog
    @Published var activeKind: MagnetKind = .bar
    @Published var strength: Double = 1.0
    @Published var current: Double = 0.65
    @Published var gelViscosity: Double = 0.45
    @Published var fieldDensity: Double = 0.58
    @Published var showFieldLines: Bool = true
    @Published var showGel: Bool = true
    @Published var showCompasses: Bool = true
    @Published var showForces: Bool = true
    @Published var polarity: Double = 1.0
    @Published var animationSpeed: Double = 0.55
    @Published var isPaused: Bool = false

    var snapshot: MagnetSceneSnapshot {
        MagnetSceneSnapshot(
            scenario: scenario,
            activeKind: activeKind,
            strength: strength,
            current: current,
            gelViscosity: gelViscosity,
            fieldDensity: fieldDensity,
            showFieldLines: showFieldLines,
            showGel: showGel,
            showCompasses: showCompasses,
            showForces: showForces,
            polarity: polarity,
            animationSpeed: animationSpeed,
            isPaused: isPaused
        )
    }

    func reversePolarity() {
        polarity *= -1.0
    }

    func pulseField() {
        strength = min(2.5, strength + 0.35)
        current = min(1.0, current + 0.2)
    }

    func reset() {
        scenario = .fullCatalog
        activeKind = .bar
        strength = 1.0
        current = 0.65
        gelViscosity = 0.45
        fieldDensity = 0.58
        showFieldLines = true
        showGel = true
        showCompasses = true
        showForces = true
        polarity = 1.0
        animationSpeed = 0.55
        isPaused = false
    }
}
