import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/styles/app_colors.dart';
import '../../data/services/login_history_service.dart';

class EmployerLoginHistoryScreen extends StatefulWidget {
  const EmployerLoginHistoryScreen({super.key});

  @override
  State<EmployerLoginHistoryScreen> createState() =>
      _EmployerLoginHistoryScreenState();
}

class _EmployerLoginHistoryScreenState
    extends State<EmployerLoginHistoryScreen> {
  final _service = LoginHistoryService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchHistory();
      setState(() => _records = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd/MM/yyyy – HH:mm').format(ts.toDate());
    }
    return '—';
  }

  String _methodLabel(String? method) {
    switch (method) {
      case 'google':
        return 'Google';
      case 'facebook':
        return 'Facebook';
      case 'email':
      default:
        return 'Email & Mật khẩu';
    }
  }

  IconData _methodIcon(String? method) {
    switch (method) {
      case 'google':
        return Icons.g_mobiledata;
      case 'facebook':
        return Icons.facebook;
      default:
        return Icons.email_outlined;
    }
  }

  Color _methodColor(String? method) {
    switch (method) {
      case 'google':
        return const Color(0xFFDB4437);
      case 'facebook':
        return const Color(0xFF3B5998);
      default:
        return AppColors.employerPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Lịch sử đăng nhập',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.employerPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.employerPrimary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'Không thể tải dữ liệu',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Chưa có lịch sử đăng nhập',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.employerPrimary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final record = _records[index];
          final method = record['method'] as String?;
          final platform = record['platform'] as String? ?? 'Unknown';
          final isFirst = index == 0;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isFirst ? 20 : 10),
                  blurRadius: isFirst ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: isFirst
                  ? Border.all(
                      color: AppColors.employerPrimary.withAlpha(100),
                      width: 1.5,
                    )
                  : null,
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _methodColor(method).withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _methodIcon(method),
                  color: _methodColor(method),
                  size: 22,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    _methodLabel(method),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                    ),
                  ),
                  if (isFirst) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Gần nhất',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 13, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(record['timestamp']),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        platform == 'Android'
                            ? Icons.android
                            : Icons.phone_iphone,
                        size: 13,
                        color: const Color(0xFF9E9E9E),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        platform,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9E9E9E)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
