import Foundation

/// Order-preserving, lenient JSON value.
///
/// The backend is loosely typed (ids arrive as numbers on one endpoint and strings on another,
/// option lists arrive as `{id: label}` objects whose key order is the display order), and the
/// Flutter app parses it the same loose way (`json['x']?.toString()`, `json['y'] is int ? ...`).
/// `JSONDecoder`/`JSONSerialization` would either reject those shapes or lose object key order,
/// so responses are parsed with this small parser instead and read through the Dart-style
/// accessors below.
enum JSON {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSON])
    case object(JSONObject)

    // MARK: - Parsing

    static func parse(_ data: Data) throws -> JSON {
        var parser = JSONParser(bytes: [UInt8](data))
        return try parser.parseDocument()
    }

    // MARK: - Dart-style accessors

    subscript(key: String) -> JSON? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    var isNull: Bool { if case .null = self { return true }; return false }

    /// Mirrors Dart's `value?.toString()` — nil only for JSON null.
    var stringValue: String? {
        switch self {
        case .null:              return nil
        case .bool(let b):       return b ? "true" : "false"
        case .int(let i):        return String(i)
        case .double(let d):     return JSON.dartDoubleString(d)
        case .string(let s):     return s
        case .array, .object:    return JSON.serialize(self)
        }
    }

    /// Mirrors `v is int ? v : int.tryParse('$v')`.
    var intValue: Int? {
        switch self {
        case .int(let i):    return i
        case .double(let d): return d == d.rounded() && abs(d) < Double(Int.max) ? Int(d) : nil
        case .string(let s): return Int(s.trimmingCharacters(in: .whitespaces))
        case .bool:          return nil
        default:             return nil
        }
    }

    /// Mirrors `(v as num?)?.toDouble()`, leniently also accepting numeric strings.
    var doubleValue: Double? {
        switch self {
        case .int(let i):    return Double(i)
        case .double(let d): return d
        case .string(let s): return Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ""))
        default:             return nil
        }
    }

    /// True only when the value is the JSON literal `true` (Dart `json['x'] == true`).
    var isTrue: Bool { if case .bool(true) = self { return true }; return false }

    /// The value when it is a JSON bool.
    var boolValue: Bool? { if case .bool(let b) = self { return b }; return nil }

    var objectValue: JSONObject? { if case .object(let o) = self { return o }; return nil }

    var arrayValue: [JSON]? { if case .array(let a) = self { return a }; return nil }

    var isNumber: Bool {
        switch self { case .int, .double: return true; default: return false }
    }

    // MARK: - Dart number formatting

    /// Dart prints whole doubles with a trailing `.0` (`120.0`), Swift would print `120.0` too but
    /// uses exponent notation earlier; keep Dart's behaviour for the common range.
    static func dartDoubleString(_ d: Double) -> String {
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d > 0 ? "Infinity" : "-Infinity" }
        if d == d.rounded() && abs(d) < 1e21 {
            return String(format: "%.1f", d)
        }
        return "\(d)"
    }

    // MARK: - Serialization (used for `toString()` of nested values / debugging)

    static func serialize(_ value: JSON) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return String(i)
        case .double(let d): return dartDoubleString(d)
        case .string(let s):
            let data = (try? JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed])) ?? Data()
            let text = String(data: data, encoding: .utf8) ?? "[\"\"]"
            return String(text.dropFirst().dropLast())
        case .array(let a): return "[" + a.map(serialize).joined(separator: ",") + "]"
        case .object(let o):
            return "{" + o.keys.map { "\(serialize(.string($0))):\(serialize(o[$0] ?? .null))" }.joined(separator: ",") + "}"
        }
    }
}

/// JSON object that remembers key insertion order (like Dart's `LinkedHashMap`).
struct JSONObject {
    private(set) var keys: [String] = []
    private var storage: [String: JSON] = [:]

    subscript(key: String) -> JSON? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil { keys.append(key) }
                storage[key] = newValue
            } else if storage.removeValue(forKey: key) != nil {
                keys.removeAll { $0 == key }
            }
        }
    }

    var isEmpty: Bool { keys.isEmpty }

    var entries: [(key: String, value: JSON)] { keys.map { ($0, storage[$0] ?? .null) } }
}

// MARK: - Convenience readers used by the model initialisers

extension Optional where Wrapped == JSON {
    /// `json['x']?.toString()` — nil for missing or null.
    var str: String? { self?.stringValue }
    /// `json['x']?.toString() ?? ''`
    var strOrEmpty: String { self?.stringValue ?? "" }
    var int: Int? { self?.intValue }
    var double: Double? { self?.doubleValue }
    var isTrue: Bool { self?.isTrue ?? false }
    var bool: Bool? { self?.boolValue }
    var object: JSONObject? { self?.objectValue }
    var array: [JSON]? { self?.arrayValue }

    /// `json['x']` as an ordered `{key: label}` map — mirrors `_toStringMap` in api_service.dart.
    var stringMap: [(key: String, value: String)] {
        guard let obj = self?.objectValue else { return [] }
        return obj.entries.map { ($0.key, $0.value.stringValue ?? "") }
    }

    /// `json['x'] is List ? list.whereType<Map>().map(fromJson) : []`
    func objects<T>(_ make: (JSON) -> T) -> [T] {
        guard let arr = self?.arrayValue else { return [] }
        return arr.filter { $0.objectValue != nil }.map(make)
    }
}

// MARK: - Parser

private struct JSONParser {
    let bytes: [UInt8]
    var pos = 0

    enum ParseError: Error { case unexpected(Int), unterminated }

    init(bytes: [UInt8]) {
        self.bytes = bytes
        // Skip a UTF-8 BOM if present.
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF { pos = 3 }
    }

    mutating func parseDocument() throws -> JSON {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        guard pos == bytes.count else { throw ParseError.unexpected(pos) }
        return value
    }

    private mutating func skipWhitespace() {
        while pos < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[pos]) { pos += 1 }
    }

    private mutating func parseValue() throws -> JSON {
        guard pos < bytes.count else { throw ParseError.unterminated }
        switch bytes[pos] {
        case UInt8(ascii: "{"): return try parseObject()
        case UInt8(ascii: "["): return try parseArray()
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): try expect("true"); return .bool(true)
        case UInt8(ascii: "f"): try expect("false"); return .bool(false)
        case UInt8(ascii: "n"): try expect("null"); return .null
        default: return try parseNumber()
        }
    }

    private mutating func expect(_ literal: String) throws {
        let lit = Array(literal.utf8)
        guard pos + lit.count <= bytes.count, Array(bytes[pos..<pos + lit.count]) == lit else {
            throw ParseError.unexpected(pos)
        }
        pos += lit.count
    }

    private mutating func parseObject() throws -> JSON {
        pos += 1
        var object = JSONObject()
        skipWhitespace()
        if pos < bytes.count, bytes[pos] == UInt8(ascii: "}") { pos += 1; return .object(object) }
        while true {
            skipWhitespace()
            guard pos < bytes.count, bytes[pos] == UInt8(ascii: "\"") else { throw ParseError.unexpected(pos) }
            let key = try parseString()
            skipWhitespace()
            guard pos < bytes.count, bytes[pos] == UInt8(ascii: ":") else { throw ParseError.unexpected(pos) }
            pos += 1
            skipWhitespace()
            object[key] = try parseValue()
            skipWhitespace()
            guard pos < bytes.count else { throw ParseError.unterminated }
            if bytes[pos] == UInt8(ascii: ",") { pos += 1; continue }
            if bytes[pos] == UInt8(ascii: "}") { pos += 1; return .object(object) }
            throw ParseError.unexpected(pos)
        }
    }

    private mutating func parseArray() throws -> JSON {
        pos += 1
        var items: [JSON] = []
        skipWhitespace()
        if pos < bytes.count, bytes[pos] == UInt8(ascii: "]") { pos += 1; return .array(items) }
        while true {
            skipWhitespace()
            items.append(try parseValue())
            skipWhitespace()
            guard pos < bytes.count else { throw ParseError.unterminated }
            if bytes[pos] == UInt8(ascii: ",") { pos += 1; continue }
            if bytes[pos] == UInt8(ascii: "]") { pos += 1; return .array(items) }
            throw ParseError.unexpected(pos)
        }
    }

    private mutating func parseString() throws -> String {
        pos += 1
        var buffer: [UInt8] = []
        while pos < bytes.count {
            let c = bytes[pos]
            if c == UInt8(ascii: "\"") {
                pos += 1
                return String(decoding: buffer, as: UTF8.self)
            }
            if c == UInt8(ascii: "\\") {
                pos += 1
                guard pos < bytes.count else { throw ParseError.unterminated }
                let e = bytes[pos]
                pos += 1
                switch e {
                case UInt8(ascii: "\""): buffer.append(0x22)
                case UInt8(ascii: "\\"): buffer.append(0x5C)
                case UInt8(ascii: "/"):  buffer.append(0x2F)
                case UInt8(ascii: "b"):  buffer.append(0x08)
                case UInt8(ascii: "f"):  buffer.append(0x0C)
                case UInt8(ascii: "n"):  buffer.append(0x0A)
                case UInt8(ascii: "r"):  buffer.append(0x0D)
                case UInt8(ascii: "t"):  buffer.append(0x09)
                case UInt8(ascii: "u"):
                    var scalar = try readHex4()
                    if (0xD800...0xDBFF).contains(scalar),
                       pos + 1 < bytes.count, bytes[pos] == UInt8(ascii: "\\"), bytes[pos + 1] == UInt8(ascii: "u") {
                        pos += 2
                        let low = try readHex4()
                        if (0xDC00...0xDFFF).contains(low) {
                            scalar = 0x10000 + ((scalar - 0xD800) << 10) + (low - 0xDC00)
                        }
                    }
                    let unicode: Unicode.Scalar = Unicode.Scalar(scalar) ?? "\u{FFFD}"
                    buffer.append(contentsOf: Array(String(Character(unicode)).utf8))
                default:
                    throw ParseError.unexpected(pos)
                }
                continue
            }
            buffer.append(c)
            pos += 1
        }
        throw ParseError.unterminated
    }

    private mutating func readHex4() throws -> UInt32 {
        guard pos + 4 <= bytes.count,
              let value = UInt32(String(decoding: bytes[pos..<pos + 4], as: UTF8.self), radix: 16) else {
            throw ParseError.unexpected(pos)
        }
        pos += 4
        return value
    }

    private mutating func parseNumber() throws -> JSON {
        let start = pos
        var isFloat = false
        while pos < bytes.count {
            let c = bytes[pos]
            if (c >= UInt8(ascii: "0") && c <= UInt8(ascii: "9")) || c == UInt8(ascii: "-") || c == UInt8(ascii: "+") {
                pos += 1
            } else if c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") {
                isFloat = true
                pos += 1
            } else {
                break
            }
        }
        guard pos > start else { throw ParseError.unexpected(pos) }
        let text = String(decoding: bytes[start..<pos], as: UTF8.self)
        if !isFloat, let i = Int(text) { return .int(i) }
        guard let d = Double(text) else { throw ParseError.unexpected(start) }
        return .double(d)
    }
}
