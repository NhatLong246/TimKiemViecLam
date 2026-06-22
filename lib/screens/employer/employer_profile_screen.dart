import 'dart:convert';
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
      backgroundColor: const Color(0xFFF4F6FB),
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
                const Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Không thể tải hồ sơ',
                  style: TextStyle(color: Colors.grey),
                ),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 92),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildProfileNavCard(context, profile),
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
                        child:
                            profile.companyLogoUrl != null &&
                                profile.companyLogoUrl!.isNotEmpty
                            ? Image.network(
                                profile.companyLogoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _defaultLogo(profile),
                              )
                            : profile.avatarBase64 != null &&
                                  profile.avatarBase64!.isNotEmpty
                            ? Image.memory(
                                base64Decode(profile.avatarBase64!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _defaultLogo(profile),
                              )
                            : profile.avatarBase64 != null &&
                                  profile.avatarBase64!.isNotEmpty
                            ? Image.memory(
                                base64Decode(profile.avatarBase64!),
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
    final initials =
        (profile.companyName?.isNotEmpty == true
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

  // ─── Profile Navigation Card ───────────────────────────
  Widget _buildProfileNavCard(BuildContext context, UserModel profile) {
    return GestureDetector(
      onTap: () => Get.to(() => const EmployerCompanyProfileScreen()),
      child: Container(
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
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.employerPrimary.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.business_center_outlined,
                      size: 18,
                      color: AppColors.employerPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Hồ sơ doanh nghiệp',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.employerGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem & Chỉnh sửa',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.employerPrimary.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.employerPrimary.withAlpha(51),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child:
                          profile.companyLogoUrl != null &&
                              profile.companyLogoUrl!.isNotEmpty
                          ? Image.network(
                              profile.companyLogoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _logoPlaceholder(profile),
                            )
                          : _logoPlaceholder(profile),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.companyName?.isNotEmpty == true
                              ? profile.companyName!
                              : 'Chưa có tên doanh nghiệp',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: profile.companyName?.isNotEmpty == true
                                ? const Color(0xFF333333)
                                : const Color(0xFFBDBDBD),
                            fontStyle: profile.companyName?.isNotEmpty == true
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (profile.companyAddress?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 13,
                                color: Color(0xFF9E9E9E),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  profile.companyAddress!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9E9E9E),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 13,
                              color: Color(0xFF9E9E9E),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                profile.fullName.isNotEmpty
                                    ? profile.fullName
                                    : 'Chưa có người đại diện',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFFBDBDBD),
                  ),
                ],
              ),
            ),
            _buildCompletionBar(profile),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder(UserModel profile) {
    return Center(
      child: Text(
        (profile.companyName?.isNotEmpty == true
                ? profile.companyName![0]
                : profile.firstName.isNotEmpty
                ? profile.firstName[0]
                : '?')
            .toUpperCase(),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.employerPrimary,
        ),
      ),
    );
  }

  Widget _buildCompletionBar(UserModel profile) {
    const total = 13;
    var filled = 0;
    if (profile.fullName.isNotEmpty) filled++;
    if (profile.phone.isNotEmpty) filled++;
    if (profile.gender?.isNotEmpty == true) filled++;
    if (profile.dateOfBirth != null) filled++;
    if (profile.cccd?.isNotEmpty == true) filled++;
    if (profile.companyName?.isNotEmpty == true) filled++;
    if (profile.companyAddress?.isNotEmpty == true) filled++;
    if (profile.companyPhone?.isNotEmpty == true) filled++;
    if (profile.companyTaxCode?.isNotEmpty == true) filled++;
    if (profile.companyDescription?.isNotEmpty == true) filled++;
    if (profile.businessLicenseImageUrls.isNotEmpty) filled++;
    if (profile.taxCodeImageUrls.isNotEmpty) filled++;
    if (profile.otherDocumentImageUrls.isNotEmpty) filled++;
    final percent = filled / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Độ hoàn thiện hồ sơ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              Text(
                '$filled/$total thông tin',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.employerPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.employerPrimary,
              ),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Employer Company Profile Screen ─────────────────────

class EmployerCompanyProfileScreen extends StatelessWidget {
  const EmployerCompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<EmployerProfileController>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.employerPrimary),
          );
        }
        final profile = ctrl.profile.value;
        if (profile == null) {
          return const Center(child: Text('Không có dữ liệu'));
        }
        return NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              expandedHeight: 112,
              elevation: 0,
              backgroundColor: const Color(0xFF5B21B6),
              leading: IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              title: const Text(
                'Hồ sơ doanh nghiệp',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF4C1D95),
                        Color(0xFF7C3AED),
                        Color(0xFF1769C2),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -30,
                        top: 10,
                        child: CircleAvatar(
                          radius: 58,
                          backgroundColor: Colors.white10,
                        ),
                      ),
                      Positioned(
                        left: 34,
                        bottom: -24,
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.blueAccent.withValues(
                            alpha: 0.12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: RefreshIndicator(
            color: AppColors.employerPrimary,
            onRefresh: ctrl.loadProfile,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AnimatedProfileSection(
                    duration: const Duration(milliseconds: 460),
                    child: _buildLogoCard(context, ctrl, profile),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedProfileSection(
                    duration: const Duration(milliseconds: 580),
                    child: _PersonalSection(ctrl: ctrl, profile: profile),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedProfileSection(
                    duration: const Duration(milliseconds: 700),
                    child: _CompanySection(ctrl: ctrl, profile: profile),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedProfileSection(
                    duration: const Duration(milliseconds: 820),
                    child: _DocumentSection(ctrl: ctrl, profile: profile),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLogoCard(
    BuildContext context,
    EmployerProfileController ctrl,
    UserModel profile,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8F5FF), Color(0xFFF2F7FF)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8E3F3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF41236E).withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x242C1850),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(23),
                  child:
                      profile.companyLogoUrl != null &&
                          profile.companyLogoUrl!.isNotEmpty
                      ? Image.network(
                          profile.companyLogoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _logoDetailPlaceholder(profile),
                        )
                      : profile.avatarBase64 != null &&
                            profile.avatarBase64!.isNotEmpty
                      ? Image.memory(
                          base64Decode(profile.avatarBase64!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _logoDetailPlaceholder(profile),
                        )
                      : profile.avatarUrl != null &&
                            profile.avatarUrl!.isNotEmpty
                      ? Image.network(
                          profile.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _logoDetailPlaceholder(profile),
                        )
                      : _logoDetailPlaceholder(profile),
                ),
              ),
              GestureDetector(
                onTap: () => ctrl.uploadAvatar(),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.employerPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x337B1FA2), blurRadius: 10),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            profile.companyName?.isNotEmpty == true
                ? profile.companyName!
                : profile.fullName,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF20263A),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7C879C)),
          ),
          if (profile.isVerified) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Đã xác minh',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EAF1)),
            ),
            child: Row(
              children: [
                _ProfileMetric(
                  icon: Icons.apartment_rounded,
                  label: 'Loại hồ sơ',
                  value: _businessTypeLabel(profile.businessType),
                ),
                const _ProfileMetricDivider(),
                _ProfileMetric(
                  icon: Icons.people_alt_rounded,
                  label: 'Quy mô',
                  value: profile.companySize?.isNotEmpty == true
                      ? profile.companySize!
                      : 'Chưa có',
                ),
                const _ProfileMetricDivider(),
                _ProfileMetric(
                  icon: Icons.folder_copy_rounded,
                  label: 'Tài liệu',
                  value:
                      '${profile.businessLicenseImageUrls.length + profile.taxCodeImageUrls.length + profile.otherDocumentImageUrls.length} ảnh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Mức độ hoàn thiện',
                style: TextStyle(
                  color: Color(0xFF59657A),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(_profileCompletion(profile) * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.employerPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _profileCompletion(profile)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                color: AppColors.employerPrimary,
                backgroundColor: const Color(0xFFE8E2F1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoDetailPlaceholder(UserModel profile) {
    return Center(
      child: Text(
        (profile.companyName?.isNotEmpty == true
                ? profile.companyName![0]
                : profile.firstName.isNotEmpty
                ? profile.firstName[0]
                : '?')
            .toUpperCase(),
        style: const TextStyle(
          color: AppColors.employerPrimary,
          fontSize: 40,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  double _profileCompletion(UserModel profile) {
    final completed = <bool>[
      profile.fullName.isNotEmpty,
      profile.phone.isNotEmpty,
      profile.gender?.isNotEmpty == true,
      profile.dateOfBirth != null,
      profile.cccd?.isNotEmpty == true,
      profile.companyName?.isNotEmpty == true,
      profile.companyAddress?.isNotEmpty == true,
      profile.companyPhone?.isNotEmpty == true,
      profile.companyTaxCode?.isNotEmpty == true,
      profile.companyDescription?.isNotEmpty == true,
      profile.businessLicenseImageUrls.isNotEmpty,
      profile.taxCodeImageUrls.isNotEmpty,
      profile.otherDocumentImageUrls.isNotEmpty,
    ].where((item) => item).length;
    return completed / 13;
  }

  String _businessTypeLabel(String? type) {
    switch (type) {
      case 'individual':
        return 'Hộ KD';
      case 'company':
        return 'Công ty';
      case 'cooperative':
        return 'Hợp tác xã';
      default:
        return 'Chưa có';
    }
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.employerPrimary, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF20263A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricDivider extends StatelessWidget {
  const _ProfileMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: const Color(0xFFE7EAF1));
  }
}

class _AnimatedProfileSection extends StatelessWidget {
  const _AnimatedProfileSection({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 22 * (1 - value)),
          child: child,
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
    final name = profile.fullName.isNotEmpty
        ? profile.fullName
        : 'Chưa cập nhật người đại diện';
    return _ModernProfileSection(
      title: 'Người đại diện',
      subtitle: 'Thông tin người chịu trách nhiệm tuyển dụng',
      icon: Icons.person_rounded,
      onEdit: () => _showEditPersonalDialog(context),
      child: Column(
        children: [
          _RepresentativeHero(
            name: name,
            email: profile.email,
            isComplete: profile.fullName.isNotEmpty && profile.phone.isNotEmpty,
            onTap: () => _showEditPersonalDialog(context),
          ),
          const SizedBox(height: 14),
          _DetailGrid(
            children: [
              _DetailBlock(
                icon: Icons.call_rounded,
                label: 'Điện thoại',
                value: profile.phone,
                onTap: () => _showSingleFieldEdit(
                  context,
                  label: 'Số điện thoại',
                  initialValue: profile.phone,
                  keyboardType: TextInputType.phone,
                  onSave: (v) => ctrl.savePersonalInfo(phone: v),
                ),
              ),
              _DetailBlock(
                icon: Icons.diversity_1_rounded,
                label: 'Giới tính',
                value: _genderLabel(profile.gender),
                onTap: () => _showGenderPicker(context),
              ),
              _DetailBlock(
                icon: Icons.cake_rounded,
                label: 'Ngày sinh',
                value: _formatDate(profile.dateOfBirth),
                onTap: () => _showDatePicker(context),
              ),
              _DetailBlock(
                icon: Icons.badge_rounded,
                label: 'CCCD/CMND',
                value: profile.cccd ?? '',
                onTap: () => _showSingleFieldEdit(
                  context,
                  label: 'Số CCCD/CMND',
                  initialValue: profile.cccd ?? '',
                  keyboardType: TextInputType.number,
                  onSave: (v) => ctrl.savePersonalInfo(cccd: v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditPersonalDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
          _PickerOption(
            value: 'other',
            label: 'Khác',
            icon: Icons.people_outline,
          ),
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
    return _ModernProfileSection(
      title: 'Thông tin doanh nghiệp',
      subtitle: 'Nhận diện, pháp lý và kênh liên hệ',
      icon: Icons.apartment_rounded,
      onEdit: () => _showEditCompanyDialog(context),
      child: Column(
        children: [
          _CompanyIdentityHero(
            name: profile.companyName ?? '',
            address: profile.companyAddress ?? '',
            businessType: _typeLabel(profile.businessType),
            onTap: () => _showEditCompanyDialog(context),
          ),
          const SizedBox(height: 14),
          _DetailGrid(
            children: [
              _DetailBlock(
                icon: Icons.receipt_long_rounded,
                label: 'Mã số thuế',
                value: profile.companyTaxCode ?? '',
                onTap: () => _showSingleEdit(
                  context,
                  label: 'Mã số thuế',
                  fieldKey: 'companyTaxCode',
                  initial: profile.companyTaxCode ?? '',
                  keyboardType: TextInputType.number,
                ),
              ),
              _DetailBlock(
                icon: Icons.groups_2_rounded,
                label: 'Quy mô',
                value: _sizeLabel(profile.companySize),
                onTap: () => _showSizePicker(context),
              ),
              _DetailBlock(
                icon: Icons.business_rounded,
                label: 'Loại hình',
                value: _typeLabel(profile.businessType),
                onTap: () => _showTypePicker(context),
              ),
              _DetailBlock(
                icon: Icons.call_rounded,
                label: 'Điện thoại',
                value: profile.companyPhone ?? '',
                onTap: () => _showSingleEdit(
                  context,
                  label: 'Điện thoại công ty',
                  fieldKey: 'companyPhone',
                  initial: profile.companyPhone ?? '',
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WideDetailBlock(
            icon: Icons.language_rounded,
            label: 'Website doanh nghiệp',
            value: profile.companyWebsite ?? '',
            onTap: () => _showSingleEdit(
              context,
              label: 'Website',
              fieldKey: 'companyWebsite',
              initial: profile.companyWebsite ?? '',
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 12),
          _DescriptionPanel(
            value: profile.companyDescription ?? '',
            onTap: () => _showSingleEdit(
              context,
              label: 'Giới thiệu doanh nghiệp',
              fieldKey: 'companyDescription',
              initial: profile.companyDescription ?? '',
              maxLines: 4,
            ),
          ),
        ],
      ),
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
          final ok = await ctrl.updateSingleField(
            fieldKey,
            textCtrl.text.trim(),
          );
          if (ok && context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditCompanyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullCompanyEditSheet(ctrl: ctrl, profile: profile),
    );
  }

  void _showSizePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerBottomSheet(
        title: 'Quy mô nhân sự',
        options: const [
          _PickerOption(
            value: '1-9',
            label: '1–9 nhân viên',
            icon: Icons.person,
          ),
          _PickerOption(
            value: '10-49',
            label: '10–49 nhân viên',
            icon: Icons.group,
          ),
          _PickerOption(
            value: '50-199',
            label: '50–199 nhân viên',
            icon: Icons.groups,
          ),
          _PickerOption(
            value: '200+',
            label: '200+ nhân viên',
            icon: Icons.corporate_fare,
          ),
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
            icon: Icons.person_outline,
          ),
          _PickerOption(
            value: 'company',
            label: 'Công ty / Doanh nghiệp',
            icon: Icons.business,
          ),
          _PickerOption(
            value: 'cooperative',
            label: 'Hợp tác xã',
            icon: Icons.handshake_outlined,
          ),
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

// ─── Business Documents ───────────────────────────────────

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.ctrl, required this.profile});

  final EmployerProfileController ctrl;
  final UserModel profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D25345D),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0E5FF), Color(0xFFE8F2FF)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.employerPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hồ sơ pháp lý',
                      style: TextStyle(
                        color: Color(0xFF20263A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Bổ sung nhiều ảnh để tăng độ tin cậy',
                      style: TextStyle(color: Color(0xFF8A94A6), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3ECFF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${profile.businessLicenseImageUrls.length + profile.taxCodeImageUrls.length + profile.otherDocumentImageUrls.length} ảnh',
                  style: const TextStyle(
                    color: AppColors.employerPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DocumentGallery(
            title: 'Giấy phép kinh doanh',
            description: 'Ảnh rõ số giấy phép, tên và địa chỉ doanh nghiệp',
            icon: Icons.business_center_outlined,
            urls: profile.businessLicenseImageUrls,
            isUploading: ctrl.isUploadingBusinessLicenses.value,
            onAdd: () => ctrl.pickAndUploadDocumentImages(
              type: EmployerDocumentType.businessLicense,
            ),
            onDelete: (url) => ctrl.removeDocumentImage(
              type: EmployerDocumentType.businessLicense,
              url: url,
            ),
          ),
          const SizedBox(height: 14),
          _DocumentGallery(
            title: 'Mã số thuế',
            description: 'Ảnh giấy chứng nhận hoặc tài liệu có mã số thuế',
            icon: Icons.numbers_rounded,
            urls: profile.taxCodeImageUrls,
            isUploading: ctrl.isUploadingTaxCodeDocuments.value,
            onAdd: () => ctrl.pickAndUploadDocumentImages(
              type: EmployerDocumentType.taxCode,
            ),
            onDelete: (url) => ctrl.removeDocumentImage(
              type: EmployerDocumentType.taxCode,
              url: url,
            ),
          ),
          const SizedBox(height: 14),
          _DocumentGallery(
            title: 'Giấy tờ khác',
            description: 'Chứng nhận, giấy ủy quyền hoặc tài liệu liên quan',
            icon: Icons.file_copy_outlined,
            urls: profile.otherDocumentImageUrls,
            isUploading: ctrl.isUploadingOtherDocuments.value,
            onAdd: () => ctrl.pickAndUploadDocumentImages(
              type: EmployerDocumentType.other,
            ),
            onDelete: (url) => ctrl.removeDocumentImage(
              type: EmployerDocumentType.other,
              url: url,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentGallery extends StatelessWidget {
  const _DocumentGallery({
    required this.title,
    required this.description,
    required this.icon,
    required this.urls,
    required this.isUploading,
    required this.onAdd,
    required this.onDelete,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<String> urls;
  final bool isUploading;
  final VoidCallback onAdd;
  final Future<void> Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF59657A), size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF293146),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF8A94A6),
                        fontSize: 10,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (urls.isNotEmpty)
                TextButton.icon(
                  onPressed: isUploading ? null : onAdd,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 17,
                  ),
                  label: const Text('Thêm'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.employerPrimary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: isUploading
                ? const _DocumentUploading()
                : urls.isEmpty
                ? _EmptyDocumentPicker(onTap: onAdd)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 20) / 3;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < urls.length; i++)
                            _DocumentThumbnail(
                              width: width,
                              url: urls[i],
                              heroTag: '$title-$i-${urls[i]}',
                              onDelete: () => _confirmDelete(context, urls[i]),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String url) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.redAccent,
          size: 30,
        ),
        title: const Text('Xóa ảnh tài liệu?'),
        content: const Text(
          'Ảnh sẽ được gỡ khỏi hồ sơ doanh nghiệp của bạn.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa ảnh'),
          ),
        ],
      ),
    );
    if (accepted == true) await onDelete(url);
  }
}

class _DocumentUploading extends StatelessWidget {
  const _DocumentUploading();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('uploading'),
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF1EBFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Text(
            'Đang tải các ảnh lên...',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyDocumentPicker extends StatelessWidget {
  const _EmptyDocumentPicker({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('empty'),
      color: const Color(0xFFF1EBFF),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppColors.employerPrimary,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chọn nhiều ảnh',
                      style: TextStyle(
                        color: AppColors.employerPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nhấn để mở thư viện ảnh',
                      style: TextStyle(color: Color(0xFF7C879C), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.employerPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentThumbnail extends StatelessWidget {
  const _DocumentThumbnail({
    required this.width,
    required this.url,
    required this.heroTag,
    required this.onDelete,
  });

  final double width;
  final String url;
  final String heroTag;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.05,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openPreview(context),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFF9AA3B5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 5,
            right: 5,
            child: Material(
              color: const Color(0xCC1E2330),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onDelete,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng ảnh',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => SafeArea(
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Hero(tag: heroTag, child: Image.network(url)),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filled(
                onPressed: Navigator.of(context).pop,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          size: 13,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          avg.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
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
          onTap: () => Get.toNamed(AppRoutes.changePassword),
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ctrl.logout();
              Get.offAllNamed(AppRoutes.login);
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────

class _ModernProfileSection extends StatelessWidget {
  const _ModernProfileSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onEdit,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onEdit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E9F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10253A63),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 4,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF1769C2)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF0E6FF), Color(0xFFE7F1FF)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: AppColors.employerPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1F2940),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8791A5),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Material(
                  color: const Color(0xFFF2EAFF),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            color: AppColors.employerPrimary,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Sửa',
                            style: TextStyle(
                              color: AppColors.employerPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEDF0F6)),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}

class _RepresentativeHero extends StatelessWidget {
  const _RepresentativeHero({
    required this.name,
    required this.email,
    required this.isComplete,
    required this.onTap,
  });

  final String name;
  final String email;
  final bool isComplete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial = name == 'Chưa cập nhật người đại diện'
        ? '?'
        : name.trim()[0].toUpperCase();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF5EEFF), Color(0xFFEDF5FF)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(19),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x337C3AED),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF202940),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF778299),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusPill(
                      complete: isComplete,
                      completeText: 'Liên hệ chính',
                      missingText: 'Cần bổ sung thông tin',
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9AA4B7),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyIdentityHero extends StatelessWidget {
  const _CompanyIdentityHero({
    required this.name,
    required this.address,
    required this.businessType,
    required this.onTap,
  });

  final String name;
  final String address;
  final String businessType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasName = name.trim().isNotEmpty;
    final displayName = hasName ? name.trim() : 'Chưa có tên doanh nghiệp';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF251340), Color(0xFF173D72)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  hasName ? name.trim()[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFFB9C9E5),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address.trim().isEmpty
                                ? 'Chưa cập nhật địa chỉ'
                                : address.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD3DDF0),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        businessType,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_rounded, color: Colors.white70, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.complete,
    required this.completeText,
    required this.missingText,
  });

  final bool complete;
  final String completeText;
  final String missingText;

  @override
  Widget build(BuildContext context) {
    final color = complete ? const Color(0xFF168A50) : const Color(0xFFB66A05);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              complete ? Icons.check_circle_rounded : Icons.info_rounded,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 4),
            Text(
              complete ? completeText : missingText,
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty || value == 'Chưa cập nhật';
    return Material(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE9ECF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E8FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: AppColors.employerPrimary,
                      size: 17,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.north_east_rounded,
                    color: Color(0xFFA2ABBB),
                    size: 14,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                missing ? 'Bổ sung ngay' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: missing
                      ? const Color(0xFFB66A05)
                      : const Color(0xFF263047),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideDetailBlock extends StatelessWidget {
  const _WideDetailBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty;
    return Material(
      color: const Color(0xFFF8F9FC),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE9ECF3)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF1769C2), size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF8A94A6),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing ? 'Bổ sung ngay' : value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: missing
                            ? const Color(0xFFB66A05)
                            : const Color(0xFF263047),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFA2ABBB)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DescriptionPanel extends StatelessWidget {
  const _DescriptionPanel({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final missing = value.trim().isEmpty;
    return Material(
      color: const Color(0xFFFFFAF0),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFF2E5C9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFB66A05),
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Câu chuyện doanh nghiệp',
                      style: TextStyle(
                        color: Color(0xFF774807),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_note_rounded,
                    color: Color(0xFFB66A05),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                missing
                    ? 'Thêm giới thiệu ngắn để ứng viên hiểu văn hóa và môi trường làm việc.'
                    : value,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: missing
                      ? const Color(0xFF9B7B4B)
                      : const Color(0xFF5D4A2C),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D25345D),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 14, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0E5FF), Color(0xFFE8F2FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: AppColors.employerPrimary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20263A),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEFF1F6)),
          ...children,
        ],
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
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
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EditorSheetHeader(
            icon: Icons.edit_note_rounded,
            title: widget.title,
            subtitle: 'Chỉnh sửa nhanh thông tin đã chọn',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE7EAF2)),
              ),
              child: Column(children: widget.children),
            ),
          ),
          _EditorSaveArea(
            saving: _saving,
            label: 'Lưu thay đổi',
            onPressed: () async {
              setState(() => _saving = true);
              await widget.onSave();
              if (mounted) setState(() => _saving = false);
            },
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
  final String? hintText;
  final IconData? prefixIcon;

  const _SheetTextField({
    required this.ctrl,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.hintText,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF263047),
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFFA4ACBA),
          fontSize: 11.5,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF778299),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.employerPrimary,
          fontWeight: FontWeight.w800,
        ),
        prefixIcon: Icon(
          prefixIcon ?? Icons.edit_rounded,
          color: AppColors.employerPrimary,
          size: 20,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE2E6EF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: AppColors.employerPrimary,
            width: 1.5,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PickerOption {
  final String value;
  final String label;
  final IconData icon;

  const _PickerOption({
    required this.value,
    required this.label,
    required this.icon,
  });
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
        color: Color(0xFFF5F7FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EditorSheetHeader(
            icon: Icons.tune_rounded,
            title: title,
            subtitle: 'Chọn một giá trị phù hợp với hồ sơ',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              children: options.map((opt) {
                final isSelected = selectedValue == opt.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: isSelected ? const Color(0xFFF0E7FF) : Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      onTap: () => onSelect(opt.value),
                      borderRadius: BorderRadius.circular(17),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.employerPrimary
                                : const Color(0xFFE4E8F0),
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFF4F6FA),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                opt.icon,
                                color: isSelected
                                    ? AppColors.employerPrimary
                                    : const Color(0xFF7D8799),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.employerPrimary
                                      : const Color(0xFF344057),
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? AppColors.employerPrimary
                                  : const Color(0xFFB2BAC8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullCompanyEditSheet extends StatefulWidget {
  const _FullCompanyEditSheet({required this.ctrl, required this.profile});

  final EmployerProfileController ctrl;
  final UserModel profile;

  @override
  State<_FullCompanyEditSheet> createState() => _FullCompanyEditSheetState();
}

class _FullCompanyEditSheetState extends State<_FullCompanyEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _descriptionCtrl;
  String? _companySize;
  String? _businessType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameCtrl = TextEditingController(text: profile.companyName ?? '');
    _addressCtrl = TextEditingController(text: profile.companyAddress ?? '');
    _taxCtrl = TextEditingController(text: profile.companyTaxCode ?? '');
    _phoneCtrl = TextEditingController(text: profile.companyPhone ?? '');
    _websiteCtrl = TextEditingController(text: profile.companyWebsite ?? '');
    _descriptionCtrl = TextEditingController(
      text: profile.companyDescription ?? '',
    );
    _companySize = profile.companySize;
    _businessType = profile.businessType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _taxCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final ok = await widget.ctrl.saveCompanyInfo(
        companyName: _nameCtrl.text.trim(),
        companyAddress: _addressCtrl.text.trim(),
        companyTaxCode: _taxCtrl.text.trim(),
        companyPhone: _phoneCtrl.text.trim(),
        companyWebsite: _websiteCtrl.text.trim(),
        companyDescription: _descriptionCtrl.text.trim(),
        companySize: _companySize,
        businessType: _businessType,
      );
      if (ok && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const _EditorSheetHeader(
              icon: Icons.apartment_rounded,
              title: 'Cập nhật doanh nghiệp',
              subtitle: 'Hoàn thiện nhận diện, pháp lý và kênh liên hệ',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    _EditorFormSection(
                      number: '01',
                      title: 'Nhận diện doanh nghiệp',
                      subtitle: 'Thông tin ứng viên nhìn thấy đầu tiên',
                      children: [
                        _SheetTextField(
                          ctrl: _nameCtrl,
                          label: 'Tên doanh nghiệp',
                          hintText: 'Ví dụ: Công ty TNHH ViecNow',
                          prefixIcon: Icons.apartment_rounded,
                        ),
                        const SizedBox(height: 12),
                        _SheetTextField(
                          ctrl: _addressCtrl,
                          label: 'Địa chỉ trụ sở',
                          hintText: 'Số nhà, đường, quận/huyện, tỉnh thành',
                          prefixIcon: Icons.location_on_rounded,
                          maxLines: 2,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorFormSection(
                      number: '02',
                      title: 'Thông tin pháp lý',
                      subtitle: 'Dùng để xác minh tư cách tuyển dụng',
                      children: [
                        _SheetTextField(
                          ctrl: _taxCtrl,
                          label: 'Mã số thuế',
                          hintText: 'Nhập mã số thuế doanh nghiệp',
                          prefixIcon: Icons.receipt_long_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 15),
                        const _EditorFieldLabel(
                          icon: Icons.business_rounded,
                          label: 'Loại hình hoạt động',
                        ),
                        const SizedBox(height: 9),
                        _EditorChoiceWrap(
                          selected: _businessType,
                          options: const [
                            _EditorChoice('individual', 'Hộ kinh doanh'),
                            _EditorChoice('company', 'Doanh nghiệp'),
                            _EditorChoice('cooperative', 'Hợp tác xã'),
                          ],
                          onChanged: (value) =>
                              setState(() => _businessType = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorFormSection(
                      number: '03',
                      title: 'Liên hệ và quy mô',
                      subtitle: 'Thông tin vận hành của doanh nghiệp',
                      children: [
                        _SheetTextField(
                          ctrl: _phoneCtrl,
                          label: 'Điện thoại doanh nghiệp',
                          hintText: 'Số hotline hoặc số liên hệ',
                          prefixIcon: Icons.call_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _SheetTextField(
                          ctrl: _websiteCtrl,
                          label: 'Website',
                          hintText: 'https://ten-doanh-nghiep.vn',
                          prefixIcon: Icons.language_rounded,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 15),
                        const _EditorFieldLabel(
                          icon: Icons.groups_2_rounded,
                          label: 'Quy mô nhân sự',
                        ),
                        const SizedBox(height: 9),
                        _EditorChoiceWrap(
                          selected: _companySize,
                          options: const [
                            _EditorChoice('1-9', '1–9'),
                            _EditorChoice('10-49', '10–49'),
                            _EditorChoice('50-199', '50–199'),
                            _EditorChoice('200+', '200+'),
                          ],
                          onChanged: (value) =>
                              setState(() => _companySize = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorFormSection(
                      number: '04',
                      title: 'Câu chuyện doanh nghiệp',
                      subtitle: 'Giúp ứng viên hiểu môi trường làm việc',
                      children: [
                        _SheetTextField(
                          ctrl: _descriptionCtrl,
                          label: 'Giới thiệu ngắn',
                          hintText:
                              'Lĩnh vực hoạt động, văn hóa và điều doanh nghiệp đang tìm kiếm...',
                          prefixIcon: Icons.auto_awesome_rounded,
                          maxLines: 5,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _EditorSaveArea(
              saving: _saving,
              label: 'Lưu hồ sơ doanh nghiệp',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSheetHeader extends StatelessWidget {
  const _EditorSheetHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 11, 14, 17),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D25345D),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD8DCE6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF202940),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8791A5),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorFormSection extends StatelessWidget {
  const _EditorFormSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String number;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A25345D),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E8FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.employerPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF263047),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8A94A6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }
}

class _EditorSaveArea extends StatelessWidget {
  const _EditorSaveArea({
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x12253A63),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: saving ? null : onPressed,
            icon: saving
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.employerPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorChoice {
  const _EditorChoice(this.value, this.label);

  final String value;
  final String label;
}

class _EditorChoiceWrap extends StatelessWidget {
  const _EditorChoiceWrap({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  final String? selected;
  final List<_EditorChoice> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final active = selected == option.value;
        return InkWell(
          onTap: () => onChanged(option.value),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF0E7FF) : const Color(0xFFF7F8FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active
                    ? AppColors.employerPrimary
                    : const Color(0xFFE4E8F0),
                width: active ? 1.4 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Icon(
                    active ? Icons.check_circle_rounded : Icons.circle_outlined,
                    key: ValueKey(active),
                    color: active
                        ? AppColors.employerPrimary
                        : const Color(0xFF9AA3B4),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  option.label,
                  style: TextStyle(
                    color: active
                        ? AppColors.employerPrimary
                        : const Color(0xFF566176),
                    fontSize: 11.5,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EditorFieldLabel extends StatelessWidget {
  const _EditorFieldLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.employerPrimary),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4F5B70),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─── Full Personal Edit Sheet ─────────────────────────────────────────────

class _FullPersonalEditSheet extends StatefulWidget {
  final EmployerProfileController ctrl;
  final UserModel profile;

  const _FullPersonalEditSheet({required this.ctrl, required this.profile});

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
    _lastCtrl = TextEditingController(text: widget.profile.lastName);
    _phoneCtrl = TextEditingController(text: widget.profile.phone);
    _cccdCtrl = TextEditingController(text: widget.profile.cccd ?? '');
    _gender = widget.profile.gender;
    _dob = widget.profile.dateOfBirth;
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
    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const _EditorSheetHeader(
              icon: Icons.person_rounded,
              title: 'Cập nhật người đại diện',
              subtitle: 'Thông tin liên hệ và xác minh danh tính',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    _EditorFormSection(
                      number: '01',
                      title: 'Thông tin liên hệ',
                      subtitle: 'Tên và số điện thoại người phụ trách',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _SheetTextField(
                                ctrl: _firstCtrl,
                                label: 'Họ',
                                hintText: 'Nguyễn',
                                prefixIcon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SheetTextField(
                                ctrl: _lastCtrl,
                                label: 'Tên',
                                hintText: 'An',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SheetTextField(
                          ctrl: _phoneCtrl,
                          label: 'Số điện thoại',
                          hintText: 'Số điện thoại đang sử dụng',
                          prefixIcon: Icons.call_rounded,
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorFormSection(
                      number: '02',
                      title: 'Thông tin cá nhân',
                      subtitle: 'Dữ liệu cơ bản của người đại diện',
                      children: [
                        const _EditorFieldLabel(
                          icon: Icons.diversity_1_rounded,
                          label: 'Giới tính',
                        ),
                        const SizedBox(height: 9),
                        _EditorChoiceWrap(
                          selected: _gender,
                          options: const [
                            _EditorChoice('male', 'Nam'),
                            _EditorChoice('female', 'Nữ'),
                            _EditorChoice('other', 'Khác'),
                          ],
                          onChanged: (value) => setState(() => _gender = value),
                        ),
                        const SizedBox(height: 14),
                        const _EditorFieldLabel(
                          icon: Icons.cake_rounded,
                          label: 'Ngày sinh',
                        ),
                        const SizedBox(height: 9),
                        Material(
                          color: const Color(0xFFF7F8FC),
                          borderRadius: BorderRadius.circular(15),
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: const Color(0xFFE2E6EF),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_rounded,
                                    color: AppColors.employerPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Text(
                                      _dob == null
                                          ? 'Chọn ngày sinh'
                                          : DateFormat(
                                              'dd/MM/yyyy',
                                            ).format(_dob!),
                                      style: TextStyle(
                                        color: _dob == null
                                            ? const Color(0xFFA4ACBA)
                                            : const Color(0xFF263047),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.expand_more_rounded,
                                    color: Color(0xFF8A94A6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _EditorFormSection(
                      number: '03',
                      title: 'Xác minh danh tính',
                      subtitle: 'CCCD/CMND và hình ảnh hai mặt',
                      children: [
                        _SheetTextField(
                          ctrl: _cccdCtrl,
                          label: 'Số CCCD/CMND',
                          hintText: 'Nhập đầy đủ số giấy tờ',
                          prefixIcon: Icons.badge_rounded,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 15),
                        const _EditorFieldLabel(
                          icon: Icons.add_photo_alternate_rounded,
                          label: 'Hình ảnh giấy tờ',
                        ),
                        const SizedBox(height: 9),
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
                            const SizedBox(width: 10),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _EditorSaveArea(
              saving: _saving,
              label: 'Lưu thông tin người đại diện',
              onPressed: _save,
            ),
          ],
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
    return Material(
      color: const Color(0xFFF7F8FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage
                  ? AppColors.employerPrimary
                  : const Color(0xFFDDE2EC),
              width: hasImage ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (file != null)
                        Image.file(file!, fit: BoxFit.cover)
                      else
                        Image.network(
                          existingUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xCC151A25)],
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF64E6A0),
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _placeholder(),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0E7FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.add_a_photo_rounded,
            size: 20,
            color: AppColors.employerPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF566176),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Chạm để tải ảnh',
          style: TextStyle(color: Color(0xFF9AA3B4), fontSize: 9.5),
        ),
      ],
    );
  }
}
