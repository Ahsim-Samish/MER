import 'package:sqflite/sqflite.dart' as sqflite;

import '../models/domain.dart';

/// Интерфейс хранилища отчётов. SQLite-реализация ниже; под боевую БД
/// (Postgres/MS SQL) можно реализовать тот же интерфейс отдельно.
abstract class ReportRepository {
  Future<AppUser?> login(int userId, String password);
  Future<List<AppUser>> listUsers();
  Future<List<Organization>> searchOrganizations(String query);
  Future<List<Report>> listReports(int organizationId);
  Future<Organization?> getOrganization(int id);
  Future<Report> createReport({
    required int organizationId,
    required String formType,
    required DateTime periodStart,
    required DateTime periodEnd,
    String version = '11',
  });
  Future<Map<String, ReportValue>> loadValues(int reportId);
  Future<void> saveValues(int reportId, List<ReportValue> values);
  Future<void> deleteReport(int reportId);
}

class SqliteReportRepository implements ReportRepository {
  final sqflite.Database db;
  SqliteReportRepository(this.db);

  @override
  Future<AppUser?> login(int userId, String password) async {
    final rows = await db.query('users',
        where: 'id = ? AND password_hash = ?',
        whereArgs: [userId, password],
        limit: 1);
    if (rows.isEmpty) return null;
    return AppUser.fromRow(rows.first);
  }

  @override
  Future<List<AppUser>> listUsers() async {
    final rows = await db.query('users', orderBy: 'district ASC');
    return rows.map(AppUser.fromRow).toList();
  }

  @override
  Future<List<Organization>> searchOrganizations(String query) async {
    final q = query.trim();
    List<Map<String, Object?>> rows;
    if (q.isEmpty) {
      rows = await db.query('organizations', orderBy: 'okpo ASC');
    } else {
      rows = await db.query(
        'organizations',
        where: 'okpo LIKE ? OR name LIKE ?',
        whereArgs: ['%$q%', '%$q%'],
        orderBy: 'okpo ASC',
      );
    }
    return rows.map(Organization.fromRow).toList();
  }

  @override
  Future<Organization?> getOrganization(int id) async {
    final rows = await db.query('organizations',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Organization.fromRow(rows.first);
  }

  @override
  Future<List<Report>> listReports(int organizationId) async {
    final rows = await db.query('reports',
        where: 'organization_id = ?',
        whereArgs: [organizationId],
        orderBy: 'period_start DESC');
    return rows.map(Report.fromRow).toList();
  }

  @override
  Future<Report> createReport({
    required int organizationId,
    required String formType,
    required DateTime periodStart,
    required DateTime periodEnd,
    String version = '11',
  }) async {
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('reports', {
      'organization_id': organizationId,
      'form_type': formType,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
      'version': version,
      'updated_at': now,
    });
    final rows = await db.query('reports',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return Report.fromRow(rows.first);
  }

  @override
  Future<Map<String, ReportValue>> loadValues(int reportId) async {
    final rows = await db.query('report_values',
        where: 'report_id = ?', whereArgs: [reportId]);
    final out = <String, ReportValue>{};
    for (final r in rows) {
      final tag = r['xml_tag'] as String;
      out[tag] = ReportValue(
        reportId: reportId,
        xmlTag: tag,
        value: r['value'] as String?,
        typeName: (r['type_name'] ?? 'Double') as String,
        hasFormula: (r['has_formula'] as int? ?? 0) != 0,
      );
    }
    return out;
  }

  @override
  Future<void> saveValues(int reportId, List<ReportValue> values) async {
    await db.transaction((tx) async {
      for (final v in values) {
        await tx.insert(
          'report_values',
          {
            'report_id': reportId,
            'xml_tag': v.xmlTag,
            'value': v.value,
            'type_name': v.typeName,
            'has_formula': v.hasFormula ? 1 : 0,
          },
          conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
        );
      }
      await tx.update(
        'reports',
        {'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });
  }

  @override
  Future<void> deleteReport(int reportId) async {
    await db.delete('reports', where: 'id = ?', whereArgs: [reportId]);
  }
}
