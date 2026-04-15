import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class PropertyEntity {
  final String propertyId;
  final String ownerName;
  final String ward;
  final String mohalla;
  final String phoneNumber;
  final String? email;
  final String? userType;
  final String? ulbId;
  final String? arvValue;
  final String? userId;

  PropertyEntity({
    required this.propertyId,
    required this.ownerName,
    required this.ward,
    required this.mohalla,
    required this.phoneNumber,
    this.email,
    this.userType,
    this.ulbId,
    this.arvValue,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'propertyId': propertyId,
      'ownerName': ownerName,
      'ward': ward,
      'mohalla': mohalla,
      'phoneNumber': phoneNumber,
      'email': email,
      'userType': userType,
      'ulbId': ulbId,
      'arvValue': arvValue,
      'userId': userId,
    };
  }

  factory PropertyEntity.fromMap(Map<String, dynamic> map) {
    return PropertyEntity(
      propertyId: map['propertyId'],
      ownerName: map['ownerName'],
      ward: map['ward'],
      mohalla: map['mohalla'],
      phoneNumber: map['phoneNumber'],
      email: map['email'],
      userType: map['userType'],
      ulbId: map['ulbId'],
      arvValue: map['arvValue'],
      userId: map['userId'],
    );
  }
}

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'property_database.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE property_table(propertyId TEXT PRIMARY KEY, ownerName TEXT, ward TEXT, mohalla TEXT, phoneNumber TEXT, email TEXT, userType TEXT, ulbId TEXT, arvValue TEXT, userId TEXT)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE property_table ADD COLUMN ulbId TEXT');
          await db.execute('ALTER TABLE property_table ADD COLUMN arvValue TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE property_table ADD COLUMN userId TEXT');
        }
      },
    );
  }

  static Future<void> insertProperty(PropertyEntity property) async {
    final db = await database;
    await db.insert(
      'property_table',
      property.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<PropertyEntity?> getPropertyById(String propertyId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'property_table',
      where: 'propertyId = ?',
      whereArgs: [propertyId],
    );
    if (maps.isEmpty) return null;
    return PropertyEntity.fromMap(maps.first);
  }

  static Future<List<PropertyEntity>> getAllProperties() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('property_table');
    return List.generate(maps.length, (i) {
      return PropertyEntity.fromMap(maps[i]);
    });
  }

  static Future<void> deletePropertyById(String id) async {
    final db = await database;
    await db.delete(
      'property_table',
      where: 'propertyId = ?',
      whereArgs: [id],
    );
  }

  static Future<void> clearDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'property_database.db');
      
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      
      await deleteDatabase(path);
      debugPrint("Database cleared and file deleted successfully.");
    } catch (e) {
      debugPrint("Database clear error: $e");
    }
  }
}
