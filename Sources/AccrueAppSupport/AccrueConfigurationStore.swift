import AccrueCore
import Combine
import Foundation
import SwiftData

@MainActor
public final class AccrueConfigurationStore: ObservableObject {
    @Published public private(set) var configuration: AccrueConfiguration?

    private let container: ModelContainer

    public init(container: ModelContainer? = nil) throws {
        self.container = try container ?? ModelContainer(for: StoredAccrueConfiguration.self)
        configuration = try loadStoredConfiguration()?.toCoreConfiguration()
    }

    public func save(_ draft: AccrueSetupDraft) throws {
        let context = container.mainContext
        let stored = try loadStoredConfiguration() ?? StoredAccrueConfiguration()

        stored.apply(draft)

        if stored.modelContext == nil {
            context.insert(stored)
        }

        try context.save()
        configuration = stored.toCoreConfiguration()
    }

    private func loadStoredConfiguration() throws -> StoredAccrueConfiguration? {
        var descriptor = FetchDescriptor<StoredAccrueConfiguration>()
        descriptor.fetchLimit = 1
        return try container.mainContext.fetch(descriptor).first
    }
}
