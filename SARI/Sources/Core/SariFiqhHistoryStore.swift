import Foundation
import Combine

struct SariFiqhStoredTurn: Codable, Identifiable {
    let id: UUID
    let question: String
    let answer: FiqhServerAnswer
    let createdAt: Date

    init(question: String, answer: FiqhServerAnswer) {
        self.id = UUID()
        self.question = question
        self.answer = answer
        self.createdAt = Date()
    }
}

struct SariFiqhConversation: Codable, Identifiable {
    let id: UUID
    var createdAt: Date
    var updatedAt: Date
    var turns: [SariFiqhStoredTurn]

    var preview: String {
        turns.last?.question ?? ""
    }
}

/// Stores conversation history locally. Persisted turns are never injected into a
/// new inference prompt automatically, so keeping history cannot grow the model
/// context or recreate the prompt-overflow crash.
@MainActor
final class SariFiqhHistoryStore: ObservableObject {
    static let shared = SariFiqhHistoryStore()

    @Published private(set) var conversations: [SariFiqhConversation] = []
    @Published private(set) var currentConversationID: UUID

    private let fm = FileManager.default
    private let maxConversations = 40
    private let maxTurnsPerConversation = 100

    private var fileURL: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SARI/FiqhHistory/conversations.json")
    }

    private init() {
        let fallbackID = UUID()
        currentConversationID = fallbackID

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([SariFiqhConversation].self, from: data),
           !decoded.isEmpty {
            conversations = decoded
            currentConversationID = decoded.first?.id ?? fallbackID
        } else {
            conversations = [
                SariFiqhConversation(
                    id: fallbackID,
                    createdAt: Date(),
                    updatedAt: Date(),
                    turns: []
                )
            ]
        }
    }

    var currentTurns: [SariFiqhStoredTurn] {
        conversations.first(where: { $0.id == currentConversationID })?.turns ?? []
    }

    func append(question: String, answer: FiqhServerAnswer) {
        ensureCurrentConversation()
        guard let index = conversations.firstIndex(where: { $0.id == currentConversationID }) else { return }

        conversations[index].turns.append(.init(question: question, answer: answer))
        if conversations[index].turns.count > maxTurnsPerConversation {
            conversations[index].turns.removeFirst(
                conversations[index].turns.count - maxTurnsPerConversation
            )
        }
        conversations[index].updatedAt = Date()
        sortAndTrim()
        save()
    }

    func newConversation() {
        // Avoid filling history with repeated empty conversations.
        if let current = conversations.first(where: { $0.id == currentConversationID }),
           current.turns.isEmpty {
            return
        }

        let conversation = SariFiqhConversation(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            turns: []
        )
        conversations.insert(conversation, at: 0)
        currentConversationID = conversation.id
        sortAndTrim()
        save()
    }

    func select(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        currentConversationID = id
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if conversations.isEmpty {
            let replacement = SariFiqhConversation(
                id: UUID(),
                createdAt: Date(),
                updatedAt: Date(),
                turns: []
            )
            conversations = [replacement]
            currentConversationID = replacement.id
        } else if !conversations.contains(where: { $0.id == currentConversationID }) {
            currentConversationID = conversations[0].id
        }
        save()
    }

    private func ensureCurrentConversation() {
        guard !conversations.contains(where: { $0.id == currentConversationID }) else { return }
        let replacement = SariFiqhConversation(
            id: UUID(),
            createdAt: Date(),
            updatedAt: Date(),
            turns: []
        )
        conversations.insert(replacement, at: 0)
        currentConversationID = replacement.id
    }

    private func sortAndTrim() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
        if conversations.count > maxConversations {
            conversations.removeLast(conversations.count - maxConversations)
        }
        if !conversations.contains(where: { $0.id == currentConversationID }),
           let first = conversations.first {
            currentConversationID = first.id
        }
    }

    private func save() {
        do {
            let url = fileURL
            try fm.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversations)
            try data.write(to: url, options: .atomic)
            try? fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            let detail = String(describing: error)
            Task {
                await SariDiagnostics.shared.log(
                    "fiqh.history saveFailed error=\(detail)"
                )
            }
        }
    }
}
