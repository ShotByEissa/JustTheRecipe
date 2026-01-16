import Foundation
import Network

// MARK: - Network Monitor
// Simple network reachability monitor for pre-flight checks.
// MainActor-isolated for thread-safe UI access.

@MainActor
@Observable
final class NetworkMonitor {
    
    /// Shared instance
    static let shared = NetworkMonitor()
    
    /// Whether network is currently available
    private(set) var isConnected: Bool = true
    
    /// Connection type
    private(set) var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    enum ConnectionType: Sendable {
        case wifi
        case cellular
        case wired
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType = NetworkMonitor.getConnectionType(path)
            
            Task { @MainActor in
                self?.isConnected = isConnected
                self?.connectionType = connectionType
            }
        }
        monitor.start(queue: queue)
    }
    
    /// Determine connection type from path - nonisolated for background queue access
    nonisolated private static func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }
        return .unknown
    }
    
    deinit {
        monitor.cancel()
    }
}
