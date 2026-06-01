import Foundation
import SQLite3

/// SQLite-backed cache for recently-used properties.
/// Mirrors Flutter's DatabaseService (sqflite) with property_table schema v4.
final class DatabaseService {

    static let shared = DatabaseService()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.enagarsewa.db", qos: .utility)

    private init() {
        openDatabase()
        createTable()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Public API

    func insertOrReplace(_ entity: PropertyEntity, completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            let ok = self?.insert(entity) ?? false
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    func fetchAll(completion: @escaping ([PropertyEntity]) -> Void) {
        queue.async { [weak self] in
            let rows = self?.queryAll() ?? []
            DispatchQueue.main.async { completion(rows) }
        }
    }

    func delete(propertyId: String, completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            let ok = self?.deleteRow(propertyId: propertyId) ?? false
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    func deleteAll(completion: ((Bool) -> Void)? = nil) {
        queue.async { [weak self] in
            let sql = "DELETE FROM property_table"
            let ok = (self?.exec(sql)) != nil
            DispatchQueue.main.async { completion?(ok) }
        }
    }

    // MARK: - Setup

    private func openDatabase() {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppConstants.Database.name)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            assertionFailure("Failed to open SQLite database")
            return
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS property_table (
            propertyId TEXT PRIMARY KEY,
            ownerName  TEXT,
            ward       TEXT,
            mohalla    TEXT,
            phoneNumber TEXT,
            email      TEXT,
            userType   TEXT,
            ulbId      TEXT,
            arvValue   TEXT,
            userId     TEXT,
            fatherName TEXT,
            address    TEXT
        );
        """
        exec(sql)
    }

    // MARK: - CRUD

    @discardableResult
    private func insert(_ e: PropertyEntity) -> Bool {
        let sql = """
        INSERT OR REPLACE INTO property_table
        (propertyId, ownerName, ward, mohalla, phoneNumber, email, userType,
         ulbId, arvValue, userId, fatherName, address)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }

        let fields = [e.propertyId, e.ownerName, e.ward, e.mohalla, e.phoneNumber,
                      e.email, e.userType, e.ulbId, e.arvValue, e.userId,
                      e.fatherName, e.address]
        for (i, field) in fields.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), (field as NSString).utf8String, -1, nil)
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func queryAll() -> [PropertyEntity] {
        let sql = "SELECT * FROM property_table;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var rows: [PropertyEntity] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            rows.append(PropertyEntity(
                propertyId:  string(stmt, 0),
                ownerName:   string(stmt, 1),
                ward:        string(stmt, 2),
                mohalla:     string(stmt, 3),
                phoneNumber: string(stmt, 4),
                email:       string(stmt, 5),
                userType:    string(stmt, 6),
                ulbId:       string(stmt, 7),
                arvValue:    string(stmt, 8),
                userId:      string(stmt, 9),
                fatherName:  string(stmt, 10),
                address:     string(stmt, 11)
            ))
        }
        return rows
    }

    private func deleteRow(propertyId: String) -> Bool {
        let sql = "DELETE FROM property_table WHERE propertyId = ?;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (propertyId as NSString).utf8String, -1, nil)
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    private func string(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: cStr)
    }
}
