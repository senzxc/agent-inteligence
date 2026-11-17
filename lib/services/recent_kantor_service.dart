import 'package:shared_preferences/shared_preferences.dart';

class RecentKantorService {
  static const int maxRecentOffices = 5;
  static const String _storagePrefix = 'recently_opened_kantor_';

  static String _userId(Map user) {
    final id =
        (user['I_AGEN'] ??
                user['NOMOR_AGEN'] ??
                user['STAMBUK'] ??
                user['stambuk'] ??
                '')
            .toString()
            .trim();
    if (id.isEmpty) {
      throw StateError('ID pengguna tidak tersedia untuk menyimpan riwayat.');
    }
    return id.toLowerCase();
  }

  static Future<List<String>> loadRecentOfficeCodes(Map user) async {
    final preferences = await SharedPreferences.getInstance();
    final codes =
        preferences.getStringList('$_storagePrefix${_userId(user)}') ??
        const <String>[];
    return codes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .take(maxRecentOffices)
        .toList(growable: false);
  }

  static Future<void> recordOpenedOffice({
    required Map user,
    required String officeCode,
  }) async {
    final code = officeCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw ArgumentError.value(
        officeCode,
        'officeCode',
        'Kode kantor wajib diisi.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final key = '$_storagePrefix${_userId(user)}';
    final codes = preferences.getStringList(key) ?? <String>[];
    codes.removeWhere((savedCode) => savedCode.trim().toUpperCase() == code);
    codes.insert(0, code);
    if (codes.length > maxRecentOffices) {
      codes.removeRange(maxRecentOffices, codes.length);
    }

    if (!await preferences.setStringList(key, codes)) {
      throw StateError('Riwayat cabang tidak dapat disimpan di perangkat.');
    }
  }
}
