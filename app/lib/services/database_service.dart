import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/api_models.dart';

class DatabaseService {
  static Database? _database;
  static const String _databaseName = 'user_management.db';
  static const int _databaseVersion = 1;

  // Tables
  static const String _usersTable = 'users';
  static const String _modificationsTable = 'user_modifications';
  static const String _rolesTable = 'roles';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users table
    await db.execute('''
      CREATE TABLE $_usersTable (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT NOT NULL,
        role TEXT NOT NULL,
        firstName TEXT,
        lastName TEXT,
        phoneNumber TEXT,
        department TEXT,
        position TEXT,
        profilePicture TEXT,
        qrCodeData TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT,
        lastLogin TEXT,
        createdBy TEXT
      )
    ''');

    // User modifications table for offline sync
    await db.execute('''
      CREATE TABLE $_modificationsTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        modifiedBy TEXT NOT NULL,
        modifications TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL,
        syncedAt TEXT
      )
    ''');

    // Roles table
    await db.execute('''
      CREATE TABLE $_rolesTable (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        permissions TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  // User operations
  Future<void> insertUser(User user) async {
    final db = await database;
    await db.insert(
      _usersTable,
      _userToMap(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertUsers(List<User> users) async {
    final db = await database;
    final batch = db.batch();
    
    for (final user in users) {
      batch.insert(
        _usersTable,
        _userToMap(user),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit();
  }

  Future<User?> getUser(String id) async {
    final db = await database;
    final maps = await db.query(
      _usersTable,
      where: 'id = ? OR qrCodeData = ?',
      whereArgs: [id, id],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return _userFromMap(maps.first);
    }
    return null;
  }

  Future<List<User>> getUsers({
    String? search,
    String? role,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (username LIKE ? OR email LIKE ? OR firstName LIKE ? OR lastName LIKE ?)';
      final searchPattern = '%$search%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern, searchPattern]);
    }

    if (role != null && role.isNotEmpty) {
      whereClause += ' AND role = ?';
      whereArgs.add(role);
    }

    final maps = await db.query(
      _usersTable,
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => _userFromMap(map)).toList();
  }

  Future<int> getUsersCount({String? search, String? role}) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (search != null && search.isNotEmpty) {
      whereClause += ' AND (username LIKE ? OR email LIKE ? OR firstName LIKE ? OR lastName LIKE ?)';
      final searchPattern = '%$search%';
      whereArgs.addAll([searchPattern, searchPattern, searchPattern, searchPattern]);
    }

    if (role != null && role.isNotEmpty) {
      whereClause += ' AND role = ?';
      whereArgs.add(role);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_usersTable WHERE $whereClause',
      whereArgs.isNotEmpty ? whereArgs : null,
    );

    return result.first['count'] as int;
  }

  Future<void> updateUser(String id, Map<String, dynamic> updates) async {
    final db = await database;
    
    // Add updatedAt timestamp
    updates['updatedAt'] = DateTime.now().toIso8601String();
    
    await db.update(
      _usersTable,
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUser(String id) async {
    final db = await database;
    await db.delete(
      _usersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Modification tracking
  Future<void> insertModification(UserModification modification) async {
    final db = await database;
    await db.insert(
      _modificationsTable,
      _modificationToMap(modification),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<UserModification>> getUnsyncedModifications() async {
    final db = await database;
    final maps = await db.query(
      _modificationsTable,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) => _modificationFromMap(map)).toList();
  }

  Future<void> markModificationSynced(String modificationId) async {
    final db = await database;
    await db.update(
      _modificationsTable,
      {
        'synced': 1,
        'syncedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [modificationId],
    );
  }

  // Cache management
  Future<void> clearCache() async {
    final db = await database;
    await db.delete(_usersTable);
    await db.delete(_modificationsTable);
    await db.delete(_rolesTable);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Helper methods
  Map<String, dynamic> _userToMap(User user) {
    return {
      'id': user.id,
      'username': user.username,
      'email': user.email,
      'role': user.role,
      'firstName': user.firstName,
      'lastName': user.lastName,
      'phoneNumber': user.phoneNumber,
      'department': user.department,
      'position': user.position,
      'profilePicture': user.profilePicture,
      'qrCodeData': user.qrCodeData,
      'isActive': user.isActive ? 1 : 0,
      'createdAt': user.createdAt.toIso8601String(),
      'updatedAt': user.updatedAt?.toIso8601String(),
      'lastLogin': user.lastLogin?.toIso8601String(),
      'createdBy': user.createdBy,
    };
  }

  User _userFromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      department: map['department'] as String?,
      position: map['position'] as String?,
      profilePicture: map['profilePicture'] as String?,
      qrCodeData: map['qrCodeData'] as String?,
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null 
          ? DateTime.parse(map['updatedAt'] as String) 
          : null,
      lastLogin: map['lastLogin'] != null 
          ? DateTime.parse(map['lastLogin'] as String) 
          : null,
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> _modificationToMap(UserModification modification) {
    return {
      'id': modification.id,
      'userId': modification.userId,
      'modifiedBy': modification.modifiedBy,
      'modifications': jsonEncode(modification.modifications),
      'synced': modification.synced ? 1 : 0,
      'createdAt': modification.createdAt.toIso8601String(),
      'syncedAt': modification.syncedAt?.toIso8601String(),
    };
  }

  UserModification _modificationFromMap(Map<String, dynamic> map) {
    return UserModification(
      id: map['id'] as String,
      userId: map['userId'] as String,
      modifiedBy: map['modifiedBy'] as String,
      modifications: jsonDecode(map['modifications'] as String),
      synced: (map['synced'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      syncedAt: map['syncedAt'] != null 
          ? DateTime.parse(map['syncedAt'] as String) 
          : null,
    );
  }
}
