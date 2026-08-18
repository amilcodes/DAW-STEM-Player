import Foundation

final class ProjectStore {
    enum StoreError: LocalizedError {
        case invalidPackage
        case unsupportedSchema(Int)

        var errorDescription: String? {
            switch self {
            case .invalidPackage: "This folder is not a valid Stem Player project."
            case .unsupportedSchema(let version): "This project uses unsupported schema version \(version)."
            }
        }
    }

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var applicationSupportURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Stem Player", isDirectory: true)
    }

    var autosaveURL: URL {
        applicationSupportURL
            .appendingPathComponent("Sessions", isDirectory: true)
            .appendingPathComponent("Autosave.stemproject", isDirectory: true)
    }

    func preparePackage(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        for name in ["Audio", "Samples", "Recordings", "Waveforms", "Analysis"] {
            try fileManager.createDirectory(
                at: url.appendingPathComponent(name, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    func save(_ project: StemProject, to packageURL: URL) throws {
        try preparePackage(at: packageURL)
        var updated = project
        updated.modifiedAt = Date()
        updated.schemaVersion = StemProject.currentSchemaVersion
        let data = try encoder.encode(updated)
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        try data.write(to: manifestURL, options: .atomic)
    }

    func load(from packageURL: URL) throws -> StemProject {
        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { throw StoreError.invalidPackage }
        let data = try Data(contentsOf: manifestURL)
        let project = try decoder.decode(StemProject.self, from: data)
        guard project.schemaVersion <= StemProject.currentSchemaVersion else {
            throw StoreError.unsupportedSchema(project.schemaVersion)
        }
        return project
    }

    func copyAsset(_ sourceURL: URL, into packageURL: URL, folder: String) throws -> String {
        let extensionPart = sourceURL.pathExtension.isEmpty ? "audio" : sourceURL.pathExtension.lowercased()
        let filename = "\(UUID().uuidString).\(extensionPart)"
        let relativePath = "\(folder)/\(filename)"
        let destination = packageURL.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return relativePath
    }

    func resolve(_ relativePath: String, in packageURL: URL) -> URL {
        packageURL.appendingPathComponent(relativePath)
    }

    func removeAsset(_ relativePath: String, in packageURL: URL) throws {
        let url = resolve(relativePath, in: packageURL)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }
}
