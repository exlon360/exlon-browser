import Foundation
import SwiftUI

struct ContentView: View {
    @StateObject private var store = MagnetSimulatorStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            MagnetSceneView(snapshot: store.snapshot)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                topBar

                Divider()
                    .overlay(.white.opacity(0.22))

                controlGrid

                HStack(spacing: 10) {
                    Toggle("Field", isOn: $store.showFieldLines)
                        .tint(.magnetCyan)
                    Toggle("Gel", isOn: $store.showGel)
                        .tint(.magnetGreen)
                    Toggle("Compass", isOn: $store.showCompasses)
                        .tint(.magnetGold)
                    Toggle("Forces", isOn: $store.showForces)
                        .tint(.magnetRose)
                }
                .font(.caption.weight(.bold))
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(Color.black)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Magnet Simulator")
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                Text(store.scenario.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Menu {
                ForEach(MagnetScenario.allCases) { scenario in
                    Button {
                        store.scenario = scenario
                    } label: {
                        Label(scenario.rawValue, systemImage: scenario.symbolName)
                    }
                }
            } label: {
                Label(store.scenario.rawValue, systemImage: store.scenario.symbolName)
            }
            .buttonStyle(SimulatorButtonStyle(tint: .magnetCyan))

            Menu {
                ForEach(MagnetKind.allCases) { kind in
                    Button {
                        store.activeKind = kind
                        store.scenario = .fullCatalog
                    } label: {
                        Label(kind.rawValue, systemImage: kind.symbolName)
                    }
                }
            } label: {
                Label(store.activeKind.rawValue, systemImage: store.activeKind.symbolName)
            }
            .buttonStyle(SimulatorButtonStyle(tint: .magnetGold))

            Button {
                store.isPaused.toggle()
            } label: {
                Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(SimulatorIconButtonStyle(tint: .magnetGreen))
        }
    }

    private var controlGrid: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                SliderControl(title: "Strength", value: $store.strength, range: 0.2...2.5, tint: .magnetRose)
                SliderControl(title: "Current", value: $store.current, range: 0.0...1.0, tint: .magnetGold)
            }

            GridRow {
                SliderControl(title: "Gel", value: $store.gelViscosity, range: 0.0...1.0, tint: .magnetGreen)
                SliderControl(title: "Density", value: $store.fieldDensity, range: 0.0...1.0, tint: .magnetCyan)
            }

            GridRow {
                SliderControl(title: "Motion", value: $store.animationSpeed, range: 0.0...1.0, tint: .magnetViolet)
                HStack(spacing: 8) {
                    Button {
                        store.reversePolarity()
                    } label: {
                        Label("Flip", systemImage: "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(SimulatorButtonStyle(tint: .magnetRose))

                    Button {
                        store.pulseField()
                    } label: {
                        Label("Pulse", systemImage: "waveform.path.ecg")
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(SimulatorButtonStyle(tint: .magnetGold))

                    Button {
                        store.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(SimulatorIconButtonStyle(tint: .magnetCyan))
                }
            }
        }
    }
}

private struct SliderControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption.weight(.black))
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: range)
                .tint(tint)
        }
    }
}

private struct SimulatorButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.black))
            .foregroundStyle(configuration.isPressed ? .black : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? tint : tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            }
    }
}

private struct SimulatorIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(configuration.isPressed ? .black : tint)
            .background(configuration.isPressed ? tint : tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            }
    }
}

private extension Color {
    static let magnetCyan = Color(red: 0.32, green: 0.88, blue: 1.0)
    static let magnetGold = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let magnetGreen = Color(red: 0.42, green: 0.94, blue: 0.55)
    static let magnetRose = Color(red: 1.0, green: 0.32, blue: 0.45)
    static let magnetViolet = Color(red: 0.74, green: 0.54, blue: 1.0)
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}
