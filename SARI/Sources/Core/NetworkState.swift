import Foundation
import Network

@MainActor
final class NetworkState: ObservableObject {
    static let shared = NetworkState()

    @Published private(set) var online = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sa.sari.network")

    private init() {
        monitor.pathUpdateHandler = { path in
            Self.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    private nonisolated static func handlePathUpdate(_ path: NWPath) {
        let isOnline = path.status == .satisfied
        Task { @MainActor in
            NetworkState.shared.online = isOnline
        }
    }
}
