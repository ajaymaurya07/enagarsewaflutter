import Foundation
import SQLite3

/// SQLite cache of the user's saved properties — port of lib/services/database_service.dart
/// (`property_table`, schema v9). An actor serialises access to the connection.
actor DatabaseService {

    static let shared = DatabaseService()

    private var db: OpaquePointer?

    private static let columns = [
        "propertyId", "ownerName", "ward", "mohalla", "phoneNumber", "email", "userType", "ulbId",
        "arvValue", "userId", "fatherName", "address", "zone", "houseNo", "totalArea", "billDate",
        "netPayable", "oldPropertyId", "ulbLang",
    ]

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Public API

    func insertProperty(_ p: PropertyEntity) {
        open()
        let placeholders = Array(repeating: "?", count: Self.columns.count).joined(separator: ",")
        let sql = "INSERT OR REPLACE INTO property_table (\(Self.columns.joined(separator: ","))) VALUES (\(placeholders));"
        let values: [String?] = [p.propertyId, p.ownerName, p.ward, p.mohalla, p.phoneNumber, p.email,
                                 p.userType, p.ulbId, p.arvValue, p.userId, p.fatherName, p.address,
                                 p.zone, p.houseNo, p.totalArea, p.billDate, p.netPayable,
                                 p.oldPropertyId, p.ulbLang]
        run(sql, values)
    }

    /// Updates only the cached bill info; no-op when the row does not exist.
    func updatePropertyBillInfo(propertyId: String, billDate: String?, netPayable: String?) {
        open()
        run("UPDATE property_table SET billDate = ?, netPayable = ? WHERE propertyId = ?;",
            [billDate, netPayable, propertyId])
    }

    /// propertysearch values needed by the bill print; nil values are skipped.
    func updatePropertySearchInfo(propertyId: String, oldPropertyId: String?, arvValue: String?) {
        updateNonNull(propertyId: propertyId, ["oldPropertyId": oldPropertyId, "arvValue": arvValue])
    }

    /// Fresh propertydetails data; nil values are skipped so existing data is never wiped.
    func updatePropertyDetailsInfo(propertyId: String, ownerName: String?, fatherName: String?,
                                   address: String?, arvValue: String?) {
        updateNonNull(propertyId: propertyId, ["ownerName": ownerName, "fatherName": fatherName,
                                               "address": address, "arvValue": arvValue])
    }

    func getPropertyById(_ propertyId: String) -> PropertyEntity? {
        open()
        return query("SELECT \(Self.columns.joined(separator: ",")) FROM property_table WHERE propertyId = ?;",
                     [propertyId]).first
    }

    func getAllProperties() -> [PropertyEntity] {
        open()
        return query("SELECT \(Self.columns.joined(separator: ",")) FROM property_table;", [])
    }

    func deletePropertyById(_ id: String) {
        open()
        run("DELETE FROM property_table WHERE propertyId = ?;", [id])
    }

    /// Dart `clearDatabase()` closes and deletes the file; the next call recreates it.
    func clearDatabase() {
        if let db { sqlite3_close(db) }
        db = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    // MARK: - Open / migrate

    private static var fileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppConstants.Database.name)
    }

    private func open() {
        guard db == nil else { return }
        try? FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        guard sqlite3_open(Self.fileURL.path, &db) == SQLITE_OK else {
            db = nil
            return
        }
        exec("CREATE TABLE IF NOT EXISTS property_table(propertyId TEXT PRIMARY KEY, ownerName TEXT, ward TEXT, mohalla TEXT, phoneNumber TEXT)")
        // Bring any older schema (including the earlier 12-column native build) up to v9.
        let existing = Set(tableColumns())
        for column in Self.columns where !existing.contains(column) {
            exec("ALTER TABLE property_table ADD COLUMN \(column) TEXT")
        }
        exec("PRAGMA user_version = \(AppConstants.Database.version)")
    }

    private func tableColumns() -> [String] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA table_info(property_table);", -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var names: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 1) { names.append(String(cString: c)) }
        }
        return names
    }

    // MARK: - Helpers

    private func updateNonNull(propertyId: String, _ fields: KeyValuePairs<String, String?>) {
        let present = fields.compactMap { pair in pair.value.map { (pair.key, $0) } }
        guard !present.isEmpty else { return }
        open()
        let sets = present.map { "\($0.0) = ?" }.joined(separator: ", ")
        run("UPDATE property_table SET \(sets) WHERE propertyId = ?;", present.map { $0.1 } + [propertyId])
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    @discardableResult
    private func run(_ sql: String, _ values: [String?]) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, values)
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func query(_ sql: String, _ values: [String?]) -> [PropertyEntity] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        bind(stmt, values)
        var rows: [PropertyEntity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            func col(_ i: Int32) -> String? {
                guard let c = sqlite3_column_text(stmt, i) else { return nil }
                return String(cString: c)
            }
            rows.append(PropertyEntity(
                propertyId: col(0) ?? "", ownerName: col(1) ?? "", ward: col(2) ?? "",
                mohalla: col(3) ?? "", phoneNumber: col(4) ?? "", email: col(5), userType: col(6),
                ulbId: col(7), arvValue: col(8), userId: col(9), fatherName: col(10), address: col(11),
                zone: col(12), houseNo: col(13), totalArea: col(14), oldPropertyId: col(17),
                billDate: col(15), netPayable: col(16), ulbLang: col(18)
            ))
        }
        return rows
    }

    private func bind(_ stmt: OpaquePointer?, _ values: [String?]) {
        for (i, value) in values.enumerated() {
            if let value {
                sqlite3_bind_text(stmt, Int32(i + 1), value, -1, Self.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, Int32(i + 1))
            }
        }
    }
}
