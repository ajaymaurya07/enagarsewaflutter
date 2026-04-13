import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class PropertyEntity {
  final String propertyId;
  final String ownerName;
  final String ward;
  final String mohalla;
  final String phoneNumber;
  final String? email;
  final String? userType;

  PropertyEntity({
    required this.propertyId,
    required this.ownerName,
    required this.ward,
    required this.mohalla,
    required this.phoneNumber,
    this.email,
    this.userType,
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
    );
  }
}

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'property_database.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE property_table(propertyId TEXT PRIMARY KEY, ownerName TEXT, ward TEXT, mohalla TEXT, phoneNumber TEXT, email TEXT, userType TEXT)',
        );
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
}
