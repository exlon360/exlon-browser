import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        ZStack {
            NebulaBackground(theme: store.selectedTheme)

            if store.currentUser == nil {
                AuthView()
            } else if store.currentRoom == nil {
                RoomLobbyView()
            } else {
                ChatRoomView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tint(Color(hex: store.selectedTheme.primaryHex))
        .statusBarHidden(true)
    }
}

private struct AuthView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var mode: AuthMode = .signUp
    @State private var username = ""
    @State private var password = ""
    @State private var isPasswordVisible = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Spacer(minLength: 18)

                    BrandHeader(subtitle: "Username and password only. Your login stays saved.")

                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Mode", selection: $mode) {
                            ForEach(AuthMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        NebulaField(title: "Username", text: $username, systemImage: "person.fill")

                        NebulaSecureField(
                            title: "Password",
                            text: $password,
                            isVisible: $isPasswordVisible,
                            systemImage: "lock.fill"
                        )

                        HStack {
                            Text("Password length: 1-100 characters")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.56))

                            Spacer()

                            Text("\(password.count) / 100")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
                        }

                        Button {
                            submit()
                        } label: {
                            Label(mode.buttonTitle, systemImage: mode == .signUp ? "sparkles" : "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NebulaPrimaryButtonStyle(theme: store.selectedTheme))
                        .disabled(password.count > 100)
                    }
                    .padding(18)
                    .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.28), lineWidth: 1)
                    }

                    StatusText(text: store.statusMessage)

                    Spacer(minLength: 18)
                }
                .frame(maxWidth: proxy.size.width > 700 ? 560 : .infinity, alignment: .leading)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .center)
                .padding(.horizontal, proxy.size.width > 700 ? 32 : 20)
                .padding(.vertical, 18)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scrollIndicators(.hidden)
        }
    }

    private func submit() {
        switch mode {
        case .signUp:
            store.signUp(username: username, password: password)
        case .signIn:
            store.signIn(username: username, password: password)
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signUp
    case signIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signUp:
            return "Create"
        case .signIn:
            return "Login"
        }
    }

    var buttonTitle: String {
        switch self {
        case .signUp:
            return "Create Account"
        case .signIn:
            return "Enter Nebula"
        }
    }
}

private struct RoomLobbyView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var mode: RoomMode = .create
    @State private var roomName = ""
    @State private var roomPassword = ""
    @State private var isPasswordVisible = false
    @State private var isThemesPresented = false

    var body: some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 18) {
                        LobbyHeader(isThemesPresented: $isThemesPresented)

                        RoomAccessPanel(
                            mode: $mode,
                            roomName: $roomName,
                            roomPassword: $roomPassword,
                            isPasswordVisible: $isPasswordVisible,
                            submit: submit
                        )

                        StatusText(text: store.statusMessage)
                    }
                    .frame(width: 420, alignment: .topLeading)

                    RoomListView()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 18) {
                    LobbyHeader(isThemesPresented: $isThemesPresented)

                    RoomAccessPanel(
                        mode: $mode,
                        roomName: $roomName,
                        roomPassword: $roomPassword,
                        isPasswordVisible: $isPasswordVisible,
                        submit: submit
                    )

                    RoomListView()

                    StatusText(text: store.statusMessage)
                }
            }
            .frame(maxWidth: 1040, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
        .sheet(isPresented: $isThemesPresented) {
            ThemeStudioView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func submit() {
        switch mode {
        case .create:
            store.createRoom(name: roomName, password: roomPassword)
        case .join:
            store.joinRoom(name: roomName, password: roomPassword)
        }
    }
}

private struct RoomAccessPanel: View {
    @EnvironmentObject private var store: ChatStore
    @Binding var mode: RoomMode
    @Binding var roomName: String
    @Binding var roomPassword: String
    @Binding var isPasswordVisible: Bool
    let submit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ForEach(RoomMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        Label(option.title, systemImage: option == .create ? "plus.message.fill" : "rectangle.portrait.and.arrow.right")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 54)
                    }
                    .buttonStyle(RoomModeButtonStyle(theme: store.selectedTheme, isSelected: mode == option))
                }
            }

            NebulaField(title: "Room Name", text: $roomName, systemImage: mode == .create ? "plus.message.fill" : "rectangle.portrait.and.arrow.right")

            NebulaSecureField(
                title: "Room Password",
                text: $roomPassword,
                isVisible: $isPasswordVisible,
                systemImage: "lock.fill"
            )

            HStack {
                Text("Password length: 1-100 characters")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))

                Spacer()

                Button {
                    submit()
                } label: {
                    Label(mode.buttonTitle, systemImage: mode == .create ? "plus" : "arrow.right")
                }
                .buttonStyle(NebulaPrimaryButtonStyle(theme: store.selectedTheme, isCompact: true))
                .disabled(roomPassword.count > 100)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.24), lineWidth: 1)
        }
    }
}

private enum RoomMode: String, CaseIterable, Identifiable {
    case create
    case join

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create:
            return "Create Room"
        case .join:
            return "Join Room"
        }
    }

    var buttonTitle: String {
        switch self {
        case .create:
            return "Create Room"
        case .join:
            return "Join Room"
        }
    }
}

private struct ChatRoomView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var draft = ""
    @State private var isThemesPresented = false

    private var visibleMessages: [ChatMessage] {
        store.currentRoom?.messages.filter { $0.state != .deletedForMe } ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ChatHeader(isThemesPresented: $isThemesPresented)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(visibleMessages) { message in
                                MessageRow(message: message)
                                    .id(message.id)
                            }
                        }
                        .frame(maxWidth: min(geometry.size.width - 32, 860), alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollIndicators(.hidden)
                    .onChange(of: visibleMessages.count) { _ in
                        guard let last = visibleMessages.last else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }

                ComposerView(draft: $draft)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background {
            NebulaBackground(theme: store.selectedTheme)
        }
        .sheet(isPresented: $isThemesPresented) {
            ThemeStudioView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct LobbyHeader: View {
    @EnvironmentObject private var store: ChatStore
    @Binding var isThemesPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AppMark(size: 80)

                VStack(alignment: .leading, spacing: 4) {
                    Text("NEBULA")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("ROOMS")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: store.selectedTheme.primaryHex),
                                    Color(hex: store.selectedTheme.secondaryHex)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 7) {
                        Circle()
                            .fill(Color(hex: store.selectedTheme.accentHex))
                            .frame(width: 9, height: 9)

                        Text(store.currentUser?.username ?? "Guest")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button {
                    isThemesPresented = true
                } label: {
                    Label("Themes", systemImage: "paintpalette.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(NebulaGhostButtonStyle(theme: store.selectedTheme))

                Button {
                    store.signOut()
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .frame(width: 42)
                }
                .buttonStyle(NebulaIconButtonStyle(theme: store.selectedTheme))
                .accessibilityLabel("Sign out")
            }
        }
    }
}

private struct BrandHeader: View {
    @EnvironmentObject private var store: ChatStore
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AppMark(size: 96)

            VStack(alignment: .leading, spacing: 2) {
                Text("NEBULA")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("ROOMS")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: store.selectedTheme.primaryHex),
                                Color(hex: store.selectedTheme.secondaryHex)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text(subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.top, 4)
            }
        }
    }
}

private struct ChatHeader: View {
    @EnvironmentObject private var store: ChatStore
    @Binding var isThemesPresented: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.leaveRoom()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(NebulaIconButtonStyle(theme: store.selectedTheme))
            .accessibilityLabel("Back to rooms")

            AppMark(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(store.currentRoom?.name ?? "Room")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
                }

                Text("\(store.currentRoom?.messages.count ?? 0) messages")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
            }

            Spacer(minLength: 0)

            Button {
                isThemesPresented = true
            } label: {
                Image(systemName: "paintpalette.fill")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(NebulaIconButtonStyle(theme: store.selectedTheme))
            .accessibilityLabel("Themes")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.38))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color(hex: store.selectedTheme.primaryHex).opacity(0.3))
                .frame(height: 1)
        }
    }
}

private struct RoomListView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rooms")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(store.joinedRooms.count) rooms")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
            }

            VStack(spacing: 0) {
                if store.joinedRooms.isEmpty {
                    EmptyRoomsView()
                } else {
                    ForEach(store.joinedRooms) { room in
                        Button {
                            store.openRoom(room)
                        } label: {
                            RoomRow(room: room)
                        }
                        .buttonStyle(.plain)

                        if room.id != store.joinedRooms.last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.08))
                                .padding(.leading, 58)
                        }
                    }
                }
            }
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.24), lineWidth: 1)
            }
        }
    }
}

private struct EmptyRoomsView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.message.fill")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))

            Text("No rooms yet")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)

            Text("Create a room with a name and password, or join one someone already made.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

private struct RoomRow: View {
    @EnvironmentObject private var store: ChatStore
    let room: ChatRoom

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
                .frame(width: 46, height: 46)
                .background(Color(hex: store.selectedTheme.primaryHex).opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(room.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Text(room.messages.last?.body.isEmpty == false ? room.messages.last?.body ?? "No messages yet" : "Removed message")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
        }
        .padding(12)
    }
}

private struct MessageRow: View {
    @EnvironmentObject private var store: ChatStore
    let message: ChatMessage

    private var isMine: Bool {
        message.authorID == store.currentUser?.id
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(isMine ? "You" : message.authorName)
                        .font(.caption.weight(.black))
                        .foregroundStyle(isMine ? Color(hex: store.selectedTheme.primaryHex) : Color(hex: store.selectedTheme.secondaryHex))

                    Text(message.createdAt.chatTime)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if message.state == .removedForEveryone {
                    Text("removed a message")
                        .font(.callout.weight(.semibold).italic())
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    Text(message.body)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(
                            isMine ? Color(hex: store.selectedTheme.bubbleHex).opacity(0.96) : .black.opacity(0.2),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(isMine ? 0.54 : 0.18), lineWidth: 1)
                        }
                        .contextMenu {
                            Button {
                                store.deleteMessageForMe(message)
                            } label: {
                                Label("Delete for me", systemImage: "trash")
                            }

                            if isMine {
                                Button(role: .destructive) {
                                    store.removeMessageForEveryone(message)
                                } label: {
                                    Label("Remove for everyone", systemImage: "trash.slash")
                                }
                            }
                        }
                }
            }
            .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)

            if isMine {
                Menu {
                    Button {
                        store.deleteMessageForMe(message)
                    } label: {
                        Label("Delete for me", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        store.removeMessageForEveryone(message)
                    } label: {
                        Label("Remove for everyone", systemImage: "trash.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            } else {
                Spacer(minLength: 48)
            }
        }
    }
}

private struct ComposerView: View {
    @EnvironmentObject private var store: ChatStore
    @Binding var draft: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "paperclip")
                .font(.title3.weight(.black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))
                .frame(width: 36)

            TextField("Type a message...", text: $draft, axis: .vertical)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                store.sendMessage(draft)
                draft = ""
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3.weight(.black))
                    .frame(width: 46, height: 46)
            }
            .buttonStyle(NebulaCircleButtonStyle(theme: store.selectedTheme))
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.42))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: store.selectedTheme.primaryHex).opacity(0.24))
                .frame(height: 1)
        }
    }
}

private struct ThemeStudioView: View {
    @EnvironmentObject private var store: ChatStore
    @State private var name = ""
    @State private var primary = "#9A4DFF"
    @State private var secondary = "#D83BCE"
    @State private var accent = "#31F477"
    @State private var bubble = "#3A1D64"

    var body: some View {
        NavigationStack {
            ZStack {
                NebulaBackground(theme: store.selectedTheme)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Themes")
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(.white)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                            ForEach(store.allThemes) { theme in
                                Button {
                                    store.selectTheme(theme)
                                } label: {
                                    ThemeTile(theme: theme, isSelected: theme.id == store.selectedTheme.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Create Theme")
                                .font(.headline.weight(.black))
                                .foregroundStyle(.white)

                            NebulaField(title: "Name", text: $name, systemImage: "textformat")
                            HexField(title: "Primary", text: $primary)
                            HexField(title: "Secondary", text: $secondary)
                            HexField(title: "Accent", text: $accent)
                            HexField(title: "Bubble", text: $bubble)

                            Button {
                                store.addCustomTheme(
                                    name: name,
                                    primaryHex: primary,
                                    secondaryHex: secondary,
                                    accentHex: accent,
                                    bubbleHex: bubble
                                )
                                name = ""
                            } label: {
                                Label("Add Theme", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(NebulaPrimaryButtonStyle(theme: store.selectedTheme))
                        }
                        .padding(16)
                        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.24), lineWidth: 1)
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ThemeTile: View {
    let theme: NebulaTheme
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: theme.primaryHex))
                Circle().fill(Color(hex: theme.secondaryHex))
                Circle().fill(Color(hex: theme.accentHex))
            }
            .frame(height: 18)

            Text(theme.name)
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(isSelected ? "Active" : "Tap to use")
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? Color(hex: theme.accentHex) : .white.opacity(0.48))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: theme.primaryHex).opacity(isSelected ? 0.78 : 0.24), lineWidth: isSelected ? 2 : 1)
        }
    }
}

private struct AppMark: View {
    @EnvironmentObject private var store: ChatStore
    let size: CGFloat

    var body: some View {
        Image("NebulaIcon")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: min(size * 0.22, 18), style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: min(size * 0.22, 18), style: .continuous)
                    .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.5), lineWidth: 1)
            }
            .shadow(color: Color(hex: store.selectedTheme.primaryHex).opacity(0.36), radius: 18, y: 8)
    }
}

private struct NebulaField: View {
    @EnvironmentObject private var store: ChatStore
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 22)

                TextField(title, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(0.26), lineWidth: 1)
            }
        }
    }
}

private struct NebulaSecureField: View {
    @EnvironmentObject private var store: ChatStore
    let title: String
    @Binding var text: String
    @Binding var isVisible: Bool
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(Color(hex: store.selectedTheme.primaryHex))

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.56))
                    .frame(width: 22)

                Group {
                    if isVisible {
                        TextField(title, text: $text)
                    } else {
                        SecureField(title, text: $text)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

                Button {
                    isVisible.toggle()
                } label: {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.white.opacity(0.58))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: store.selectedTheme.primaryHex).opacity(text.count > 100 ? 0.9 : 0.26), lineWidth: 1)
            }
        }
    }
}

private struct HexField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: text))
                .frame(width: 22, height: 22)

            Text(title)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 86, alignment: .leading)

            TextField("#9A4DFF", text: $text)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatusText: View {
    let text: String

    var body: some View {
        if text.isEmpty == false {
            Text(text)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NebulaBackground: View {
    let theme: NebulaTheme

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image("NebulaBackdrop")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .opacity(0.7)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color(hex: theme.primaryHex).opacity(0.08),
                    .black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct NebulaPrimaryButtonStyle: ButtonStyle {
    let theme: NebulaTheme
    var isCompact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((isCompact ? Font.subheadline : Font.headline).weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, isCompact ? 14 : 18)
            .frame(minHeight: isCompact ? 42 : 54)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: theme.primaryHex),
                        Color(hex: theme.secondaryHex)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct RoomModeButtonStyle: ButtonStyle {
    let theme: NebulaTheme
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : Color(hex: theme.primaryHex))
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(hex: theme.primaryHex),
                                    Color(hex: theme.secondaryHex)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.black.opacity(0.24))
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: theme.primaryHex).opacity(isSelected ? 0.62 : 0.36), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct NebulaGhostButtonStyle: ButtonStyle {
    let theme: NebulaTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(.white)
            .frame(minHeight: 46)
            .padding(.horizontal, 12)
            .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: theme.primaryHex).opacity(0.42), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct NebulaIconButtonStyle: ButtonStyle {
    let theme: NebulaTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.black))
            .foregroundStyle(Color(hex: theme.primaryHex))
            .frame(height: 42)
            .background(.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(hex: theme.primaryHex).opacity(0.35), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

private struct NebulaCircleButtonStyle: ButtonStyle {
    let theme: NebulaTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: theme.primaryHex),
                        Color(hex: theme.secondaryHex)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ChatStore())
            .preferredColorScheme(.dark)
    }
}
