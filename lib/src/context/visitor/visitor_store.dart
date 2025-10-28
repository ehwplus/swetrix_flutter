import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SwetrixVisitorStore {
  SwetrixVisitorStore({SharedPreferences? sharedPreferences})
      : _sharedPrefs = sharedPreferences != null ? Future.value(sharedPreferences) : SharedPreferences.getInstance();

  final Future<SharedPreferences> _sharedPrefs;
  static const _uuid = Uuid();

  Future<String> ensureVisitorId(String projectId) async {
    final prefs = await _sharedPrefs;
    final key = _visitorKey(projectId);
    final existingUuid = prefs.getString(key);
    if (existingUuid != null && existingUuid.isNotEmpty) {
      return existingUuid;
    }

    final generated = _uuid.v4();
    await prefs.setString(key, generated);
    return generated;
  }

  Future<bool> hasTrackedUnique(String projectId) async {
    final prefs = await _sharedPrefs;
    return prefs.getBool(_uniqueKey(projectId)) ?? false;
  }

  Future<void> markUniqueTracked(String projectId) async {
    final prefs = await _sharedPrefs;
    await prefs.setBool(_uniqueKey(projectId), true);
  }

  Future<void> reset(String projectId) async {
    final prefs = await _sharedPrefs;
    await prefs.remove(_visitorKey(projectId));
    await prefs.remove(_uniqueKey(projectId));
  }

  String _visitorKey(String projectId) => 'swetrix_visitor_id_$projectId';

  String _uniqueKey(String projectId) => 'swetrix_unique_tracked_$projectId';
}
