import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/agency_role.dart';
import 'agent_profile_photo.dart';

Future<void> showAgentDetailsDialog(
  BuildContext context,
  Map<String, dynamic> agent,
) {
  final name = (agent['NAMA_AGEN'] ?? '-').toString();
  final agentId = (agent['NOMOR_AGEN'] ?? agent['I_AGEN'] ?? '')
      .toString()
      .trim();
  final photoFuture = agentId.isEmpty
      ? Future<Uint8List?>.value()
      : ApiService.getAgentProfilePhoto(agentId);
  final agentNumber = (agent['NOMOR_AGEN'] ?? '-').toString();
  final namaKantor = (agent['NAMA_KANTOR'] ?? '').toString().trim();
  final kodeKantor = (agent['KODE_KANTOR'] ?? '').toString().trim();
  final kantor = namaKantor.isNotEmpty
      ? (kodeKantor.isNotEmpty ? '$namaKantor - ($kodeKantor)' : namaKantor)
      : (kodeKantor.isNotEmpty ? kodeKantor : '-');
  final tracking = agent['isTracking'] == true;
  final alamat = (agent['ALAMAT'] ?? 'Belum tersedia').toString().trim();
  final email = (agent['A_EMAIL'] ?? agent['EMAIL'] ?? 'Belum tersedia')
      .toString()
      .trim();
  final phone = (agent['NOMOR_HP'] ?? 'Belum tersedia').toString().trim();
  final jabatan = formatAgencyRole(
    (agent['C_AGENCY_JABATAN'] ?? 'Belum tersedia').toString(),
  );
  final tanggalLahir = (agent['TANGGAL_LAHIR'] ?? 'Belum tersedia')
      .toString()
      .trim();
  final statusColor = tracking
      ? const Color(0xFF15803D)
      : const Color(0xFF64748B);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.86,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 22, 16, 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1B72D7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    FutureBuilder<Uint8List?>(
                      future: photoFuture,
                      builder: (context, snapshot) {
                        return AgentProfilePhoto(
                          photoBytes: snapshot.data,
                          size: 54,
                          circleThumbnail: true,
                          semanticLabel: 'Perbesar foto profil $name',
                          placeholder: Text(
                            _agentInitials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROFIL AGEN',
                            style: TextStyle(
                              color: Color(0xFFDCEBFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tracking
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              tracking ? 'Sedang tracking' : 'Offline',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'INFORMASI AGEN',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _agentDetailTile(
                        icon: Icons.badge_outlined,
                        label: 'Nomor Agen',
                        value: agentNumber,
                      ),
                      _agentDetailTile(
                        icon: Icons.work_outline,
                        label: 'Jabatan',
                        value: jabatan,
                      ),
                      _agentDetailTile(
                        icon: Icons.apartment_rounded,
                        label: 'Kantor',
                        value: kantor,
                      ),
                      _agentDetailTile(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: alamat.isEmpty ? 'Belum tersedia' : alamat,
                      ),
                      _agentDetailTile(
                        icon: Icons.phone_outlined,
                        label: 'Nomor HP',
                        value: phone.isEmpty ? 'Belum tersedia' : phone,
                      ),
                      _agentDetailTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email.isEmpty ? 'Belum tersedia' : email,
                      ),
                      _agentDetailTile(
                        icon: Icons.cake_outlined,
                        label: 'Tanggal Lahir',
                        value: tanggalLahir,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE8EEF6))),
                ),
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Tutup'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _agentDetailTile({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFD),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8EEF6)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F0FF),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: const Color(0xFF1565C0), size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF14264D),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _agentInitials(String name) {
  final trimmedName = name.trim();
  return trimmedName.isEmpty
      ? '??'
      : trimmedName.characters.take(2).toString().toUpperCase();
}
