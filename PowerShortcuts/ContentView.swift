import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PowerShortcutsViewModel: ObservableObject {
    @Published var roots: [ShortcutRoot] = []
    @Published var selectedRootName = ShortcutFileSystem.builtInRootName
    @Published var currentPath = ""
    @Published var entries: [ShortcutFileEntry] = []
    @Published var command = "ls"
    @Published var output = ""
    @Published var errorMessage: String?

    init() {
        reloadRoots()
        reloadEntries()
    }

    func reloadRoots() {
        roots = ShortcutFileSystem.shared.roots()
        if roots.contains(where: { $0.name == selectedRootName }) == false {
            selectedRootName = ShortcutFileSystem.builtInRootName
        }
    }

    func selectRoot(_ root: ShortcutRoot) {
        selectedRootName = root.name
        currentPath = ""
        reloadEntries()
    }

    func open(_ entry: ShortcutFileEntry) {
        guard entry.isDirectory else {
            output = entry.path
            return
        }
        currentPath = entry.path
        reloadEntries()
    }

    func goUp() {
        guard currentPath.isEmpty == false else { return }
        let parts = currentPath.split(separator: "/").dropLast()
        currentPath = parts.joined(separator: "/")
        reloadEntries()
    }

    func reloadEntries() {
        do {
            entries = try ShortcutFileSystem.shared.list(rootName: selectedRootName, folderPath: currentPath)
            errorMessage = nil
        } catch {
            entries = []
            errorMessage = error.localizedDescription
        }
    }

    func runCommand() {
        do {
            let result = try PowerCommandRunner.run(command: command, rootName: selectedRootName, workingDirectory: currentPath)
            output = result.output
            if result.urlToOpen != nil {
                output += "\nRun app-opening commands from Shortcuts."
            }
            reloadEntries()
        } catch {
            output = error.localizedDescription
        }
    }

    func delete(_ entry: ShortcutFileEntry) {
        do {
            output = try ShortcutFileSystem.shared.delete(rootName: selectedRootName, path: entry.path, allowDirectory: entry.isDirectory)
            reloadEntries()
        } catch {
            output = error.localizedDescription
        }
    }

    func remove(_ root: ShortcutRoot) {
        guard root.isBuiltIn == false else { return }
        ShortcutFileSystem.shared.removeRoot(id: root.id)
        reloadRoots()
        reloadEntries()
    }
}

struct ContentView: View {
    @StateObject private var model = PowerShortcutsViewModel()
    @State private var isPickingFolder = false
    @State private var pendingDelete: ShortcutFileEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                rootStrip

                List {
                    Section {
                        ForEach(model.entries) { entry in
                            Button {
                                model.open(entry)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc.fill")
                                        .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                                        .frame(width: 26)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.name)
                                            .font(.body)
                                            .lineLimit(1)
                                        Text(entry.path)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(entry.displaySize)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(model.currentPath.isEmpty ? "/" : "/\(model.currentPath)")
                            Spacer()
                            Text(model.selectedRootName)
                        }
                    }

                    Section("Command") {
                        HStack {
                            TextField("ls", text: $model.command)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(.body, design: .monospaced))
                            Button {
                                model.runCommand()
                            } label: {
                                Image(systemName: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("Run")
                        }

                        if model.output.isEmpty == false {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(model.output)
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("PowerShortcuts")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        model.goUp()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(model.currentPath.isEmpty)
                    .accessibilityLabel("Up")
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        isPickingFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityLabel("Add Folder")

                    Button {
                        model.reloadRoots()
                        model.reloadEntries()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                }
            }
            .fileImporter(
                isPresented: $isPickingFolder,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let url = try result.get().first else { return }
                    try ShortcutFileSystem.shared.addSecurityScopedRoot(url)
                    model.reloadRoots()
                    model.reloadEntries()
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
            .alert("Delete?", isPresented: deleteAlertBinding, presenting: pendingDelete) { entry in
                Button("Delete", role: .destructive) {
                    model.delete(entry)
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDelete = nil
                }
            } message: { entry in
                Text(entry.path)
            }
            .alert("PowerShortcuts", isPresented: errorAlertBinding) {
                Button("OK", role: .cancel) {
                    model.errorMessage = nil
                }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }

    private var rootStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.roots) { root in
                    Menu {
                        Button {
                            model.selectRoot(root)
                        } label: {
                            Label("Open", systemImage: "folder")
                        }

                        if root.isBuiltIn == false {
                            Button(role: .destructive) {
                                model.remove(root)
                            } label: {
                                Label("Forget", systemImage: "xmark")
                            }
                        }
                    } label: {
                        Label(root.name, systemImage: root.isBuiltIn ? "internaldrive" : "folder")
                            .labelStyle(.titleAndIcon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(root.name == model.selectedRootName ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDelete = nil
                }
            }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { isPresented in
                if isPresented == false {
                    model.errorMessage = nil
                }
            }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
