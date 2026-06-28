import Foundation
import os

/// Severity levels for `Logger`.
///
/// Unknown strings are rejected at the API boundary (see DECISION P1-LOG-001).
public enum LogLevel: String, CaseIterable, Codable, Sendable, Hashable {
    case trace
    case debug
    case info
    case warn
    case error

    /// Numeric ordering. Higher = more severe.
    public var rank: Int {
        switch self {
        case .trace: return 0
        case .debug: return 1
        case .info:  return 2
        case .warn:  return 3
        case .error: return 4
        }
    }
}

/// A typed rejection returned when a caller hands `Logger` an invalid level string.
public struct UnknownLogLevelError: Error, Equatable {
    public let rawValue: String
}

/// Where log lines are flushed.
public protocol LogSink: Sendable {
    func write(_ entry: LogEntry)
}

/// Captured log record. Decodable for CLI / debug-overlay round-trips.
public struct LogEntry: Codable, Sendable, Equatable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: String
    public let message: String
    public let redactions: [String]

    public init(timestamp: Date, level: LogLevel, category: String, message: String, redactions: [String]) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.redactions = redactions
    }
}

/// Output to stdout (debug builds).
public struct StdoutSink: LogSink {
    public init() {}
    public func write(_ entry: LogEntry) {
        // ponytail: avoid ISO formatting per line, log throughput matters.
        let line = "[\(entry.level.rawValue)] \(entry.category): \(entry.message)"
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}

/// Persistent backing file.
public final class FileSink: LogSink, @unchecked Sendable {
    private let lock = NSLock()
    private let handle: FileHandle

    public init(path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        self.handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
    }

    deinit {
        try? handle.close()
    }

    public func write(_ entry: LogEntry) {
        // ponytail: scoped lock; log writes are in the hot path.
        lock.lock()
        defer { lock.unlock() }
        let payload = "\(entry.timestamp.timeIntervalSince1970) [\(entry.level.rawValue)] \(entry.category): \(entry.message)\n"
        if let data = payload.data(using: .utf8) {
            try? handle.write(contentsOf: data)
        }
    }
}

/// macOS unified-log sink — used in CI/dev mode where syslog noise is undesirable.
public struct OSLogSink: LogSink {
    private let logger: os.Logger
    public init(subsystem: String, category: String) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    public func write(_ entry: LogEntry) {
        switch entry.level {
        case .trace, .debug: logger.debug("\(entry.message, privacy: .public)")
        case .info:          logger.info("\(entry.message, privacy: .public)")
        case .warn:          logger.warning("\(entry.message, privacy: .public)")
        case .error:         logger.error("\(entry.message, privacy: .public)")
        }
    }
}

/// Phase 1 redactor. Drops obvious secrets so log capture at INFO level never leaks.
/// Phase 7 sharpens this with content-aware filtering (see spec-007-ai).
public struct LogRedactor: Sendable {
    /// Patterns are: (description, NSRegularExpression-friendly literal substring).
    /// Kept as simple substring matches for O(n·m) over short messages — the false-positive
    /// cost is acceptable because the next pass is human review.
    public static let defaults: [String] = [
        "sk-ant-",          // Anthropic API key prefix
        "x-api-key=",       // generic header echo
        "/Users/",          // raw home paths leak PII
        "/Documents/",
    ]

    public let patterns: [String]

    public init(patterns: [String] = LogRedactor.defaults) {
        self.patterns = patterns
    }

    public func redact(_ message: String) -> (String, [String]) {
        var redacted = message
        var hits: [String] = []
        for pattern in patterns where redacted.contains(pattern) {
            hits.append(pattern)
            redacted = redacted.replacingOccurrences(of: pattern, with: "[REDACTED]")
        }
        return (redacted, hits)
    }
}

/// Core logger. Thread-safe; safe for use from MTKView callbacks and Update Loop.
public final class Logger: @unchecked Sendable {
    /// Threshold below which entries are dropped. Default `.info`; Production may set `.warn`.
    public var minimumLevel: LogLevel

    /// Rate-limit cap for `.trace` (entries/sec). Default 100/s when `.trace` is enabled.
    public var traceRateLimitPerSecond: Int

    private let sinks: [LogSink]
    private let redactor: LogRedactor
    private let subsystem: String

    /// Trace-rate bookkeeping. Simple atomic counter; rolling window is fine here.
    private var traceWindowStart: TimeInterval = 0
    private var traceCountInWindow: Int = 0
    private let rateLock = NSLock()

    // ponytail: a single global instance per subsystem. Phase N may grow a registry if
    // subsystems diverge; one fits Phase 1.
    /// The Phase 1 default logger — flushed to stderr + a file under `~/Library/Logs/...`.
    public static let shared: Logger = {
        let logPath = NSHomeDirectory() + "/Library/Logs/DesktopPet/desktop-pet.log"
        let sinks: [LogSink]
        do {
            sinks = [StdoutSink(), try FileSink(path: logPath)]
        } catch {
            sinks = [StdoutSink()]
        }
        return Logger(subsystem: "com.desktop-pet", sinks: sinks)
    }()

    public init(
        subsystem: String,
        sinks: [LogSink],
        redactor: LogRedactor = LogRedactor(),
        minimumLevel: LogLevel = .info,
        traceRateLimitPerSecond: Int = 100
    ) {
        self.subsystem = subsystem
        self.sinks = sinks
        self.redactor = redactor
        self.minimumLevel = minimumLevel
        self.traceRateLimitPerSecond = traceRateLimitPerSecond
    }

    /// Resolves a level from a raw string. Throws `UnknownLogLevelError` if invalid.
    public static func parseLevel(_ raw: String) throws -> LogLevel {
        guard let level = LogLevel(rawValue: raw) else { throw UnknownLogLevelError(rawValue: raw) }
        return level
    }

    public func trace(_ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        log(.trace, message, category: category, file: file, line: line)
    }
    public func debug(_ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        log(.debug, message, category: category, file: file, line: line)
    }
    public func info(_ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        log(.info, message, category: category, file: file, line: line)
    }
    public func warn(_ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        log(.warn, message, category: category, file: file, line: line)
    }
    public func error(_ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        log(.error, message, category: category, file: file, line: line)
    }

    /// Single funnel for all levels — needed so redactor + sinks + rate-limit are uniform.
    public func log(_ level: LogLevel, _ message: String, category: String = "general", file: StaticString = #file, line: UInt = #line) {
        guard level.rank >= minimumLevel.rank else { return }
        if level == .trace, !consumeTraceBudget() { return }

        let (cleaned, hits) = redactor.redact(message)
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: "\(subsystem).\(category)",
            message: cleaned,
            redactions: hits
        )
        for sink in sinks {
            sink.write(entry)
        }
    }

    // ponytail: rate limiter is approximate by design. A burst of <100 trace entries still
    // gets through; correctness-grade limiting upgrades to a token bucket only if benchmarks
    // demand it.
    private func consumeTraceBudget() -> Bool {
        rateLock.lock()
        defer { rateLock.unlock() }
        let now = CFAbsoluteTimeGetCurrent()
        if now - traceWindowStart >= 1.0 {
            traceWindowStart = now
            traceCountInWindow = 0
        }
        if traceCountInWindow >= traceRateLimitPerSecond { return false }
        traceCountInWindow += 1
        return true
    }
}
