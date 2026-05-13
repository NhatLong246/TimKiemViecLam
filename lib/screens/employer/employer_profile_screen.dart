import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/employer_profile_controller.dart';
import '../../data/models/user_model.dart';
import '../../routes/app_routes.dart';

class EmployerProfileScreen extends StatelessWidget {
  const EmployerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EmployerProfileController());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.employerPrimary),
          );
        }
        final profile = ctrl.profile.value;
        if (profile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                const Text('Không thể tải hồ sơ', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: ctrl.loadProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: AppColors.employerPrimary,
          onRefresh: ctrl.loadProfile,
          child: CustomScrollView(
            slivers: [
              _buildHeader(context, ctrl, profile),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _PersonalSection(ctrl: ctrl, profile: profile),
                      const SizedBox(height: 16),
                      _CompanySection(ctrl: ctrl, profile: profile),
                      const SizedBox(height: 16),
                      _AccountSection(ctrl: ctrl),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ─── Header SliverAppBar ──────────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    EmployerProfileController ctrl,
    UserModel profile,
  ) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.employerGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 8),
                // Avatar / Logo công ty
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withAlpha(51),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: ClipOval(
                        child: profile.companyLogoUrl != null &&
                                profile.companyLogoUrl!.isNotEmpty
                            ? Image.network(
                                profile.companyLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _defaultLogo(profile),
                              )
                            : profile.avatarUrl != null &&
                                    profile.avatarUrl!.isNotEmpty
                                ? Image.network(
                                    profile.avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _defaultLogo(profile),
                                  )
                                : _defaultLogo(profile),
                      ),
                    ),
                    // Camera button
                    GestureDetector(
                      onTap: () => ctrl.uploadAvatar(),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: AppColors.employerPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Tên
                Text(
                  profile.companyName?.isNotEmpty == true
                      ? profile.companyName!
                      : profile.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  profile.email,
                  style: TextStyle(
                    color: Colors.white.withAlpha(204),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                // Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Badge(
                      icon: Icons.business_center,
                      label: 'Nhà tuyển dụng',
                      color: Colors.white.withAlpha(51),
                    ),
                    if (profile.isVerified) ...[
                      const SizedBox(width: 8),
                      _Badge(
                        icon: Icons.verified,
                        label: 'Đã xác minh',
                        color: Colors.green.withAlpha(153),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _defaultLogo(UserModel profile) {
    final initials = (profile.companyName?.isNotEmpty == true
            ? profile.companyName![0]
            : profile.firstName.isNotEmpty
                ? profile.firstName[0]
                : '?')
        .toUpperCase();
    return Container(
      color: Colors.white.withAlpha(51),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ─── Wallet Card ──────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final EmployerProfileController ctrl;
  final UserModel profile;

  const _WalletCard({required this.ctrl, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.employerGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.employerPrimary.withAlpha(77),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Ví doanh nghiệp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WalletStat(
                  label: 'Số dư',
                  value: ctrl.formatCurrency(profile.walletBalance),
                  icon: Icons.savings_outlined,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white30),
              Expanded(
                child: _WalletStat(
                  label: 'Tổng đã chi',
                  value: ctrl.formatCurrency(profile.totalSpent),
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WalletStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Personal Section ─────────────────────────────────────

class _PersonalSection extends StatelessWidget {
  final EmployerProfileController ctrl;
  final UserModel profile;

  const _PersonalSection({required this.ctrl, required this.profile});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa cập nhật';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _genderLabel(String? g) {
    switch (g) {
      case 'male':
        return 'Nam';
      case 'female':
        return 'Nữ';
      case 'other':
        return 'Khác';
      default:
        return 'Chưa cập nhật';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Người đại diện',
      icon: Icons.person_outline,
      onEditAll: () => _showEditPersonalDialog(context),
      children: [
        _InfoTile(
          icon: Icons.badge_outlined,
          label: 'Họ & Tên',
          value: profile.fullName.isNotEmpty ? profile.fullName : 'Chưa cập nhật',
          onTap: () => _showEditPersonalDialog(context),
        ),
        _InfoTile(
          icon: Icons.phone_outlined,
          label: 'Số điện thoại',
          value: profile.phone.isNotEmpty ? profile.phone : 'Chưa cập nhật',
          onTap: () => _showSingleFieldEdit(
            context,
            label: 'Số điện thoại',
            initialValue: profile.phone,
            keyboardType: TextInputType.phone,
            onSave: (v) => ctrl.savePersonalInfo(phone: v),
          ),
        ),
        _InfoTile(
          icon: Icons.wc_outlined,
          label: 'Giới tính',
          value: _genderLabel(profile.gender),
          onTap: () => _showGenderPicker(context),
        ),
        _InfoTile(
          icon: Icons.cake_outlined,
          label: 'Ngày sinh',
          value: _formatDate(profile.dateOfBirth),
          onTap: () => _showDatePicker(context),
        ),
        _InfoTile(
          icon: Icons.credit_card_outlined,
          label: 'CCCD/CMND',
          value: profile.cccd?.isNotEmpty == true ? profile.cccd! : 'Chưa cập nhật',
          onTap: () => _showSingleFieldEdit(
            context,
            label: 'Số CCCD/CMND',
            initialValue: profile.cccd ?? '',
            keyboardType: TextInputType.number,
            onSave: (v) => ctrl.savePersonalInfo(cccd: v),
          ),
        ),
      ],
    );
  }

  void _showEditPersonalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullPersonalEditSheet(ctrl: ctrl, profile: profile),
    );
  }

  void _showSingleFieldEdit(
    BuildContext context, {
    required String label,
    required String initialValue,
    required TextInputType keyboardType,
    required Future<bool> Function(String) onSave,
  }) {
    final textCtrl = TextEditingController(text: initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBottomSheet(
        title: 'Chỉnh sửa $label',
        children: [
          _SheetTextField(
            ctrl: textCtrl,
            label: label,
            keyboardType: keyboardType,
          ),
        ],
        onSave: () async {
          final ok = await onSave(textCtrl.text.trim());
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showGenderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerBottomSheet(
        title: 'Chọn giới tính',
        options: const [
          _PickerOption(value: 'male', label: 'Nam', icon: Icons.male),
          _PickerOption(value: 'female', label: 'Nữ', icon: Icons.female),
          _PickerOption(value: 'other', label: 'Khác', icon: Icons.people_outline),
        ],
        selectedValue: profile.gender,
        onSelect: (v) async {
          final ok = await ctrl.savePersonalInfo(gender: v);
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: profile.dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.employerPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      await ctrl.savePersonalInfo(dateOfBirth: picked);
    }
  }
}

// ─── Company Section ──────────────────────────────────────

class _CompanySection extends StatelessWidget {
  final EmployerProfileController ctrl;
  final UserModel profile;

  const _CompanySection({required this.ctrl, required this.profile});

  String _sizeLabel(String? s) {
    switch (s) {
      case '1-9':
        return '1–9 nhân viên';
      case '10-49':
        return '10–49 nhân viên';
      case '50-199':
        return '50–199 nhân viên';
      case '200+':
        return '200+ nhân viên';
      default:
        return 'Chưa cập nhật';
    }
  }

  String _typeLabel(String? t) {
    switch (t) {
      case 'individual':
        return 'Cá nhân / Hộ kinh doanh';
      case 'company':
        return 'Công ty / Doanh nghiệp';
      case 'cooperative':
        return 'Hợp tác xã';
      default:
        return 'Chưa cập nhật';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Thông tin doanh nghiệp',
      icon: Icons.business_outlined,
      onEditAll: () => _showEditCompanyDialog(context),
      children: [
        _InfoTile(
          icon: Icons.apartment_outlined,
          label: 'Tên doanh nghiệp',
          value: profile.companyName?.isNotEmpty == true
              ? profile.companyName!
              : 'Chưa cập nhật',
          onTap: () => _showSingleEdit(
            context,
            label: 'Tên doanh nghiệp',
            fieldKey: 'companyName',
            initial: profile.companyName ?? '',
          ),
        ),
        _InfoTile(
          icon: Icons.location_on_outlined,
          label: 'Địa chỉ',
          value: profile.companyAddress?.isNotEmpty == true
              ? profile.companyAddress!
              : 'Chưa cập nhật',
          onTap: () => _showSingleEdit(
            context,
            label: 'Địa chỉ doanh nghiệp',
            fieldKey: 'companyAddress',
            initial: profile.companyAddress ?? '',
          ),
        ),
        _InfoTile(
          icon: Icons.receipt_long_outlined,
          label: 'Mã số thuế',
          value: profile.companyTaxCode?.isNotEmpty == true
              ? profile.companyTaxCode!
              : 'Chưa cập nhật',
          onTap: () => _showSingleEdit(
            context,
            label: 'Mã số thuế',
            fieldKey: 'companyTaxCode',
            initial: profile.companyTaxCode ?? '',
            keyboardType: TextInputType.number,
          ),
        ),
        _InfoTile(
          icon: Icons.phone_outlined,
          label: 'Điện thoại công ty',
          value: profile.companyPhone?.isNotEmpty == true
              ? profile.companyPhone!
              : 'Chưa cập nhật',
          onTap: () => _showSingleEdit(
            context,
            label: 'Điện thoại công ty',
            fieldKey: 'companyPhone',
            initial: profile.companyPhone ?? '',
            keyboardType: TextInputType.phone,
          ),
        ),
        _InfoTile(
          icon: Icons.language_outlined,
          label: 'Website',
          value: profile.companyWebsite?.isNotEmpty == true
              ? profile.companyWebsite!
              : 'Chưa cập nhật',
          onTap: () => _showSingleEdit(
            context,
            label: 'Website',
            fieldKey: 'companyWebsite',
            initial: profile.companyWebsite ?? '',
            keyboardType: TextInputType.url,
          ),
        ),
        _InfoTile(
          icon: Icons.groups_outlined,
          label: 'Quy mô',
          value: _sizeLabel(profile.companySize),
          onTap: () => _showSizePicker(context),
        ),
        _InfoTile(
          icon: Icons.category_outlined,
          label: 'Loại hình',
          value: _typeLabel(profile.businessType),
          onTap: () => _showTypePicker(context),
        ),
        _InfoTile(
          icon: Icons.description_outlined,
          label: 'Giới thiệu',
          value: profile.companyDescription?.isNotEmpty == true
              ? profile.companyDescription!
              : 'Chưa cập nhật',
          maxLines: 3,
          onTap: () => _showSingleEdit(
            context,
            label: 'Giới thiệu doanh nghiệp',
            fieldKey: 'companyDescription',
            initial: profile.companyDescription ?? '',
            maxLines: 4,
          ),
        ),
      ],
    );
  }

  void _showSingleEdit(
    BuildContext context, {
    required String label,
    required String fieldKey,
    required String initial,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    final textCtrl = TextEditingController(text: initial);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBottomSheet(
        title: 'Chỉnh sửa $label',
        children: [
          _SheetTextField(
            ctrl: textCtrl,
            label: label,
            keyboardType: keyboardType,
            maxLines: maxLines,
          ),
        ],
        onSave: () async {
          final ok = await ctrl.updateSingleField(fieldKey, textCtrl.text.trim());
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditCompanyDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: profile.companyName ?? '');
    final addressCtrl = TextEditingController(text: profile.companyAddress ?? '');
    final taxCtrl = TextEditingController(text: profile.companyTaxCode ?? '');
    final phoneCtrl = TextEditingController(text: profile.companyPhone ?? '');
    final webCtrl = TextEditingController(text: profile.companyWebsite ?? '');
    final descCtrl = TextEditingController(text: profile.companyDescription ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditBottomSheet(
        title: 'Thông tin doanh nghiệp',
        children: [
          _SheetTextField(ctrl: nameCtrl, label: 'Tên doanh nghiệp'),
          const SizedBox(height: 12),
          _SheetTextField(ctrl: addressCtrl, label: 'Địa chỉ'),
          const SizedBox(height: 12),
          _SheetTextField(
              ctrl: taxCtrl,
              label: 'Mã số thuế',
              keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _SheetTextField(
              ctrl: phoneCtrl,
              label: 'Điện thoại',
              keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          _SheetTextField(
              ctrl: webCtrl, label: 'Website', keyboardType: TextInputType.url),
          const SizedBox(height: 12),
          _SheetTextField(ctrl: descCtrl, label: 'Giới thiệu', maxLines: 3),
        ],
        onSave: () async {
          final ok = await ctrl.saveCompanyInfo(
            companyName: nameCtrl.text.trim(),
            companyAddress: addressCtrl.text.trim(),
            companyTaxCode: taxCtrl.text.trim(),
            companyPhone: phoneCtrl.text.trim(),
            companyWebsite: webCtrl.text.trim(),
            companyDescription: descCtrl.text.trim(),
          );
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showSizePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerBottomSheet(
        title: 'Quy mô nhân sự',
        options: const [
          _PickerOption(value: '1-9', label: '1–9 nhân viên', icon: Icons.person),
          _PickerOption(value: '10-49', label: '10–49 nhân viên', icon: Icons.group),
          _PickerOption(
              value: '50-199', label: '50–199 nhân viên', icon: Icons.groups),
          _PickerOption(
              value: '200+',
              label: '200+ nhân viên',
              icon: Icons.corporate_fare),
        ],
        selectedValue: profile.companySize,
        onSelect: (v) async {
          final ok = await ctrl.saveCompanyInfo(companySize: v);
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showTypePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerBottomSheet(
        title: 'Loại hình doanh nghiệp',
        options: const [
          _PickerOption(
              value: 'individual',
              label: 'Cá nhân / Hộ kinh doanh',
              icon: Icons.person_outline),
          _PickerOption(
              value: 'company',
              label: 'Công ty / Doanh nghiệp',
              icon: Icons.business),
          _PickerOption(
              value: 'cooperative',
              label: 'Hợp tác xã',
              icon: Icons.handshake_outlined),
        ],
        selectedValue: profile.businessType,
        onSelect: (v) async {
          final ok = await ctrl.saveCompanyInfo(businessType: v);
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// ─── Account Section ──────────────────────────────────────

class _AccountSection extends StatelessWidget {
  final EmployerProfileController ctrl;

  const _AccountSection({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tài khoản',
      icon: Icons.settings_outlined,
      children: [
        // Đánh giá
        Obx(() {
          final avg = ctrl.profile.value?.averageRating ?? 0.0;
          final hasRating = avg > 0;
          return _MenuTile(
            icon: Icons.star_rate_outlined,
            label: 'Đánh giá từ ứng viên',
            iconColor: Colors.amber.shade700,
            trailing: hasRating
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star,
                            size: 13, color: Colors.amber.shade700),
                        const SizedBox(width: 3),
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                  )
                : null,
            onTap: () => Get.toNamed(AppRoutes.employerReviews),
          );
        }),
        _MenuTile(
          icon: Icons.lock_outline,
          label: 'Đổi mật khẩu',
          iconColor: AppColors.employerPrimary,
          onTap: () {
            // TODO: navigate to change password
          },
        ),
        _MenuTile(
          icon: Icons.manage_history_outlined,
          label: 'Lịch sử đăng nhập',
          iconColor: AppColors.employerSecondary,
          onTap: () => Get.toNamed(AppRoutes.employerLoginHistory),
        ),
        _MenuTile(
          icon: Icons.logout,
          label: 'Đăng xuất',
          iconColor: Colors.red,
          textColor: Colors.red,
          onTap: () => _confirmLogout(context),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ctrl.logout();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final VoidCallback? onEditAll;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.onEditAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.employerPrimary.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.employerPrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                if (onEditAll != null)
                  TextButton(
                    onPressed: onEditAll,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Chỉnh sửa',
                      style: TextStyle(
                        color: AppColors.employerPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final int maxLines;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF9E9E9E)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: value == 'Chưa cập nhật'
                          ? const Color(0xFFBDBDBD)
                          : const Color(0xFF333333),
                      fontStyle: value == 'Chưa cập nhật'
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? textColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.textColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor ?? const Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet Widgets ─────────────────────────────────

class _EditBottomSheet extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;

  const _EditBottomSheet({
    required this.title,
    required this.children,
    required this.onSave,
  });

  @override
  State<_EditBottomSheet> createState() => _EditBottomSheetState();
}

class _EditBottomSheetState extends State<_EditBottomSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          ...widget.children,
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSave();
                      if (mounted) setState(() => _saving = false);
                    },
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Lưu thay đổi',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetTextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType keyboardType;
  final int maxLines;

  const _SheetTextField({
    required this.ctrl,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.employerPrimary),
        ),
      ),
    );
  }
}

class _PickerOption {
  final String value;
  final String label;
  final IconData icon;

  const _PickerOption(
      {required this.value, required this.label, required this.icon});
}

class _PickerBottomSheet extends StatelessWidget {
  final String title;
  final List<_PickerOption> options;
  final String? selectedValue;
  final Future<void> Function(String) onSelect;

  const _PickerBottomSheet({
    required this.title,
    required this.options,
    required this.onSelect,
    this.selectedValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          ...options.map((opt) {
            final isSelected = selectedValue == opt.value;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.employerPrimary.withAlpha(26)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  opt.icon,
                  size: 20,
                  color: isSelected
                      ? AppColors.employerPrimary
                      : const Color(0xFF9E9E9E),
                ),
              ),
              title: Text(
                opt.label,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.employerPrimary
                      : const Color(0xFF333333),
                ),
              ),
              trailing: isSelected
                  ? const Icon(Icons.check_circle,
                      color: AppColors.employerPrimary)
                  : null,
              onTap: () => onSelect(opt.value),
            );
          }),
        ],
      ),
    );
  }
}

// ─── Full Personal Edit Sheet ─────────────────────────────────────────────

class _FullPersonalEditSheet extends StatefulWidget {
  final EmployerProfileController ctrl;
  final UserModel profile;

  const _FullPersonalEditSheet({
    required this.ctrl,
    required this.profile,
  });

  @override
  State<_FullPersonalEditSheet> createState() => _FullPersonalEditSheetState();
}

class _FullPersonalEditSheetState extends State<_FullPersonalEditSheet> {
  late TextEditingController _firstCtrl;
  late TextEditingController _lastCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _cccdCtrl;
  String? _gender;
  DateTime? _dob;
  File? _frontFile;
  File? _backFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstCtrl = TextEditingController(text: widget.profile.firstName);
    _lastCtrl  = TextEditingController(text: widget.profile.lastName);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
    _cccdCtrl  = TextEditingController(text: widget.profile.cccd ?? '');
    _gender    = widget.profile.gender;
    _dob       = widget.profile.dateOfBirth;
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _cccdCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String side) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        if (side == 'front') {
          _frontFile = File(picked.path);
        } else {
          _backFile = File(picked.path);
        }
      });
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể chọn ảnh: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade800,
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.employerPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? frontUrl;
      String? backUrl;
      if (_frontFile != null) {
        frontUrl = await widget.ctrl.uploadCccdImage(_frontFile!, 'front');
      }
      if (_backFile != null) {
        backUrl = await widget.ctrl.uploadCccdImage(_backFile!, 'back');
      }
      final ok = await widget.ctrl.savePersonalInfo(
        firstName: _firstCtrl.text.trim(),
        lastName: _lastCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        gender: _gender,
        dateOfBirth: _dob,
        cccd: _cccdCtrl.text.trim(),
        cccdImageUrl: frontUrl,
        cccdBackImageUrl: backUrl,
      );
      if (ok && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Người đại diện',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            // ── Họ & Tên ──
            Row(
              children: [
                Expanded(child: _SheetTextField(ctrl: _firstCtrl, label: 'Họ')),
                const SizedBox(width: 12),
                Expanded(child: _SheetTextField(ctrl: _lastCtrl, label: 'Tên')),
              ],
            ),
            const SizedBox(height: 12),

            // ── Số điện thoại ──
            _SheetTextField(
              ctrl: _phoneCtrl,
              label: 'Số điện thoại',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            // ── Giới tính ──
            const Text(
              'Giới tính',
              style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _GenderChip(
                  label: 'Nam',
                  value: 'male',
                  selected: _gender,
                  onTap: (v) => setState(() => _gender = v),
                ),
                const SizedBox(width: 8),
                _GenderChip(
                  label: 'Nữ',
                  value: 'female',
                  selected: _gender,
                  onTap: (v) => setState(() => _gender = v),
                ),
                const SizedBox(width: 8),
                _GenderChip(
                  label: 'Khác',
                  value: 'other',
                  selected: _gender,
                  onTap: (v) => setState(() => _gender = v),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Ngày sinh ──
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, size: 18, color: Color(0xFF9E9E9E)),
                    const SizedBox(width: 10),
                    Text(
                      _dob != null
                          ? DateFormat('dd/MM/yyyy').format(_dob!)
                          : 'Chọn ngày sinh',
                      style: TextStyle(
                        fontSize: 14,
                        color: _dob != null
                            ? const Color(0xFF333333)
                            : const Color(0xFFBDBDBD),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBDBDBD)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Số CCCD ──
            _SheetTextField(
              ctrl: _cccdCtrl,
              label: 'Số CCCD/CMND',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // ── Ảnh CCCD ──
            const Text(
              'Hình ảnh CCCD/CMND',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CccdImagePicker(
                    label: 'Mặt trước',
                    file: _frontFile,
                    existingUrl: widget.profile.cccdImageUrl,
                    onPick: () => _pickImage('front'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CccdImagePicker(
                    label: 'Mặt sau',
                    file: _backFile,
                    existingUrl: widget.profile.cccdBackImageUrl,
                    onPick: () => _pickImage('back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Nút lưu ──
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.employerPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final String value;
  final String? selected;
  final void Function(String) onTap;

  const _GenderChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.employerPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.employerPrimary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : const Color(0xFF666666),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _CccdImagePicker extends StatelessWidget {
  final String label;
  final File? file;
  final String? existingUrl;
  final VoidCallback onPick;

  const _CccdImagePicker({
    required this.label,
    required this.onPick,
    this.file,
    this.existingUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null || (existingUrl?.isNotEmpty == true);
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasImage
                ? AppColors.employerPrimary.withAlpha(128)
                : Colors.grey.shade300,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: file != null
              ? Image.file(file!, fit: BoxFit.cover, width: double.infinity)
              : existingUrl?.isNotEmpty == true
                  ? Image.network(
                      existingUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 28, color: Colors.grey.shade400),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
