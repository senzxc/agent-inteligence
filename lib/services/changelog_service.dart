import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/changelog_dialog.dart';

class ChangelogService {
  static const _lastSeenVersionKey = 'changelog_last_seen_version';
  static const List<String> latestEntries = [
    'Daftar tugas diurutkan berdasarkan tanggal dan jam tenggat, dari yang terdekat.',
    'Pilih semua dan hapus massal hanya berlaku untuk tugas yang tampil sesuai filter aktif.',
    'Detail tugas selesai kini menampilkan waktu penyelesaiannya.',
    'Optimalisasi layout pada detail tugas.',
    'Menambahkan tombol kiri/kanan pada pemilihan bulan dan tahun.',
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
