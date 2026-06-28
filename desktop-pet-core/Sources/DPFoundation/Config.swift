import Foundation

/// Strongly-typed config schema. Strictly no string keys leak past `decode<T>(_:)`.
///
/// Phase 1 ships a hand-rolled minimal "INI-ish" reader to avoid pulling a YAML
/// dependency for one config file. The format is line-based:
///
///   key = value
///
/// Future Phase 8 may migrate to YAML once settings UI lands; the public decode API
/// is preserved either way. See `00-spec-conventions.md` and `roadmap.md` for the
/// long-term direction.
public struct DesktopPetConfig: Codable, Equatable, Sendable {
    public var window: WindowConfig
    public var runtime: RuntimeConfig
    public var profiling: ProfilingConfig
    public var assets: AssetConfig

    public init(window: WindowConfig = .default, runtime: RuntimeConfig = .default, profiling: ProfilingConfig = .default, assets: AssetConfig = .default) {
        self.window = window
        self.runtime = runtime
        self.profiling = profiling
        self.assets = assets
    }

    public static let `default` = DesktopPetConfig()
}

public struct WindowConfig: Codable, Equatable, Sendable {
    public enum Position: Codable, Equatable, Sendable {
        case center
        case topLeft
        case custom(x: Double, y: Double)
    }
    public enum MultiDisplayPolicy: String, Codable, Equatable, Sendable {
        case primaryOnly
        case followActiveDisplay
    }

    public var width: Double
    public var height: Double
    public var position: Position
    public var multiDisplayPolicy: MultiDisplayPolicy
    public var clickThrough: Bool

    public init(width: Double = 320, height: Double = 320, position: Position = .center, multiDisplayPolicy: MultiDisplayPolicy = .primaryOnly, clickThrough: Bool = true) {
        self.width = width
        self.height = height
        self.position = position
        self.multiDisplayPolicy = multiDisplayPolicy
        self.clickThrough = clickThrough
    }

    public static let `default` = WindowConfig()
}

public struct RuntimeConfig: Codable, Equatable, Sendable {
    public var targetFrameRate: Int
    public var bootTimeoutMs: Int
    public init(targetFrameRate: Int = 60, bootTimeoutMs: Int = 1000) {
        self.targetFrameRate = targetFrameRate
        self.bootTimeoutMs = bootTimeoutMs
    }
    public static let `default` = RuntimeConfig()
}

public struct ProfilingConfig: Codable, Equatable, Sendable {
    public enum Policy: String, Codable, Equatable, Sendable {
        case off
        case everyFrame
        case everyNFrames
        case manual
    }
    public var policy: Policy
    public var everyNFrames: Int
    public init(policy: Policy = .everyNFrames, everyNFrames: Int = 60) {
        self.policy = policy
        self.everyNFrames = everyNFrames
    }
    public static let `default` = ProfilingConfig()
}

public struct AssetConfig: Codable, Equatable, Sendable {
    public var foxGLBPath: String
    public var memoryCacheBytes: Int
    public init(foxGLBPath: String = "pets-models/fox.glb", memoryCacheBytes: Int = 32 * 1024 * 1024) {
        self.foxGLBPath = foxGLBPath
        self.memoryCacheBytes = memoryCacheBytes
    }
    public static let `default` = AssetConfig()
}

/// Outcome of `decode`. Either a fully validated config or a typed reason.
public enum ConfigDecodeError: Error, Equatable, CustomStringConvertible {
    case missingFile(path: String)
    case parseError(reason: String, line: Int?)
    case schemaMismatch(field: String, expected: String, actual: String)

    public var description: String {
        switch self {
        case .missingFile(let path): return "config missing at \(path)"
        case .parseError(let reason, let line):
            if let line = line { return "config parse error at line \(line): \(reason)" }
            return "config parse error: \(reason)"
        case .schemaMismatch(let field, let expected, let actual): return "\(field): expected \(expected), got \(actual)"
        }
    }
}

/// Loads a `DesktopPetConfig` from disk and produces or rejects in a fully typed manner.
public final class Config: @unchecked Sendable {
    private let logger: Logger?

    public init(logger: Logger? = nil) {
        self.logger = logger
    }

    /// Default config location, per spec-001.
    /// Ponytail: Phase 1 ships a minimal hand-rolled INI reader (no YAML/TOML
    /// third-party dependency). The extension is `.conf` to make the parser
    /// selection unambiguous; spec-001 §2's "YAML or TOML" roadmap is revisited
    /// in Phase 8 (Hardening) if a richer config schema is needed.
    public static var defaultURL: URL {
        let path = NSHomeDirectory() + "/Library/Application Support/DesktopPet/config.conf"
        return URL(fileURLWithPath: path)
    }

    /// Decode the config at `url`. If the file is absent, returns `.default`.
    /// Test harness can pass an arbitrary URL.
    public func decode(from url: URL) -> Result<DesktopPetConfig, ConfigDecodeError> {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .failure(.missingFile(path: url.path))
        }
        do {
            let raw = try String(contentsOf: url, encoding: .utf8)
            return decode(raw)
                .mapError { err in .parseError(reason: String(describing: err), line: nil) }
        } catch let err {
            return .failure(.parseError(reason: String(describing: err), line: nil))
        }
    }

    /// Pure decode — exposed for tests so we don't need disk I/O.
    public func decode(_ raw: String) -> Result<DesktopPetConfig, ConfigDecodeError> {
        // ponytail: hand-rolled INI-ish reader keeps Phase 1 dependency-free.
        var parsed: [String: String] = [:]
        var section: String = ""
        var lineNo = 0
        for rawLine in raw.split(separator: "\n") {
            lineNo += 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                continue
            }
            guard let eq = line.firstIndex(of: "=") else {
                return .failure(.parseError(reason: "expected '=' on line \(line)", line: lineNo))
            }
            let k = line[..<eq].trimmingCharacters(in: .whitespaces)
            let v = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if !section.isEmpty {
                parsed["\(section).\(k)"] = v
            } else {
                parsed[String(k)] = v
            }
        }

        return assemble(parsed)
    }

    private func assemble(_ kv: [String: String]) -> Result<DesktopPetConfig, ConfigDecodeError> {
        var config = DesktopPetConfig.default

        if let raw = kv["window.width"], let v = Double(raw) {
            config.window.width = v
        } else if let _ = kv["window.width"] {
            return .failure(.schemaMismatch(field: "window.width", expected: "Double", actual: String(describing: kv["window.width"])))
        }
        if let raw = kv["window.height"], let v = Double(raw) {
            config.window.height = v
        } else if let _ = kv["window.height"] {
            return .failure(.schemaMismatch(field: "window.height", expected: "Double", actual: String(describing: kv["window.height"])))
        }
        if let raw = kv["window.position"] {
            switch raw {
            case "center": config.window.position = .center
            case "topLeft": config.window.position = .topLeft
            case let s where s.hasPrefix("("):
                // (123.0,45.0)
                let inside = s.dropFirst().dropLast()
                let parts = inside.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else {
                    return .failure(.schemaMismatch(field: "window.position", expected: "center|topLeft|(x,y)", actual: raw))
                }
                config.window.position = .custom(x: x, y: y)
            default:
                return .failure(.schemaMismatch(field: "window.position", expected: "center|topLeft|(x,y)", actual: raw))
            }
        }
        if let raw = kv["window.multiDisplayPolicy"] {
            guard let policy = WindowConfig.MultiDisplayPolicy(rawValue: raw) else {
                return .failure(.schemaMismatch(field: "window.multiDisplayPolicy", expected: "primaryOnly|followActiveDisplay", actual: raw))
            }
            config.window.multiDisplayPolicy = policy
        }
        if let raw = kv["window.clickThrough"] {
            guard let b = Bool(raw) else {
                return .failure(.schemaMismatch(field: "window.clickThrough", expected: "true|false", actual: raw))
            }
            config.window.clickThrough = b
        }
        if let raw = kv["runtime.targetFrameRate"], let v = Int(raw) {
            config.runtime.targetFrameRate = v
        }
        if let raw = kv["runtime.bootTimeoutMs"], let v = Int(raw) {
            config.runtime.bootTimeoutMs = v
        }
        if let raw = kv["profiling.policy"] {
            guard let p = ProfilingConfig.Policy(rawValue: raw) else {
                return .failure(.schemaMismatch(field: "profiling.policy", expected: "off|everyFrame|everyNFrames|manual", actual: raw))
            }
            config.profiling.policy = p
        }
        if let raw = kv["profiling.everyNFrames"], let v = Int(raw) {
            config.profiling.everyNFrames = v
        }
        if let raw = kv["assets.foxGLBPath"] {
            config.assets.foxGLBPath = raw
        }
        if let raw = kv["assets.memoryCacheBytes"], let v = Int(raw) {
            config.assets.memoryCacheBytes = v
        }
        return .success(config)
    }

    /// Encode a config back to disk-compatible form. Used by tests (round-trip).
    public func encode(_ config: DesktopPetConfig) -> String {
        var out = ""
        out += "[window]\n"
        out += "width = \(config.window.width)\n"
        out += "height = \(config.window.height)\n"
        switch config.window.position {
        case .center: out += "position = center\n"
        case .topLeft: out += "position = topLeft\n"
        case let .custom(x, y): out += "position = (\(x),\(y))\n"
        }
        out += "multiDisplayPolicy = \(config.window.multiDisplayPolicy.rawValue)\n"
        out += "clickThrough = \(config.window.clickThrough)\n"
        out += "\n[runtime]\n"
        out += "targetFrameRate = \(config.runtime.targetFrameRate)\n"
        out += "bootTimeoutMs = \(config.runtime.bootTimeoutMs)\n"
        out += "\n[profiling]\n"
        out += "policy = \(config.profiling.policy.rawValue)\n"
        out += "everyNFrames = \(config.profiling.everyNFrames)\n"
        out += "\n[assets]\n"
        out += "foxGLBPath = \(config.assets.foxGLBPath)\n"
        out += "memoryCacheBytes = \(config.assets.memoryCacheBytes)\n"
        return out
    }
}

/// Mock implementing the same decode API surface — used in tests so modules don't
/// each reinvent one.
public final class ConfigMock: @unchecked Sendable {
    public init() {}
    public func decode(from url: URL) -> Result<DesktopPetConfig, ConfigDecodeError> {
        .success(.default)
    }
}
