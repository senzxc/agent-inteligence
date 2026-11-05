const Map<String, String> _agencyRoleNames = {
  'KD': 'Kepala Pemasaran',
  'AD': 'Agen Director',
  'AM': 'Agen Manager',
  'AS': 'Agen Supervisor',
  'WA': 'Wakil Agen',
};

String formatAgencyRole(String role) {
  final normalizedRole = role.trim().toUpperCase();
  final fullName = _agencyRoleNames[normalizedRole];

  if (fullName == null) return role.trim();
  return '$normalizedRole ($fullName)';
}
