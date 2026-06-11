import Foundation
import Combine
import CryptoKit
import Security

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var users: [ChatUser]
    @Published private(set) var rooms: [ChatRoom]
    @Published var currentUser: ChatUser? = nil {
        didSet {
            saveCurrentUserID()
        }
    }
    @Published var currentRoomID: UUID? = nil {
        didSet {
            saveCurrentRoomID()
        }
    }
    @Published var selectedTheme: NebulaTheme
    @Published var customThemes: [NebulaTheme]
    @Published var statusMessage = ""

    private static let usersKey = "nebula.rooms.users"
    private static let roomsKey = "nebula.rooms.rooms"
    private static let themeKey = "nebula.rooms.theme"
    private static let customThemesKey = "nebula.rooms.customThemes"
    private static let currentUserIDKey = "nebula.rooms.currentUserID"
    private static let currentRoomIDKey = "nebula.rooms.currentRoomID"
    private static let legacySeededSystemUserID = UUID(uuidString: "75DB0F6E-7E9D-43E1-9776-3C192E64A496") ?? UUID()

    var currentRoom: ChatRoom? {
        guard let currentRoomID else { return nil }
        return rooms.first { $0.id == currentRoomID }
    }

    var joinedRooms: [ChatRoom] {
        rooms.sorted { $0.createdAt > $1.createdAt }
    }

    var allThemes: [NebulaTheme] {
        NebulaTheme.builtIns + customThemes
    }

    init() {
        users = Self.load([ChatUser].self, key: Self.usersKey, fallback: [])
        rooms = Self.load([ChatRoom].self, key: Self.roomsKey, fallback: [])
            .filter { $0.createdByUserID != Self.legacySeededSystemUserID }
        selectedTheme = Self.load(NebulaTheme.self, key: Self.themeKey, fallback: .defaultTheme)
        customThemes = Self.load([NebulaTheme].self, key: Self.customThemesKey, fallback: [])

        if let savedUserID = Self.loadUUID(key: Self.currentUserIDKey),
           let user = users.first(where: { $0.id == savedUserID }) {
            currentUser = user
        } else {
            currentUser = nil
        }

        if currentUser != nil,
           let savedRoomID = Self.loadUUID(key: Self.currentRoomIDKey),
           rooms.contains(where: { $0.id == savedRoomID }) {
            currentRoomID = savedRoomID
        } else {
            currentRoomID = nil
        }

        saveRooms()
    }

    func signUp(username: String, password: String) {
        let cleanedName = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedName.isEmpty == false else {
            statusMessage = "Choose a username."
            return
        }

        guard isValidPassword(password) else {
            statusMessage = "Password can be 1 to 100 characters."
            return
        }

        guard users.contains(where: { $0.username.caseInsensitiveCompare(cleanedName) == .orderedSame }) == false else {
            statusMessage = "That username already exists."
            return
        }

        let credentials = Self.makePasswordHash(password)
        let user = ChatUser(
            id: UUID(),
            username: cleanedName,
            passwordHash: credentials.hash,
            passwordSalt: credentials.salt,
            createdAt: Date()
        )
        users.append(user)
        currentUser = user
        statusMessage = "Welcome, \(cleanedName)."
        saveUsers()
    }

    func signIn(username: String, password: String) {
        let cleanedName = username.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let userIndex = users.firstIndex(where: {
            $0.username.caseInsensitiveCompare(cleanedName) == .orderedSame && verifyPassword(password, for: $0)
        }) else {
            statusMessage = "Username or password did not match."
            return
        }

        if users[userIndex].passwordSalt.isEmpty {
            let credentials = Self.makePasswordHash(password)
            users[userIndex].passwordHash = credentials.hash
            users[userIndex].passwordSalt = credentials.salt
            saveUsers()
        }

        currentUser = users[userIndex]
        statusMessage = "Back in the room."
    }

    func signOut() {
        currentUser = nil
        currentRoomID = nil
        statusMessage = ""
    }

    func createRoom(name: String, password: String) {
        guard let currentUser else { return }
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedName.isEmpty == false else {
            statusMessage = "Room name is required."
            return
        }

        guard isValidPassword(password) else {
            statusMessage = "Room password can be 1 to 100 characters."
            return
        }

        guard rooms.contains(where: { $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame }) == false else {
            statusMessage = "A room with that name already exists."
            return
        }

        let room = ChatRoom(
            id: UUID(),
            name: cleanedName,
            password: password,
            createdByUserID: currentUser.id,
            createdAt: Date(),
            messages: [
                ChatMessage(
                    id: UUID(),
                    authorID: currentUser.id,
                    authorName: currentUser.username,
                    body: "Created \(cleanedName).",
                    createdAt: Date(),
                    state: .visible
                )
            ]
        )

        rooms.append(room)
        currentRoomID = room.id
        statusMessage = "Room created."
        saveRooms()
    }

    func joinRoom(name: String, password: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let room = rooms.first(where: {
            $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame && $0.password == password
        }) else {
            statusMessage = "Room name or password did not match."
            return
        }

        currentRoomID = room.id
        statusMessage = "Joined \(room.name)."
    }

    func openRoom(_ room: ChatRoom) {
        currentRoomID = room.id
    }

    func leaveRoom() {
        currentRoomID = nil
    }

    func sendMessage(_ body: String) {
        guard let currentUser, let roomIndex = currentRoomIndex else { return }
        let cleanedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedBody.isEmpty == false else { return }

        rooms[roomIndex].messages.append(
            ChatMessage(
                id: UUID(),
                authorID: currentUser.id,
                authorName: currentUser.username,
                body: cleanedBody,
                createdAt: Date(),
                state: .visible
            )
        )
        saveRooms()
    }

    func deleteMessageForMe(_ message: ChatMessage) {
        updateMessage(message) { item in
            item.state = .deletedForMe
        }
    }

    func removeMessageForEveryone(_ message: ChatMessage) {
        updateMessage(message) { item in
            item.body = ""
            item.state = .removedForEveryone
        }
    }

    func selectTheme(_ theme: NebulaTheme) {
        selectedTheme = theme
        saveTheme()
    }

    func addCustomTheme(name: String, primaryHex: String, secondaryHex: String, accentHex: String, bubbleHex: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let theme = NebulaTheme(
            id: UUID(),
            name: cleanedName.isEmpty ? "Custom \(customThemes.count + 1)" : cleanedName,
            primaryHex: normalizeHex(primaryHex, fallback: selectedTheme.primaryHex),
            secondaryHex: normalizeHex(secondaryHex, fallback: selectedTheme.secondaryHex),
            accentHex: normalizeHex(accentHex, fallback: selectedTheme.accentHex),
            bubbleHex: normalizeHex(bubbleHex, fallback: selectedTheme.bubbleHex)
        )

        customThemes.append(theme)
        selectedTheme = theme
        saveCustomThemes()
        saveTheme()
    }

    private var currentRoomIndex: Int? {
        guard let currentRoomID else { return nil }
        return rooms.firstIndex { $0.id == currentRoomID }
    }

    private func updateMessage(_ message: ChatMessage, update: (inout ChatMessage) -> Void) {
        guard let roomIndex = currentRoomIndex,
              let messageIndex = rooms[roomIndex].messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }

        update(&rooms[roomIndex].messages[messageIndex])
        saveRooms()
    }

    private func isValidPassword(_ password: String) -> Bool {
        (1...100).contains(password.count)
    }

    private func verifyPassword(_ password: String, for user: ChatUser) -> Bool {
        guard user.passwordSalt.isEmpty == false else {
            return user.passwordHash == password
        }

        return Self.hash(password: password, salt: user.passwordSalt) == user.passwordHash
    }

    private func normalizeHex(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

        guard hex.count == 6, hex.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return fallback
        }

        return "#\(hex.uppercased())"
    }

    private func saveUsers() {
        Self.save(users, key: Self.usersKey)
    }

    private func saveRooms() {
        Self.save(rooms, key: Self.roomsKey)
    }

    private func saveTheme() {
        Self.save(selectedTheme, key: Self.themeKey)
    }

    private func saveCustomThemes() {
        Self.save(customThemes, key: Self.customThemesKey)
    }

    private func saveCurrentUserID() {
        if let currentUser {
            UserDefaults.standard.set(currentUser.id.uuidString, forKey: Self.currentUserIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.currentUserIDKey)
        }
    }

    private func saveCurrentRoomID() {
        if let currentRoomID {
            UserDefaults.standard.set(currentRoomID.uuidString, forKey: Self.currentRoomIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.currentRoomIDKey)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String, fallback: T) -> T {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(T.self, from: data) else {
            return fallback
        }
        return value
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadUUID(key: String) -> UUID? {
        guard let string = UserDefaults.standard.string(forKey: key) else { return nil }
        return UUID(uuidString: string)
    }

    private static func makePasswordHash(_ password: String) -> (hash: String, salt: String) {
        let salt = randomSalt()
        return (hash(password: password, salt: salt), salt)
    }

    private static func hash(password: String, salt: String) -> String {
        let data = Data("\(salt):\(password)".utf8)
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func randomSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if result == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }

        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}
