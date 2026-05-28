import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/notification_service.dart';

/// Cài đặt nhận thông báo — đồng bộ Firestore + cache cục bộ.
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
  static const _keyMessage = 'notify_message';

  final _service = NotificationService();

  bool _job = true;
  bool _system = true;
  bool _promo = false;
  bool _profile = true;
  bool _message = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, bool> remote = {};
    try {
      remote = await _service.loadPrefs();
    } catch (_) {}

    setState(() {
      _job = remote['job'] ?? prefs.getBool(_keyJob) ?? true;
      _system = remote['system'] ?? prefs.getBool(_keySystem) ?? true;
      _promo = remote['promo'] ?? prefs.getBool(_keyPromo) ?? false;
      _profile = remote['profile'] ?? prefs.getBool(_keyProfile) ?? true;
      _message = remote['message'] ?? prefs.getBool(_keyMessage) ?? true;
      _loading = false;
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyJob, _job);
    await prefs.setBool(_keySystem, _system);
    await prefs.setBool(_keyPromo, _promo);
    await prefs.setBool(_keyProfile, _profile);
    await prefs.setBool(_keyMessage, _message);

    await _service.savePrefs({
      'job': _job,
      'system': _system,
      'promo': _promo,
      'profile': _profile,
      'message': _message,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tùy chọn được lưu trên tài khoản. Thông báo trong app (hộp thư) '
                    'hiển thị theo loại bạn bật.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    child: Column(
                      children: [
                        _buildSwitch(
                          title: 'Việc làm & ứng tuyển',
                          subtitle:
                              'Trạng thái đơn, chấp nhận, nhắc nhở ca làm',
                          value: _job,
                          onChanged: (v) async {
                            setState(() => _job = v);
                            await _saveAll();
                          },
                        ),
                        const _SettingsDivider(),
                        _buildSwitch(
                          title: 'Hệ thống',
                          subtitle: 'Bảo mật, cập nhật ứng dụng',
                          value: _system,
                          onChanged: (v) async {
                            setState(() => _system = v);
                            await _saveAll();
                          },
                        ),
                        const _SettingsDivider(),
                        _buildSwitch(
                          title: 'Khuyến mãi',
                          subtitle: 'Ưu đãi và sự kiện từ ViecNow',
                          value: _promo,
                          onChanged: (v) async {
                            setState(() => _promo = v);
                            await _saveAll();
                          },
                        ),
                        const _SettingsDivider(),
                        _buildSwitch(
                          title: 'Hồ sơ',
                          subtitle: 'Gợi ý hoàn thiện hồ sơ',
                          value: _profile,
                          onChanged: (v) async {
                            setState(() => _profile = v);
                            await _saveAll();
                          },
                        ),
                        const _SettingsDivider(),
                        _buildSwitch(
                          title: 'Tin nhắn',
                          subtitle:
                              'Tin mới từ nhóm chat hoặc chat cá nhân',
                          value: _message,
                          onChanged: (v) async {
                            setState(() => _message = v);
                            await _saveAll();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
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
        color: Theme.of(context).cardColor,
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
