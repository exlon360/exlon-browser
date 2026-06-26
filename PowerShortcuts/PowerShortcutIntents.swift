import AppIntents
import Foundation
import UIKit
import UniformTypeIdentifiers

struct RunPowerCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run Power Command"
    static var description = IntentDescription("Runs a safe PowerShell-style file or launch command inside a selected root.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Command", default: "ls")
    var command: String

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Working Folder", default: "")
    var workingFolder: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = try PowerCommandRunner.run(command: command, rootName: root, workingDirectory: workingFolder)
        if let url = result.urlToOpen {
            try await ShortcutApplicationLauncher.open(url)
        }
        return .result(value: result.output)
    }
}

struct ListFolderIntent: AppIntent {
    static var title: LocalizedStringResource = "List Files"
    static var description = IntentDescription("Lists files and folders inside an approved root.")

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Folder Path", default: "")
    var folderPath: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try ShortcutFileSystem.shared.formattedList(rootName: root, folderPath: folderPath)
        return .result(value: output)
    }
}

struct CopyShortcutFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Copy File"
    static var description = IntentDescription("Copies a file or folder between approved roots.")

    @Parameter(title: "Source Root", default: ShortcutFileSystem.builtInRootName)
    var sourceRoot: String

    @Parameter(title: "Source Path")
    var sourcePath: String

    @Parameter(title: "Destination Root", default: ShortcutFileSystem.builtInRootName)
    var destinationRoot: String

    @Parameter(title: "Destination Path")
    var destinationPath: String

    @Parameter(title: "Overwrite", default: false)
    var overwrite: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try ShortcutFileSystem.shared.copy(
            sourceRootName: sourceRoot,
            sourcePath: sourcePath,
            destinationRootName: destinationRoot,
            destinationPath: destinationPath,
            overwrite: overwrite
        )
        return .result(value: output)
    }
}

struct MoveShortcutFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Move File"
    static var description = IntentDescription("Moves or renames a file or folder inside approved roots.")

    @Parameter(title: "Source Root", default: ShortcutFileSystem.builtInRootName)
    var sourceRoot: String

    @Parameter(title: "Source Path")
    var sourcePath: String

    @Parameter(title: "Destination Root", default: ShortcutFileSystem.builtInRootName)
    var destinationRoot: String

    @Parameter(title: "Destination Path")
    var destinationPath: String

    @Parameter(title: "Overwrite", default: false)
    var overwrite: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try ShortcutFileSystem.shared.move(
            sourceRootName: sourceRoot,
            sourcePath: sourcePath,
            destinationRootName: destinationRoot,
            destinationPath: destinationPath,
            overwrite: overwrite
        )
        return .result(value: output)
    }
}

struct DeleteShortcutFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Delete File"
    static var description = IntentDescription("Deletes one file, or a folder only when folder deletion is explicitly enabled.")

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Path")
    var path: String

    @Parameter(title: "Allow Folder Delete", default: false)
    var allowFolderDelete: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try ShortcutFileSystem.shared.delete(rootName: root, path: path, allowDirectory: allowFolderDelete)
        return .result(value: output)
    }
}

struct ImportShortcutFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Import File"
    static var description = IntentDescription("Writes a Shortcuts file input into an approved root.")

    @Parameter(title: "File")
    var file: IntentFile

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Destination Path", default: "")
    var destinationPath: String

    @Parameter(title: "Overwrite", default: false)
    var overwrite: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let filename = file.filename ?? "ShortcutFile"
        let path = try ShortcutFileSystem.shared.destinationPath(for: destinationPath, fallbackFilename: filename)
        try ShortcutFileSystem.shared.writeData(rootName: root, path: path, data: file.data, overwrite: overwrite)
        return .result(value: "Imported \(path)")
    }
}

struct ExportShortcutFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Export File"
    static var description = IntentDescription("Returns a file from an approved root to the Shortcut.")

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Path")
    var path: String

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let result = try ShortcutFileSystem.shared.readData(rootName: root, path: path)
        let fileExtension = URL(fileURLWithPath: result.filename).pathExtension
        let type = UTType(filenameExtension: fileExtension) ?? .data
        let file = IntentFile(data: result.data, filename: result.filename, type: type)
        return .result(value: file)
    }
}

struct ReadTextFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Text File"
    static var description = IntentDescription("Reads a UTF-8 text file from an approved root.")

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Path")
    var path: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let text = try ShortcutFileSystem.shared.readText(rootName: root, path: path)
        return .result(value: text)
    }
}

struct WriteTextFileIntent: AppIntent {
    static var title: LocalizedStringResource = "Write Text File"
    static var description = IntentDescription("Writes UTF-8 text into an approved root.")

    @Parameter(title: "Root", default: ShortcutFileSystem.builtInRootName)
    var root: String

    @Parameter(title: "Path")
    var path: String

    @Parameter(title: "Text")
    var text: String

    @Parameter(title: "Overwrite", default: false)
    var overwrite: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let output = try ShortcutFileSystem.shared.writeText(rootName: root, path: path, text: text, overwrite: overwrite)
        return .result(value: output)
    }
}

struct OpenAppURLIntent: AppIntent {
    static var title: LocalizedStringResource = "Open App or URL"
    static var description = IntentDescription("Opens an app URL scheme or web URL.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "URL or App Scheme")
    var target: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let url = try ShortcutApplicationLauncher.url(from: target)
        try await ShortcutApplicationLauncher.open(url)
        return .result(value: "Opened \(url.absoluteString)")
    }
}

struct PowerShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RunPowerCommandIntent(),
            phrases: [
                "Run a command in \(.applicationName)",
                "Power command with \(.applicationName)"
            ],
            shortTitle: "Run Command",
            systemImageName: "terminal"
        )
        AppShortcut(
            intent: ListFolderIntent(),
            phrases: [
                "List files in \(.applicationName)",
                "Show files with \(.applicationName)"
            ],
            shortTitle: "List Files",
            systemImageName: "folder"
        )
        AppShortcut(
            intent: CopyShortcutFileIntent(),
            phrases: [
                "Copy a file with \(.applicationName)"
            ],
            shortTitle: "Copy File",
            systemImageName: "doc.on.doc"
        )
        AppShortcut(
            intent: MoveShortcutFileIntent(),
            phrases: [
                "Move a file with \(.applicationName)"
            ],
            shortTitle: "Move File",
            systemImageName: "arrow.right.doc.on.clipboard"
        )
        AppShortcut(
            intent: DeleteShortcutFileIntent(),
            phrases: [
                "Delete a file with \(.applicationName)"
            ],
            shortTitle: "Delete File",
            systemImageName: "trash"
        )
        AppShortcut(
            intent: OpenAppURLIntent(),
            phrases: [
                "Open an app with \(.applicationName)",
                "Open a URL with \(.applicationName)"
            ],
            shortTitle: "Open URL",
            systemImageName: "arrow.up.forward.app"
        )
    }
}

extension ShortcutApplicationLauncher {
    @MainActor
    static func open(_ url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PowerShortcutError.invalidURL(url.absoluteString))
                }
            }
        }
    }
}
