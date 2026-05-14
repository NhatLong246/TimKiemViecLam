import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:viecnow/controller/update_account_controller.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  static const Color _primary = Color(0xFF2E7D32);
  static const Color _iconBg = Color(0xFFE8F5E9);
  static const Color _border = Color(0xFFE2E2E2);

  @override
  Widget build(BuildContext context) {
    final UpdateAccountController controller = Get.put(
      UpdateAccountController(),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF666666)),
        ),
        title: const Text(
          'Hồ sơ của tôi',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder(
          stream: controller.getUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.hasData && snapshot.data!.exists
                ? snapshot.data!.data() as Map<String, dynamic>
                : <String, dynamic>{};

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  _buildProfileInfoCard(context, data),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.favorite_border,
                    title: 'Giới thiệu bản thân',
                    trailingIcon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 22),
                  _buildExperienceSection(),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.school_outlined,
                    title: 'Học vấn',
                    trailingIcon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.bolt_outlined,
                    title: 'Kỹ năng',
                    trailingIcon: Icons.edit_outlined,
                  ),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.theater_comedy_outlined,
                    title: 'Dự án/ Thành tựu',
                    trailingIcon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.card_membership_outlined,
                    title: 'Chứng chỉ/ Bằng cấp',
                    trailingIcon: Icons.add_circle_outline,
                  ),
                  const SizedBox(height: 22),
                  _buildSimpleSection(
                    icon: Icons.translate_outlined,
                    title: 'Ngoại ngữ',
                    trailingIcon: Icons.add_circle_outline,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileInfoCard(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final fullName = _joinValues([data['firstName'], data['lastName']]);
    final phone = _stringValue(data['phone']);
    final email = _stringValue(data['email']);
    final gender = _stringValue(data['gender']);
    final dateOfBirth = _dateValue(data['dateOfBirth']);
    final address = _joinValues([data['companyAddress'], data['address']]);
    final items = <Widget>[
      if (fullName.isNotEmpty) _buildInfoLine(Icons.people_outline, fullName),
      if (phone.isNotEmpty) _buildVerifiedInfoLine(Icons.phone_outlined, phone),
      if (email.isNotEmpty) _buildVerifiedInfoLine(Icons.email_outlined, email),
      if (address.isNotEmpty)
        _buildInfoLine(Icons.location_on_outlined, address),
      if (gender.isNotEmpty) _buildInfoLine(Icons.wc_outlined, gender),
      if (dateOfBirth.isNotEmpty)
        _buildInfoLine(Icons.cake_outlined, dateOfBirth),
    ];

    return _ProfileFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildIconBox(Icons.person_outline),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Thông tin cá nhân',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Color(0xFF666666),
                  size: 28,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[const SizedBox(height: 12), ...items],
        ],
      ),
    );
  }

  String _stringValue(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    if (text == 'Not set' || text == 'Chưa cập nhật') return '';
    return text;
  }

  String _joinValues(List<dynamic> values) {
    return values
        .map(_stringValue)
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  String _dateValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(value.toDate());
    }
    return _stringValue(value);
  }

  Widget _buildInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF555555)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedInfoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF555555)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
          ),
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Color(0xFF37B96B),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSection({
    required IconData icon,
    required String title,
    required IconData trailingIcon,
  }) {
    return _ProfileFormCard(
      child: Row(
        children: [
          _buildIconBox(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(trailingIcon, color: const Color(0xFF555555), size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection() {
    return _ProfileFormCard(
      child: Column(
        children: [
          Row(
            children: [
              _buildIconBox(Icons.business_center_outlined),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Kinh nghiệm làm việc',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8FFF1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Đề xuất',
                  style: TextStyle(
                    color: Color(0xFF37B96B),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Color(0xFF555555),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F4F8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bạn đã có kinh nghiệm làm việc chưa?',
                  style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildExperienceChoice('Chưa có')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildExperienceChoice('Đã có')),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceChoice(String title) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _primary, size: 24),
    );
  }
}

class _ProfileFormCard extends StatelessWidget {
  final Widget child;

  const _ProfileFormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E1E1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
