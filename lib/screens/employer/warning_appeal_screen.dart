import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../common/styles/app_colors.dart';
import '../../data/models/complaint_catalog_item.dart';
import '../../data/services/complaints_catalog_service.dart';

class WarningAppealScreen extends StatefulWidget {
  const WarningAppealScreen({super.key});

  @override
  State<WarningAppealScreen> createState() => _WarningAppealScreenState();
}

class _WarningAppealScreenState extends State<WarningAppealScreen> {
  final _svc = ComplaintsCatalogService();
  final _appealCtrl = TextEditingController();
  
  late ComplaintCatalogItem _item;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _item = Get.arguments as ComplaintCatalogItem;
  }

  @override
  void dispose() {
    _appealCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAppeal() async {
    final text = _appealCtrl.text.trim();
    if (text.isEmpty) {
      Get.snackbar('Lỗi', 'Vui lòng nhập nội dung giải trình/kháng cáo.');
      return;
    }
    if (text.length < 20) {
      Get.snackbar('Lỗi', 'Vui lòng nhập chi tiết hơn (ít nhất 20 ký tự).');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _svc.submitWarningAppeal(
        warningId: _item.id,
        appealText: text,
      );
      if (mounted) {
        Get.back(result: true); // Return true to trigger refresh
        Get.snackbar(
          'Thành công',
          'Đã gửi đơn kháng cáo. Vui lòng chờ Admin xem xét.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar('Lỗi', 'Không thể gửi kháng cáo: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAppealed = _item.appealStatus != null;
    final isPending = _item.appealStatus == 'pending';
    final isReviewed = _item.appealStatus == 'reviewed';
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      appBar: AppBar(
        backgroundColor: AppColors.employerPrimary,
        foregroundColor: Colors.white,
        title: const Text('Chi tiết Cảnh báo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWarningDetails(),
            const SizedBox(height: 16),
            if (hasAppealed) ...[
              _buildAppealStatus(isPending, isReviewed),
              const SizedBox(height: 16),
              _buildSubmittedAppeal(),
              if (isReviewed && _item.adminResponse != null && _item.adminResponse!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildAdminResponse(),
              ],
            ] else ...[
              _buildAppealForm(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _item.jobTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          const Text(
            'Lý do cảnh báo:',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            _item.summary,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Ngày nhận: ${DateFormat('dd/MM/yyyy HH:mm').format(_item.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealStatus(bool isPending, bool isReviewed) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPending ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPending ? Colors.orange.shade300 : Colors.blue.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPending ? Icons.pending_actions : Icons.verified,
            color: isPending ? Colors.orange.shade800 : Colors.blue.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isPending 
                  ? 'Đơn kháng cáo đang chờ Admin xem xét.'
                  : 'Admin đã phản hồi đơn kháng cáo của bạn.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isPending ? Colors.orange.shade900 : Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedAppeal() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_edu, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Nội dung bạn đã giải trình:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _item.appealText ?? '',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminResponse() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Phản hồi từ Admin:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _item.adminResponse ?? '',
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gửi đơn kháng cáo / Giải trình',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Nếu bạn cho rằng quyết định cảnh báo của Admin chưa chính xác (ví dụ do ứng viên báo cáo sai), hãy viết rõ lý do và cung cấp thêm thông tin để Admin xem xét lại.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _appealCtrl,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Nhập nội dung giải trình chi tiết...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitAppeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.employerPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Gửi giải trình', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
