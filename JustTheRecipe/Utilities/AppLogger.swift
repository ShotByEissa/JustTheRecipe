import Foundation
import os

// MARK: - App Logger
// Simple logging wrapper for debug and error output.
// Uses os.log for proper system integration.

enum AppLogger {
    
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.justtherecipe"
    
    // Category-specific loggers
    private static let persistence = Logger(subsystem: subsystem, category: "persistence")
    private static let network = Logger(subsystem: subsystem, category: "network")
    private static let extraction = Logger(subsystem: subsystem, category: "extraction")
    private static let general = Logger(subsystem: subsystem, category: "general")
    
    // MARK: - Persistence Logging
    
    static func persistenceError(_ message: String, error: Error? = nil) {
        if let error = error {
            persistence.error("\(message): \(error.localizedDescription)")
        } else {
            persistence.error("\(message)")
        }
    }
    
    static func persistenceInfo(_ message: String) {
        persistence.info("\(message)")
    }
    
    // MARK: - Network Logging
    
    static func networkError(_ message: String, error: Error? = nil) {
        if let error = error {
            network.error("\(message): \(error.localizedDescription)")
        } else {
            network.error("\(message)")
        }
    }
    
    static func networkInfo(_ message: String) {
        network.info("\(message)")
    }
    
    // MARK: - Extraction Logging
    
    static func extractionError(_ message: String, error: Error? = nil) {
        if let error = error {
            extraction.error("\(message): \(error.localizedDescription)")
        } else {
            extraction.error("\(message)")
        }
    }
    
    static func extractionInfo(_ message: String) {
        extraction.info("\(message)")
    }
    
    // MARK: - General Logging
    
    static func debug(_ message: String) {
        #if DEBUG
        general.debug("\(message)")
        #endif
    }
    
    static func error(_ message: String, error: Error? = nil) {
        if let error = error {
            general.error("\(message): \(error.localizedDescription)")
        } else {
            general.error("\(message)")
        }
    }
}
