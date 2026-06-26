import Foundation

struct ShortcutRoot: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var bookmarkData: Data?
    var isBuiltIn: Bool
}

struct ShortcutFileEntry: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var path: String
    var isDirectory: Bool
    var size: Int64?
    var modified: Date?

    var displaySize: String {
        guard let size, isDirectory == false else { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

struct PowerCommandResult {
    var output: String
    var urlToOpen: URL?
}

enum PowerShortcutError: LocalizedError {
    case rootUnavailable(String)
    case rootNotFound(String)
    case unsafePath(String)
    case fileNotFound(String)
    case notADirectory(String)
    case directoryRequiresConfirmation(String)
    case destinationExists(String)
    case textEncodingFailed(String)
    case invalidCommand(String)
    case invalidURL(String)
    case destructiveOperationRefused(String)

    var errorDescription: String? {
        switch self {
        case .rootUnavailable(let message):
            return message
        case .rootNotFound(let root):
            return "Root not found: \(root)"
        case .unsafePath(let message):
            return message
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .notADirectory(let path):
            return "Not a folder: \(path)"
        case .directoryRequiresConfirmation(let path):
            return "Folder deletion needs Allow Folder Delete enabled: \(path)"
        case .destinationExists(let path):
            return "Destination already exists: \(path)"
        case .textEncodingFailed(let path):
            return "Could not read UTF-8 text from \(path)"
        case .invalidCommand(let message):
            return message
        case .invalidURL(let url):
            return "Could not open URL or app scheme: \(url)"
        case .destructiveOperationRefused(let message):
            return message
        }
    }
}

final class ShortcutFileSystem {
    static let shared = ShortcutFileSystem()
    static let builtInRootName = "App Documents"

    private let storageKey = "PowerShortcuts.SecurityScopedRoots.v1"
    private let fileManager = FileManager.default

    private init() {}

    func roots() -> [ShortcutRoot] {
        let builtIn = ShortcutRoot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            name: Self.builtInRootName,
            bookmarkData: nil,
            isBuiltIn: true
        )
        return [builtIn] + storedRoots()
    }

    func addSecurityScopedRoot(_ url: URL) throws {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let bookmark = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        var existing = storedRoots()
        let baseName = url.lastPathComponent.isEmpty ? "Files Root" : url.lastPathComponent
        let name = uniqueRootName(baseName, in: existing)
        existing.append(ShortcutRoot(id: UUID(), name: name, bookmarkData: bookmark, isBuiltIn: false))
        save(roots: existing)
    }

    func removeRoot(id: UUID) {
        let filtered = storedRoots().filter { $0.id != id }
        save(roots: filtered)
    }

    func list(rootName: String, folderPath: String) throws -> [ShortcutFileEntry] {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: folderPath, allowEmpty: true)
            var isDirectory = ObjCBool(false)
            guard fileManager.fileExists(atPath: target.url.path, isDirectory: &isDirectory) else {
                throw PowerShortcutError.fileNotFound(target.normalizedPath)
            }
            guard isDirectory.boolValue else {
                throw PowerShortcutError.notADirectory(target.normalizedPath)
            }

            let keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
            let urls = try fileManager.contentsOfDirectory(at: target.url, includingPropertiesForKeys: Array(keys), options: [])
            let prefix = target.normalizedPath.isEmpty ? "" : "\(target.normalizedPath)/"

            return try urls.map { url in
                let values = try url.resourceValues(forKeys: keys)
                let childPath = "\(prefix)\(url.lastPathComponent)"
                return ShortcutFileEntry(
                    name: url.lastPathComponent,
                    path: childPath,
                    isDirectory: values.isDirectory ?? false,
                    size: values.fileSize.map(Int64.init),
                    modified: values.contentModificationDate
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory {
                    return lhs.isDirectory
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    func formattedList(rootName: String, folderPath: String) throws -> String {
        let entries = try list(rootName: rootName, folderPath: folderPath)
        guard entries.isEmpty == false else { return "(empty)" }
        return entries.map { entry in
            let kind = entry.isDirectory ? "d" : "-"
            return "\(kind) \(entry.displaySize) \(entry.path)"
        }
        .joined(separator: "\n")
    }

    func makeDirectory(rootName: String, folderPath: String) throws -> String {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: folderPath, allowEmpty: false)
            try fileManager.createDirectory(at: target.url, withIntermediateDirectories: true)
            return "Created folder \(target.normalizedPath)"
        }
    }

    func copy(sourceRootName: String, sourcePath: String, destinationRootName: String, destinationPath: String, overwrite: Bool) throws -> String {
        let sourceRoot = try resolveRoot(named: sourceRootName)
        let destinationRoot = try resolveRoot(named: destinationRootName)
        defer {
            sourceRoot.stop()
            destinationRoot.stop()
        }

        let source = try resolvedChildURL(rootURL: sourceRoot.url, path: sourcePath, allowEmpty: false)
        guard fileManager.fileExists(atPath: source.url.path) else {
            throw PowerShortcutError.fileNotFound(source.normalizedPath)
        }

        var destination = try resolvedChildURL(rootURL: destinationRoot.url, path: destinationPath, allowEmpty: false)
        var destinationIsDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: destination.url.path, isDirectory: &destinationIsDirectory), destinationIsDirectory.boolValue {
            destination = try resolvedChildURL(
                rootURL: destinationRoot.url,
                path: "\(destination.normalizedPath)/\(source.url.lastPathComponent)",
                allowEmpty: false
            )
        }

        try createParentDirectory(for: destination.url)
        if fileManager.fileExists(atPath: destination.url.path) {
            guard overwrite else { throw PowerShortcutError.destinationExists(destination.normalizedPath) }
            try guardedRemove(url: destination.url, rootURL: destinationRoot.url, normalizedPath: destination.normalizedPath, allowDirectory: true)
        }

        try fileManager.copyItem(at: source.url, to: destination.url)
        return "Copied \(source.normalizedPath) to \(destination.normalizedPath)"
    }

    func move(sourceRootName: String, sourcePath: String, destinationRootName: String, destinationPath: String, overwrite: Bool) throws -> String {
        let sourceRoot = try resolveRoot(named: sourceRootName)
        let destinationRoot = try resolveRoot(named: destinationRootName)
        defer {
            sourceRoot.stop()
            destinationRoot.stop()
        }

        let source = try resolvedChildURL(rootURL: sourceRoot.url, path: sourcePath, allowEmpty: false)
        guard fileManager.fileExists(atPath: source.url.path) else {
            throw PowerShortcutError.fileNotFound(source.normalizedPath)
        }

        var destination = try resolvedChildURL(rootURL: destinationRoot.url, path: destinationPath, allowEmpty: false)
        var destinationIsDirectory = ObjCBool(false)
        if fileManager.fileExists(atPath: destination.url.path, isDirectory: &destinationIsDirectory), destinationIsDirectory.boolValue {
            destination = try resolvedChildURL(
                rootURL: destinationRoot.url,
                path: "\(destination.normalizedPath)/\(source.url.lastPathComponent)",
                allowEmpty: false
            )
        }

        try createParentDirectory(for: destination.url)
        if fileManager.fileExists(atPath: destination.url.path) {
            guard overwrite else { throw PowerShortcutError.destinationExists(destination.normalizedPath) }
            try guardedRemove(url: destination.url, rootURL: destinationRoot.url, normalizedPath: destination.normalizedPath, allowDirectory: true)
        }

        try fileManager.moveItem(at: source.url, to: destination.url)
        return "Moved \(source.normalizedPath) to \(destination.normalizedPath)"
    }

    func delete(rootName: String, path: String, allowDirectory: Bool) throws -> String {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: path, allowEmpty: false)
            try guardedRemove(url: target.url, rootURL: rootURL, normalizedPath: target.normalizedPath, allowDirectory: allowDirectory)
            return "Deleted \(target.normalizedPath)"
        }
    }

    func readText(rootName: String, path: String) throws -> String {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: path, allowEmpty: false)
            guard fileManager.fileExists(atPath: target.url.path) else {
                throw PowerShortcutError.fileNotFound(target.normalizedPath)
            }
            let data = try Data(contentsOf: target.url)
            guard let text = String(data: data, encoding: .utf8) else {
                throw PowerShortcutError.textEncodingFailed(target.normalizedPath)
            }
            return text
        }
    }

    func writeText(rootName: String, path: String, text: String, overwrite: Bool) throws -> String {
        let data = Data(text.utf8)
        try writeData(rootName: rootName, path: path, data: data, overwrite: overwrite)
        return "Wrote \(path)"
    }

    func appendText(rootName: String, path: String, text: String) throws -> String {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: path, allowEmpty: false)
            try createParentDirectory(for: target.url)
            if fileManager.fileExists(atPath: target.url.path) == false {
                try Data().write(to: target.url)
            }
            let handle = try FileHandle(forWritingTo: target.url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
            return "Appended \(target.normalizedPath)"
        }
    }

    func readData(rootName: String, path: String) throws -> (data: Data, filename: String) {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: path, allowEmpty: false)
            guard fileManager.fileExists(atPath: target.url.path) else {
                throw PowerShortcutError.fileNotFound(target.normalizedPath)
            }
            return (try Data(contentsOf: target.url), target.url.lastPathComponent)
        }
    }

    func writeData(rootName: String, path: String, data: Data, overwrite: Bool) throws {
        try withResolvedRoot(named: rootName) { rootURL in
            let target = try resolvedChildURL(rootURL: rootURL, path: path, allowEmpty: false)
            try createParentDirectory(for: target.url)
            if fileManager.fileExists(atPath: target.url.path) {
                guard overwrite else { throw PowerShortcutError.destinationExists(target.normalizedPath) }
            }
            try data.write(to: target.url, options: .atomic)
        }
    }

    func destinationPath(for rawDestination: String, fallbackFilename: String) throws -> String {
        let trimmed = rawDestination.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFilename = safeFilename(fallbackFilename)
        if trimmed.isEmpty {
            return cleanFilename
        }
        if trimmed.hasSuffix("/") || trimmed.hasSuffix("\\") {
            return "\(trimmed)\(cleanFilename)"
        }
        return trimmed
    }

    func normalizedRelativePath(_ rawPath: String, allowEmpty: Bool) throws -> String {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let unixPath = trimmed.replacingOccurrences(of: "\\", with: "/")

        if unixPath.isEmpty || unixPath == "." {
            if allowEmpty { return "" }
            throw PowerShortcutError.unsafePath("Choose a file or folder path; the root itself is protected.")
        }
        if unixPath.hasPrefix("/") || unixPath.hasPrefix("~") {
            throw PowerShortcutError.unsafePath("Use a path relative to the selected root.")
        }
        if unixPath.contains("*") || unixPath.contains("?") {
            throw PowerShortcutError.unsafePath("Wildcards are blocked so a Shortcut cannot target every file at once.")
        }
        if unixPath.contains(":") {
            throw PowerShortcutError.unsafePath("Use relative file paths here, not drive names or URLs.")
        }

        var components: [String] = []
        for part in unixPath.split(separator: "/", omittingEmptySubsequences: true) {
            let component = String(part)
            if component == "." {
                continue
            }
            if component == ".." {
                throw PowerShortcutError.unsafePath("Parent folder references are blocked.")
            }
            components.append(component)
        }

        if components.isEmpty {
            if allowEmpty { return "" }
            throw PowerShortcutError.unsafePath("Choose a file or folder path; the root itself is protected.")
        }
        return components.joined(separator: "/")
    }

    private func storedRoots() -> [ShortcutRoot] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([ShortcutRoot].self, from: data)) ?? []
    }

    private func save(roots: [ShortcutRoot]) {
        guard let data = try? JSONEncoder().encode(roots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func uniqueRootName(_ proposed: String, in roots: [ShortcutRoot]) -> String {
        let used = Set((roots + self.roots()).map(\.name))
        if used.contains(proposed) == false {
            return proposed
        }

        var index = 2
        while used.contains("\(proposed) \(index)") {
            index += 1
        }
        return "\(proposed) \(index)"
    }

    private func documentRootURL() throws -> URL {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw PowerShortcutError.rootUnavailable("The app Documents folder is unavailable.")
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private struct ResolvedRoot {
        var url: URL
        var didStartAccess: Bool

        func stop() {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    private func resolveRoot(named name: String) throws -> ResolvedRoot {
        let requested = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if requested.isEmpty || requested == Self.builtInRootName {
            return ResolvedRoot(url: try documentRootURL(), didStartAccess: false)
        }

        guard let root = storedRoots().first(where: { $0.name == requested }) else {
            throw PowerShortcutError.rootNotFound(requested)
        }
        guard let bookmarkData = root.bookmarkData else {
            throw PowerShortcutError.rootUnavailable("Root \(root.name) does not have a Files bookmark.")
        }

        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        let didStart = url.startAccessingSecurityScopedResource()
        return ResolvedRoot(url: url, didStartAccess: didStart)
    }

    private func withResolvedRoot<T>(named name: String, body: (URL) throws -> T) throws -> T {
        let resolved = try resolveRoot(named: name)
        defer { resolved.stop() }
        return try body(resolved.url)
    }

    private func resolvedChildURL(rootURL: URL, path: String, allowEmpty: Bool) throws -> (url: URL, normalizedPath: String) {
        let normalized = try normalizedRelativePath(path, allowEmpty: allowEmpty)
        let base = rootURL.standardizedFileURL
        let target = normalized.isEmpty ? base : base.appendingPathComponent(normalized)
        try verify(url: target, staysInside: base)
        return (target, normalized)
    }

    private func verify(url: URL, staysInside rootURL: URL) throws {
        let rootPath = rootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let targetPath = url.standardizedFileURL.path
        guard targetPath == rootPath || targetPath.hasPrefix(rootPath + "/") else {
            throw PowerShortcutError.unsafePath("The requested path escapes the selected root.")
        }
    }

    private func createParentDirectory(for url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
    }

    private func guardedRemove(url: URL, rootURL: URL, normalizedPath: String, allowDirectory: Bool) throws {
        try verify(url: url.resolvingSymlinksInPath(), staysInside: rootURL)
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw PowerShortcutError.fileNotFound(normalizedPath)
        }
        guard normalizedPath.isEmpty == false else {
            throw PowerShortcutError.destructiveOperationRefused("Deleting a root folder is blocked.")
        }
        if isDirectory.boolValue {
            guard allowDirectory else {
                throw PowerShortcutError.directoryRequiresConfirmation(normalizedPath)
            }
            let immediateItems = (try? fileManager.contentsOfDirectory(atPath: url.path).count) ?? 0
            if immediateItems > 250 {
                throw PowerShortcutError.destructiveOperationRefused("Refusing to delete \(normalizedPath) because it contains more than 250 immediate items.")
            }
        }
        try fileManager.removeItem(at: url)
    }

    private func safeFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = trimmed.replacingOccurrences(of: "\\", with: "/").split(separator: "/").last.map(String.init)
        let candidate = last?.isEmpty == false ? last ?? "ShortcutFile" : "ShortcutFile"
        return candidate.replacingOccurrences(of: ":", with: "-")
    }
}

enum PowerCommandRunner {
    static func run(command: String, rootName: String, workingDirectory: String) throws -> PowerCommandResult {
        let tokens = try tokenize(command)
        guard let first = tokens.first else {
            throw PowerShortcutError.invalidCommand("Enter a command.")
        }

        let commandName = first.lowercased()
        let arguments = Array(tokens.dropFirst())
        let fs = ShortcutFileSystem.shared

        switch commandName {
        case "help":
            return PowerCommandResult(output: helpText, urlToOpen: nil)
        case "pwd", "get-location":
            let path = try fs.normalizedRelativePath(workingDirectory, allowEmpty: true)
            return PowerCommandResult(output: path.isEmpty ? "/" : "/\(path)", urlToOpen: nil)
        case "ls", "dir", "gci", "get-childitem", "get-child-item":
            let path = try pathArgument(from: arguments, workingDirectory: workingDirectory)
            return PowerCommandResult(output: try fs.formattedList(rootName: rootName, folderPath: path), urlToOpen: nil)
        case "mkdir", "md":
            let path = try requiredPathArgument(from: arguments, workingDirectory: workingDirectory, command: first)
            return PowerCommandResult(output: try fs.makeDirectory(rootName: rootName, folderPath: path), urlToOpen: nil)
        case "new-item":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard let rawPath = positional.first else {
                throw PowerShortcutError.invalidCommand("New-Item needs a path.")
            }
            let path = try resolve(rawPath, workingDirectory: workingDirectory)
            if optionValue(arguments, name: "-itemtype")?.lowercased() == "file" {
                return PowerCommandResult(output: try fs.writeText(rootName: rootName, path: path, text: "", overwrite: false), urlToOpen: nil)
            }
            return PowerCommandResult(output: try fs.makeDirectory(rootName: rootName, folderPath: path), urlToOpen: nil)
        case "cp", "copy", "copy-item":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard positional.count >= 2 else {
                throw PowerShortcutError.invalidCommand("\(first) needs source and destination paths.")
            }
            let source = try resolve(positional[0], workingDirectory: workingDirectory)
            let destination = try resolve(positional[1], workingDirectory: workingDirectory)
            let overwrite = hasOption(arguments, "-force")
            return PowerCommandResult(
                output: try fs.copy(sourceRootName: rootName, sourcePath: source, destinationRootName: rootName, destinationPath: destination, overwrite: overwrite),
                urlToOpen: nil
            )
        case "mv", "move", "move-item":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard positional.count >= 2 else {
                throw PowerShortcutError.invalidCommand("\(first) needs source and destination paths.")
            }
            let source = try resolve(positional[0], workingDirectory: workingDirectory)
            let destination = try resolve(positional[1], workingDirectory: workingDirectory)
            let overwrite = hasOption(arguments, "-force")
            return PowerCommandResult(
                output: try fs.move(sourceRootName: rootName, sourcePath: source, destinationRootName: rootName, destinationPath: destination, overwrite: overwrite),
                urlToOpen: nil
            )
        case "rm", "del", "remove-item":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard let rawPath = positional.first else {
                throw PowerShortcutError.invalidCommand("\(first) needs a path.")
            }
            let path = try resolve(rawPath, workingDirectory: workingDirectory)
            let allowDirectory = hasOption(arguments, "-recurse") || hasOption(arguments, "-directory")
            return PowerCommandResult(output: try fs.delete(rootName: rootName, path: path, allowDirectory: allowDirectory), urlToOpen: nil)
        case "cat", "type", "get-content":
            let path = try requiredPathArgument(from: arguments, workingDirectory: workingDirectory, command: first)
            return PowerCommandResult(output: try fs.readText(rootName: rootName, path: path), urlToOpen: nil)
        case "set-content", "write":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard positional.count >= 2 else {
                throw PowerShortcutError.invalidCommand("\(first) needs a path and text.")
            }
            let path = try resolve(positional[0], workingDirectory: workingDirectory)
            let text = positional.dropFirst().joined(separator: " ")
            let overwrite = hasOption(arguments, "-force")
            return PowerCommandResult(output: try fs.writeText(rootName: rootName, path: path, text: text, overwrite: overwrite), urlToOpen: nil)
        case "add-content":
            let positional = arguments.filter { $0.hasPrefix("-") == false }
            guard positional.count >= 2 else {
                throw PowerShortcutError.invalidCommand("Add-Content needs a path and text.")
            }
            let path = try resolve(positional[0], workingDirectory: workingDirectory)
            let text = positional.dropFirst().joined(separator: " ")
            return PowerCommandResult(output: try fs.appendText(rootName: rootName, path: path, text: text), urlToOpen: nil)
        case "open", "start", "start-process":
            guard let rawURL = arguments.first else {
                throw PowerShortcutError.invalidCommand("\(first) needs a URL or app scheme.")
            }
            let url = try ShortcutApplicationLauncher.url(from: rawURL)
            return PowerCommandResult(output: "Opening \(url.absoluteString)", urlToOpen: url)
        default:
            throw PowerShortcutError.invalidCommand("Unsupported command: \(first). Try help.")
        }
    }

    private static var helpText: String {
        """
        Commands: ls, pwd, mkdir, cp, mv, rm, cat, write, open
        PowerShell names: Get-ChildItem, Get-Location, New-Item, Copy-Item, Move-Item, Remove-Item, Get-Content, Set-Content, Add-Content, Start-Process
        Safety: paths stay inside the selected root, wildcards are blocked, and folder delete needs -Recurse.
        """
    }

    private static func tokenize(_ command: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?

        for character in command {
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character.unicodeScalars.allSatisfy({ CharacterSet.whitespacesAndNewlines.contains($0) }) {
                if current.isEmpty == false {
                    tokens.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if quote != nil {
            throw PowerShortcutError.invalidCommand("Close the quoted string before running the command.")
        }
        if current.isEmpty == false {
            tokens.append(current)
        }
        return tokens
    }

    private static func pathArgument(from arguments: [String], workingDirectory: String) throws -> String {
        guard let raw = arguments.first(where: { $0.hasPrefix("-") == false }) else {
            return try ShortcutFileSystem.shared.normalizedRelativePath(workingDirectory, allowEmpty: true)
        }
        return try resolve(raw, workingDirectory: workingDirectory)
    }

    private static func requiredPathArgument(from arguments: [String], workingDirectory: String, command: String) throws -> String {
        guard let raw = arguments.first(where: { $0.hasPrefix("-") == false }) else {
            throw PowerShortcutError.invalidCommand("\(command) needs a path.")
        }
        return try resolve(raw, workingDirectory: workingDirectory)
    }

    private static func resolve(_ rawPath: String, workingDirectory: String) throws -> String {
        let fs = ShortcutFileSystem.shared
        let working = try fs.normalizedRelativePath(workingDirectory, allowEmpty: true)
        if rawPath == "." {
            return working
        }
        let combined = working.isEmpty ? rawPath : "\(working)/\(rawPath)"
        return try fs.normalizedRelativePath(combined, allowEmpty: true)
    }

    private static func hasOption(_ arguments: [String], _ name: String) -> Bool {
        arguments.contains { $0.lowercased() == name.lowercased() }
    }

    private static func optionValue(_ arguments: [String], name: String) -> String? {
        guard let index = arguments.firstIndex(where: { $0.lowercased() == name.lowercased() }) else {
            return nil
        }
        let nextIndex = arguments.index(after: index)
        guard nextIndex < arguments.endIndex else { return nil }
        return arguments[nextIndex]
    }
}

enum ShortcutApplicationLauncher {
    static func url(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw PowerShortcutError.invalidURL(rawValue)
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        if trimmed.contains(".") {
            let prefixed = "https://\(trimmed)"
            if let url = URL(string: prefixed) {
                return url
            }
        }
        throw PowerShortcutError.invalidURL(rawValue)
    }
}
