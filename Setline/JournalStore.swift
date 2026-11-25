import Foundation

@MainActor
struct JournalStore {
    let url: URL

    static func applicationStore() -> JournalStore {
        #if DEBUG
        let process = ProcessInfo.processInfo
        if process.arguments.contains("-ui-testing") {
            let runID = process.environment["SETLINE_TEST_STORE"].flatMap(UUID.init(uuidString:)) ?? UUID()
            return JournalStore(url: FileManager.default.temporaryDirectory
                .appendingPathComponent(runID.uuidString, isDirectory: true)
                .appendingPathComponent("journal.json"))
        }
        #endif
        return JournalStore(url: URL.applicationSupportDirectory
            .appendingPathComponent("Setline", isDirectory: true)
            .appendingPathComponent("journal.json"))
    }

    func load() throws -> JournalSnapshot {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return JournalSnapshot()
        }
        return try JSONDecoder().decode(JournalSnapshot.self, from: data)
    }

    func save(_ snapshot: JournalSnapshot) throws {
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }
}
