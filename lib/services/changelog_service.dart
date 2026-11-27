import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/changelog_dialog.dart';

class ChangelogService {
  static const _lastSeenVersionKey = 'changelog_last_seen_version';
  static const List<String> latestEntries = [
    'Menambahkan linimasa waktu (dibuat, tenggat, selesai) beserta indikator ketepatan waktu pada detail tugas.',
    'Memperbarui batas maksimal karakter menjadi 75 untuk judul dan 1.000 untuk deskripsi tugas.',
    'Mengoptimalkan layout halaman detail tugas agar lebih rapi dan responsif.',
  ];

  static Future<void> showIfNewVersion(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final versionKey = '${packageInfo.version}+${packageInfo.buildNumber}';
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString(_lastSeenVersionKey) == versionKey) return;
    if (!context.mounted) return;

    await _showDialog(context, packageInfo.version);

    final saved = await preferences.setString(_lastSeenVersionKey, versionKey);
    if (!saved) {
      throw StateError('Gagal menyimpan versi changelog yang sudah dilihat.');
    }
  }

  static Future<void> showLatest(BuildContext context) async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await _showDialog(context, packageInfo.version);
  }

  static Future<void> _showDialog(BuildContext context, String version) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          ChangelogDialog(version: version, entries: latestEntries),
    );
  }
}
