import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class AgentProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> agent;
  final bool loadLatestProfile;

  const AgentProfileEditPage({
    super.key,
    required this.agent,
    this.loadLatestProfile = false,
  });

  @override
  State<AgentProfileEditPage> createState() => _AgentProfileEditPageState();
}

class _AgentProfileEditPageState extends State<AgentProfileEditPage> {
  static const Color _primary = Color(0xFF1565C0);
  static const Color _textPrimary = Color(0xFF1E293B);
  static const Color _textSecondary = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  DateTime? _birthDate;
  bool _birthDateLocked = false;
  bool _isLoadingProfile = false;
  String? _profileLoadError;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _profilePhotoBytes;
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String? _photoError;
  String? _photoLoadError;
  bool _isLoadingPhoto = true;
  bool _removeProfilePhoto = false;
  bool _isSaving = false;
  bool _isEditingPhoto = false;

  String _firstValue(List<String> keys) {
    for (final key in keys) {
      final value = widget.agent[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') {
        return value;
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: _firstValue(['NOMOR_HP', 'I_TELEPON_HP', 'NO_HP', 'nomorHp']),
    );
    _emailController = TextEditingController(
      text: _firstValue(['A_EMAIL', 'EMAIL', 'email']),
    );
    _addressController = TextEditingController(
      text: _firstValue(['ALAMAT', 'A_RUMAH', 'ALAMAT_USER']),
    );
    _birthDate = _parseBirthDate();
    _birthDateLocked = _birthDate != null;
    if (widget.loadLatestProfile) {
      _loadLatestProfile();
    }
    _loadProfilePhoto();
  }

  Future<void> _loadProfilePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
      _photoLoadError = null;
    });
    try {
      final photo = await ApiService.getMyProfilePhoto();
      if (!mounted) return;
      setState(() {
        _profilePhotoBytes = photo;
        _isLoadingPhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _photoLoadError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingPhoto = false;
      });
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_isSaving || _isEditingPhoto) return;
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      setState(() {
        _photoError = 'Edit foto tersedia di Android, iOS, dan web.';
      });
      return;
    }

    setState(() {
      _isEditingPhoto = true;
      _photoError = null;
    });

    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;

      final uiSettings = <PlatformUiSettings>[
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          AndroidUiSettings(
            toolbarTitle: 'Edit foto profil',
            toolbarColor: _primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: _primary,
            lockAspectRatio: false,
            initAspectRatio: CropAspectRatioPreset.original,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
          IOSUiSettings(
            title: 'Edit foto profil',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        if (kIsWeb)
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
      ];
      final croppedImage = await ImageCropper().cropImage(
        sourcePath: image.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        maxWidth: 1200,
        maxHeight: 1200,
        uiSettings: uiSettings,
      );
      if (croppedImage == null || !mounted) return;

      final bytes = await croppedImage.readAsBytes();
      if (!mounted) return;
      final validationError = _validateProfilePhoto(bytes);
      if (validationError != null) {
        setState(() {
          _photoError = validationError;
        });
        return;
      }

      setState(() {
        _photoError = null;
        _selectedPhotoBytes = bytes;
        _selectedPhotoName = 'profile-photo.jpg';
        _removeProfilePhoto = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _photoError =
            'Foto gagal dipilih: '
            '${error.toString().replaceFirst('Exception: ', '')}';
      });
    } finally {
      if (mounted) setState(() => _isEditingPhoto = false);
    }
  }

  String? _validateProfilePhoto(Uint8List bytes) {
    if (bytes.isEmpty) return 'File foto kosong.';
    if (bytes.length > 5 * 1024 * 1024) {
      return 'Ukuran foto maksimal 5 MB.';
    }

    final isJpeg =
        bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
    final isPng =
        bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a;
    final isWebP =
        bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
    if (!isJpeg && !isPng && !isWebP) {
      return 'Format foto harus JPEG, PNG, atau WebP.';
    }
    return null;
  }

  Future<void> _loadLatestProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _profileLoadError = null;
    });

    try {
      final latestProfile = await ApiService.getCurrentUser();
      if (!mounted) return;

      widget.agent.addAll(latestProfile);
      _phoneController.text = _firstValue([
        'NOMOR_HP',
        'I_TELEPON_HP',
        'NO_HP',
        'nomorHp',
      ]);
      _emailController.text = _firstValue(['A_EMAIL', 'EMAIL', 'email']);
      _addressController.text = _firstValue([
        'ALAMAT',
        'A_RUMAH',
        'ALAMAT_USER',
      ]);
      _birthDate = _parseBirthDate();
      _birthDateLocked = _birthDate != null;
      setState(() => _isLoadingProfile = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileLoadError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingProfile = false;
      });
    }
  }

  DateTime? _parseBirthDate() {
    final value = _firstValue([
      'TANGGAL_LAHIR_ISO',
      'TANGGAL_LAHIR',
      'D_LAHIR',
      'tanggalLahir',
    ]);
    if (value.isEmpty || value == '-') return null;

    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final months = {
      'januari': 1,
      'februari': 2,
      'maret': 3,
      'april': 4,
      'mei': 5,
      'juni': 6,
      'juli': 7,
      'agustus': 8,
      'september': 9,
      'oktober': 10,
      'november': 11,
      'desember': 12,
    };
    final match = RegExp(r'^(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})$')
        .firstMatch(value);
    if (match == null) return null;

    final month = months[match.group(2)!.toLowerCase()];
    if (month == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!RegExp(r'^[0-9+().\-\s]{8,20}$').hasMatch(phone)) {
      return 'Masukkan nomor telepon yang valid.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;
    if (email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    final address = value?.trim() ?? '';
    if (address.isEmpty) return null;
    if (address.length > 500) return 'Alamat maksimal 500 karakter.';
    return null;
  }

  Future<void> _saveProfile() async {
    if (_isLoadingProfile ||
        _profileLoadError != null ||
        _isEditingPhoto ||
        _isSaving ||
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await ApiService.updateMyAgentProfile(
        phone: _optionalFormValue(_phoneController.text),
        email: _optionalFormValue(_emailController.text),
        address: _optionalFormValue(_addressController.text),
        birthDate: _birthDate == null || _birthDateLocked
            ? null
            : '${_birthDate!.year.toString().padLeft(4, '0')}-'
                  '${_birthDate!.month.toString().padLeft(2, '0')}-'
                  '${_birthDate!.day.toString().padLeft(2, '0')}',
        photoBytes: _selectedPhotoBytes,
        photoFilename: _selectedPhotoName,
        removePhoto: _removeProfilePhoto,
      );
      final data = response['data'] as Map<String, dynamic>;
      final user = data['user'];
      if (user is! Map) {
        throw Exception('Data profil dari server tidak valid.');
      }

      if (mounted) {
        Navigator.of(context).pop(Map<String, dynamic>.from(user));
      }
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil gagal disimpan: $message'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _optionalFormValue(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _selectBirthDate() async {
    if (_birthDateLocked || _isSaving) return;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal lahir',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: _primary),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _primary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFD),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDCE6F2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines == 1 ? 1 : 3,
      maxLength: maxLines == 1 ? null : 500,
      textCapitalization: textCapitalization,
      textInputAction: maxLines == 1
          ? TextInputAction.next
          : TextInputAction.newline,
      decoration: _inputDecoration(label: label, hint: hint, icon: icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F7FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(
            color: _textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              children: [
                if (_isLoadingProfile) ...[
                  const LinearProgressIndicator(
                    color: _primary,
                    backgroundColor: Color(0xFFDCEBFF),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_profileLoadError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFB91C1C),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Profil terbaru gagal dimuat: $_profileLoadError',
                            style: const TextStyle(
                              color: Color(0xFF991B1B),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoadingProfile
                              ? null
                              : _loadLatestProfile,
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260D47A1),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0x2FFFFFFF),
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                        ),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.contact_mail_outlined,
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Kontak',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Perbarui nomor telepon, email, dan alamat Anda.',
                              style: TextStyle(
                                color: Color(0xFFDCEBFF),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5EDF7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C0D47A1),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: const Color(0xFFEAF3FF),
                        child:
                            _removeProfilePhoto ||
                                (_selectedPhotoBytes ?? _profilePhotoBytes) ==
                                    null
                            ? const Icon(
                                Icons.person_outline_rounded,
                                color: _primary,
                                size: 52,
                              )
                            : ClipOval(
                                child: Image.memory(
                                  _selectedPhotoBytes ?? _profilePhotoBytes!,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person_outline_rounded,
                                    color: _primary,
                                    size: 52,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Foto profil',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JPEG, PNG, atau WebP · Maksimal 5 MB',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                      if (_isLoadingPhoto) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primary,
                          ),
                        ),
                      ],
                      if (_isEditingPhoto) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Menyiapkan foto...',
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                        ),
                      ],
                      if (_photoLoadError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Foto lama gagal dimuat: $_photoLoadError',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoadingPhoto ? null : _loadProfilePhoto,
                          child: const Text('Muat ulang foto'),
                        ),
                      ],
                      if (_photoError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Foto tidak dapat digunakan: $_photoError',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isSaving || _isEditingPhoto
                                ? null
                                : _pickProfilePhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(
                              _selectedPhotoBytes == null
                                  ? 'Pilih foto'
                                  : 'Ganti pilihan',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: Color(0xFFBBD5F5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                          ),
                          if (_selectedPhotoBytes != null)
                            TextButton.icon(
                              onPressed: _isSaving || _isEditingPhoto
                                  ? null
                                  : () => setState(() {
                                      _selectedPhotoBytes = null;
                                      _selectedPhotoName = null;
                                      _photoError = null;
                                    }),
                              icon: const Icon(Icons.undo_rounded),
                              label: const Text('Batalkan pilihan'),
                            )
                          else if (_removeProfilePhoto)
                            TextButton.icon(
                              onPressed: _isSaving || _isEditingPhoto
                                  ? null
                                  : () => setState(
                                      () => _removeProfilePhoto = false,
                                    ),
                              icon: const Icon(Icons.undo_rounded),
                              label: const Text('Batalkan hapus'),
                            )
                          else if (_profilePhotoBytes != null)
                            OutlinedButton.icon(
                              onPressed: _isSaving || _isEditingPhoto
                                  ? null
                                  : () => setState(() {
                                      _removeProfilePhoto = true;
                                      _photoError = null;
                                    }),
                              icon: const Icon(Icons.delete_outline_rounded),
                              label: const Text('Hapus foto'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB91C1C),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFBBD5F5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE5EDF7)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C0D47A1),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail yang dapat diubah',
                        style: TextStyle(
                          color: _textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Isi data yang ingin diperbarui.',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 25),
                      _buildField(
                        label: 'Nomor telepon',
                        hint: 'Contoh: 081234567890',
                        icon: Icons.phone_outlined,
                        controller: _phoneController,
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Email',
                        hint: 'nama@email.com',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Alamat',
                        hint: 'Masukkan alamat lengkap',
                        icon: Icons.location_on_outlined,
                        controller: _addressController,
                        validator: _validateAddress,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 18),
                      InkWell(
                        onTap: _birthDateLocked ? null : _selectBirthDate,
                        borderRadius: BorderRadius.circular(15),
                        child: InputDecorator(
                          decoration:
                              _inputDecoration(
                                label: 'Tanggal lahir',
                                hint: 'Pilih tanggal lahir',
                                icon: Icons.cake_outlined,
                              ).copyWith(
                                enabled: !_birthDateLocked,
                                suffixIcon: Icon(
                                  _birthDateLocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.calendar_month_outlined,
                                  color: _birthDateLocked
                                      ? _textSecondary
                                      : _primary,
                                  size: 20,
                                ),
                              ),
                          child: Text(
                            _birthDate == null
                                ? 'Belum diisi'
                                : _formatBirthDate(_birthDate!),
                            style: TextStyle(
                              color: _birthDate == null
                                  ? _textSecondary
                                  : _textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _birthDateLocked
                                ? Icons.lock_outline_rounded
                                : Icons.info_outline_rounded,
                            size: 15,
                            color: _textSecondary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _birthDateLocked
                                  ? 'Tanggal lahir sudah tersimpan dan dikunci agar tidak dapat diubah.'
                                  : 'Tanggal lahir dapat diisi satu kali dan tidak dapat diubah setelah disimpan.',
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x260D47A1),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed:
                    _isSaving ||
                        _isEditingPhoto ||
                        _isLoadingProfile ||
                        _profileLoadError != null
                    ? null
                    : _saveProfile,
                icon: _isSaving || _isEditingPhoto || _isLoadingProfile
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isLoadingProfile
                      ? 'Memuat profil...'
                      : _isSaving
                      ? 'Menyimpan...'
                      : _isEditingPhoto
                      ? 'Menyiapkan foto...'
                      : 'Simpan perubahan',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  disabledForegroundColor: Colors.white70,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
