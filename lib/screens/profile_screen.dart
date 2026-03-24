import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:almadar/core/theme.dart';

class ProfileScreen extends StatefulWidget {
  final String? uid;
  const ProfileScreen({super.key, this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  bool _isLoading = true;

  late bool isMyProfile;
  late String targetUid;
  late bool isCurrentUserAdmin;

  String _name = '';
  String _email = '';
  String _bio = '';

  final _nameController = TextEditingController();
  final _bioController = TextEditingController();

  static const String _adminUid = '2vQk2uX6iWe2iRFT8z3hD6Z6g2K2';
  static const String _adminEmail = 'hmwshy402@gmail.com';

  @override
  void initState() {
    super.initState();
    isMyProfile = widget.uid == null || widget.uid == currentUser?.uid;
    targetUid = widget.uid ?? currentUser?.uid ?? '';
    isCurrentUserAdmin =
        currentUser?.uid == _adminUid || currentUser?.email == _adminEmail;

    if (targetUid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } else {
      _loadProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final snapshot = await _usersRef.child(targetUid).get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _name = data['name'] ?? 'مستخدم';
          _bio = data['bio'] ?? '';
          _email = data['email'] ?? '';
          _nameController.text = _name;
          _bioController.text = _bio;
        });
      } else if (isMyProfile && currentUser != null) {
        setState(() {
          _name = currentUser!.displayName ?? 'مستخدم';
          _email = currentUser!.email ?? '';
          _nameController.text = _name;
          _bioController.text = _bio;
        });
        await _saveProfileData();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfileData() async {
    setState(() => _name = _nameController.text);
    setState(() => _bio = _bioController.text);
    await _usersRef.child(targetUid).update({'name': _name, 'bio': _bio});
    await currentUser?.updateDisplayName(_name);
  }

  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff161616),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'تعديل الملف الشخصي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildEditField('الاسم', _nameController, Icons.person_outline),
              const SizedBox(height: 14),
              _buildEditField(
                'النبذة الشخصية',
                _bioController,
                Icons.info_outline,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _saveProfileData();
                    setState(() {});
                  },
                  child: const Text(
                    'حفظ التغييرات',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      textDirection: TextDirection.rtl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accentBlue, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue),
        ),
      );
    }

    bool isProfileAdmin = targetUid == _adminUid || _email == _adminEmail;

    // Edit button is only shown if the current user is the main system admin
    bool canEdit = isCurrentUserAdmin;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              onPressed: _showEditSheet,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ─── Hero Header ───
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 120, bottom: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.accentBlue.withOpacity(0.25),
                      Colors.black,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // Profile picture
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isProfileAdmin
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.accentBlue,
                                      Colors.purple,
                                    ],
                                  )
                                : null,
                            color: isProfileAdmin ? null : Colors.white12,
                          ),
                        ),
                        Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage('assets/images/logo.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        if (isProfileAdmin)
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.accentBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Name row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isProfileAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.accentBlue,
                            size: 22,
                          ),
                        ],
                      ],
                    ),
                    if (isProfileAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.accentBlue.withOpacity(0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: AppColors.accentBlue,
                              size: 14,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'حساب رسمي',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      isMyProfile ? '● متصل الآن' : '○ آخر ظهور مؤخراً',
                      style: TextStyle(
                        color: isMyProfile
                            ? Colors.greenAccent
                            : Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Action Buttons ───
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: isMyProfile
                      ? [
                          if (canEdit)
                            _buildActionBtn(
                              'تعديل الملف',
                              Icons.edit_rounded,
                              AppColors.accentBlue,
                              _showEditSheet,
                            ),
                        ]
                      : [
                          _buildActionBtn(
                            'مراسلة',
                            Icons.chat_bubble_rounded,
                            AppColors.accentBlue,
                            () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          _buildActionBtn(
                            'إبلاغ',
                            Icons.report_rounded,
                            Colors.redAccent,
                            () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم الإبلاغ')),
                              );
                            },
                          ),
                        ],
                ),
              ),

              // ─── Info Panel ───
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xff111111),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    if (_bio.isNotEmpty) ...[
                      _infoRow(Icons.info_outline, 'النبذة', _bio),
                      const Divider(color: Colors.white10, height: 30),
                    ],
                    _infoRow(
                      Icons.badge_rounded,
                      'الحساب',
                      isProfileAdmin ? 'مدير المنصة' : 'عضو',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
