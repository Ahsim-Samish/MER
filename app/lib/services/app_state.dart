import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/repository.dart';
import '../models/domain.dart';
import '../models/mapping.dart';

/// Глобальное состояние приложения: текущий пользователь, репозиторий, схема
/// формы.
class AppState extends ChangeNotifier {
  AppState._(this.repository, this.schema);

  final ReportRepository repository;
  final FormSchema schema;

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  static Future<AppState> init() async {
    final db = await openAppDatabase();
    final repo = SqliteReportRepository(db);
    final rows = await loadMapping2FermerJson();
    final schema = FormSchema.fromRows(
      '2-фермер',
      rows.map(MappingRow.fromJson).toList(),
    );
    return AppState._(repo, schema);
  }

  Future<bool> login(int userId, String password) async {
    final u = await repository.login(userId, password);
    if (u == null) return false;
    _currentUser = u;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
