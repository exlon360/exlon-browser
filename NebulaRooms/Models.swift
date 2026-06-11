import Foundation
import SwiftUI

struct ChatUser: Identifiable, Codable, Equatable {
    let id: UUID
    var username: String
    var password: String
    var createdAt: Date
}

struct ChatRoom: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var password: String
    var createdByUserID: UUID
    var createdAt: Date
    var messages: [ChatMessage]
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let authorID: UUID
    let authorName: String
    var body: String
    let createdAt: Date
    var state: MessageState
}

enum MessageState: String, Codable, Equatable {
    case visible
    case deletedForMe
    case removedForEveryone
}

struct NebulaTheme: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var primaryHex: String
    var secondaryHex: String
    var accentHex: String
    var bubbleHex: String

    static let defaultTheme = NebulaTheme(
        id: UUID(uuidString: "7E134FCF-9338-4771-AF02-4FDD55E9B7D5") ?? UUID(),
        name: "Nebula",
        primaryHex: "#9A4DFF",
        secondaryHex: "#D83BCE",
        accentHex: "#31F477",
        bubbleHex: "#3A1D64"
    )

    static let builtIns: [NebulaTheme] = [
        .defaultTheme,
        NebulaTheme(id: UUID(), name: "Void", primaryHex: "#7862FF", secondaryHex: "#B947FF", accentHex: "#66E8FF", bubbleHex: "#241A58"),
        NebulaTheme(id: UUID(), name: "Pulse", primaryHex: "#FF4FD8", secondaryHex: "#8E5CFF", accentHex: "#FFD166", bubbleHex: "#4A1748"),
        NebulaTheme(id: UUID(), name: "Aurora", primaryHex: "#54F3C5", secondaryHex: "#7C5CFF", accentHex: "#E7FF6B", bubbleHex: "#143A37")
    ]
}

extension Date {
    var chatTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}

extension Color {
    init(hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)

        let red: UInt64
        let green: UInt64
        let blue: UInt64

        switch value.count {
        case 6:
            red = (int >> 16) & 0xff
            green = (int >> 8) & 0xff
            blue = int & 0xff
        default:
            red = 154
            green = 77
            blue = 255
        }

        self.init(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255
        )
    }
}
