import Foundation
import Network
@MainActor final class NetworkState:ObservableObject {
    static let shared=NetworkState()
    @Published private(set) var online=true
    private let monitor=NWPathMonitor(),queue=DispatchQueue(label:"sa.sari.network")
    private init(){monitor.pathUpdateHandler={path in Task{@MainActor in self.online = path.status == .satisfied}};monitor.start(queue:queue)}
}
