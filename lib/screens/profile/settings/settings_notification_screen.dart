import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cài đặt nhận thông báo (lưu cục bộ).
class SettingsNotificationScreen extends StatefulWidget {
  const SettingsNotificationScreen({super.key});

  @override
  State<SettingsNotificationScreen> createState() =>
      _SettingsNotificationScreenState();
}

class _SettingsNotificationScreenState extends State<SettingsNotificationScreen> {
  static const _keyJob = 'notify_job';
  static const _keySystem = 'notify_system';
  static const _keyPromo = 'notify_promo';
  static const _keyProfile = 'notify_profile';

  bool _job = true;
  bool _system = true;
  bool _promo = false;
  bool _profile = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _job = prefs.getBool(_keyJob) ?? true;
      _system = prefs.getBool(_keySystem) ?? true;
      _promo = prefs.getBool(_keyPromo) ?? false;
      _profile = prefs.getBool(_keyProfile) ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
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
          'Thông báo',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: _SettingsCard(
                child: Column(
                  children: [
                    _buildSwitch(
                      title: 'Việc làm & ứng tuyển',
                      subtitle: 'Cập nhật trạng thái hồ sơ, lời mời phỏng vấn',
                      value: _job,
                      onChanged: (v) async {
                        setState(() => _job = v);
                        await _set(_keyJob, v);
                      },
                    ),
                    const _SettingsDivider(),
                    _buildSwitch(
                      title: 'Hệ thống',
                      subtitle: 'Bảo mật tài khoản, cập nhật ứng dụng',
                      value: _system,
                      onChanged: (v) async {
                        setState(() => _system = v);
                        await _set(_keySystem, v);
                      },
                    ),
                    const _SettingsDivider(),
                    _buildSwitch(
                      title: 'Khuyến mãi',
                      subtitle: 'Ưu đãi và sự kiện từ ViecNow',
                      value: _promo,
                      onChanged: (v) async {
                        setState(() => _promo = v);
                        await _set(_keyPromo, v);
                      },
                    ),
                    const _SettingsDivider(),
                    _buildSwitch(
                      title: 'Hồ sơ',
                      subtitle: 'Gợi ý hoàn thiện hồ sơ',
                      value: _profile,
                      onChanged: (v) async {
                        setState(() => _profile = v);
                        await _set(_keyProfile, v);
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF888888),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF2E7D32).withValues(alpha: 0.45),
            activeThumbColor: const Color(0xFF2E7D32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

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

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(height: 1, color: Color(0xFFEDEDED)),
    );
  }
}
