import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Инициализация SQLite на desktop/web. Возвращает фабрику.
Future<sqflite.DatabaseFactory> initDatabaseFactory() async {
  if (kIsWeb) {
    return databaseFactoryFfiWeb;
  }
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi;
}

Future<String> _resolveDbPath(sqflite.DatabaseFactory factory) async {
  if (kIsWeb) {
    return 'mer_app.db';
  }
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'mer_app.db');
}

/// Открывает базу и создаёт таблицы при необходимости + сидирует демо-данные.
Future<sqflite.Database> openAppDatabase() async {
  final factory = await initDatabaseFactory();
  final path = await _resolveDbPath(factory);
  final db = await factory.openDatabase(
    path,
    options: sqflite.OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async => _createSchema(db),
    ),
  );
  await _ensureSeed(db);
  return db;
}

Future<void> _createSchema(sqflite.Database db) async {
  final batch = db.batch();
  batch.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      login TEXT NOT NULL UNIQUE,
      district TEXT NOT NULL,
      password_hash TEXT NOT NULL
    );
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS organizations (
      id INTEGER PRIMARY KEY,
      region_code TEXT,
      okpo TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      konh TEXT,
      legal_form TEXT
    );
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS reports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      organization_id INTEGER NOT NULL REFERENCES organizations(id),
      form_type TEXT NOT NULL,
      period_start TEXT NOT NULL,
      period_end TEXT NOT NULL,
      version TEXT NOT NULL DEFAULT '11',
      updated_at TEXT NOT NULL
    );
  ''');
  batch.execute('''
    CREATE TABLE IF NOT EXISTS report_values (
      report_id INTEGER NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
      xml_tag TEXT NOT NULL,
      value TEXT,
      type_name TEXT NOT NULL DEFAULT 'Double',
      has_formula INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (report_id, xml_tag)
    );
  ''');
  batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_reports_org ON reports(organization_id);');
  batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_values_report ON report_values(report_id);');
  await batch.commit(noResult: true);
}

Future<void> _ensureSeed(sqflite.Database db) async {
  final users = await db.rawQuery('SELECT COUNT(*) AS c FROM users');
  if ((users.first['c'] as int) == 0) {
    await _seedUsers(db);
  }
  final orgs = await db.rawQuery('SELECT COUNT(*) AS c FROM organizations');
  if ((orgs.first['c'] as int) == 0) {
    await _seedOrganizations(db);
  }
}

Future<void> _seedUsers(sqflite.Database db) async {
  // Список районов из руководства пользователя.
  const districts = <(String, String)>[
    ('gus_bendery', 'ГУС г. Бендеры'),
    ('gus_tiraspol', 'ГУС г. Тирасполь и г. Днестровск'),
    ('rus_grigoriopol', 'РУС г. Григориополь и Григориопольский район'),
    ('rus_dubossary', 'РУС г. Дубоссары и Дубоссарский район'),
    ('rus_kamenka', 'РУС г. Каменка и Каменский район'),
    ('rus_rybnitsa', 'РУС г. Рыбница и Рыбницкий район'),
    ('rus_slobodzeya', 'РУС г. Слободзея и Слободзейский район'),
  ];
  final batch = db.batch();
  for (final (login, name) in districts) {
    batch.insert('users', {
      'login': login,
      'district': name,
      // Демо-пароль — `1234`; здесь хранится "хэш" в виде той же строки,
      // в проде заменить на bcrypt/argon2.
      'password_hash': '1234',
    });
  }
  await batch.commit(noResult: true);
}

Future<void> _seedOrganizations(sqflite.Database db) async {
  // Минимальная заглушка — несколько организаций из примера XML/руководства.
  // Реальные данные подгружаются из боевой БД через ReportRepository.
  final samples = <Map<String, Object?>>[
    {
      'id': 2520,
      'region_code': '2826',
      'okpo': '37483563',
      'name': 'ОБЩ.ОРГ."СОЮЗ ХУДОЖНИКОВ ПРИДНЕСТРОВЬЯ"',
      'konh': '98400',
      'legal_form': '83',
    },
    {
      'id': 10869,
      'region_code': '2826',
      'okpo': '02167810',
      'name': 'ОБЩ.ОРГ."ШКОЛА ВОСТОЧНОГО ТАНЦА ИРИНЫ ЗЕМЦОВОЙ ДИВИЯ"',
      'konh': '98400',
      'legal_form': '83',
    },
    {
      'id': 5004,
      'region_code': '2826',
      'okpo': '02740008',
      'name': 'МП "СУ МОЛОДЕЖНЫХ ЖИЛЫХ КОМПЛЕКСОВ МЖКСТРОЙ"',
      'konh': '63200',
      'legal_form': '83',
    },
    // Организация из примера 2-фермер.
    {
      'id': 3017,
      'region_code': '0299',
      'okpo': '3017',
      'name': 'АРТЕМОВ С.В. с.Воронково',
      'konh': null,
      'legal_form': null,
    },
  ];
  final batch = db.batch();
  for (final s in samples) {
    batch.insert('organizations', s,
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);
}

/// Загружает таблицу сопоставления для формы 2-фермер из ассетов.
Future<List<Map<String, Object?>>> loadMapping2FermerJson() async {
  final raw = await rootBundle.loadString('assets/mapping_2fermer.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final rows = (data['rows'] as List).cast<Map<String, dynamic>>();
  return rows;
}
