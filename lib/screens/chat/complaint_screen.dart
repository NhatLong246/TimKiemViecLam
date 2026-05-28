import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/models/incident_model.dart';
import '../../data/models/user_model.dart';
import '../../data/services/group_chat_service.dart';
import '../../data/services/notification_service.dart';
import '../../routes/app_routes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ComplaintScreen — Khiếu nại nhân viên
// Argument: GroupChatModel
// ─────────────────────────────────────────────────────────────────────────────
class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  late final GroupChatModel _group;
  final _groupChatSvc = GroupChatService();
  final _auth = Get.find<AuthController>();

  List<UserModel>? _members;
  UserModel? _selectedWorker;
  final _descCtrl = TextEditingController();
  final _deductCtrl = TextEditingController(text: '0');
  final _compensationCtrl = TextEditingController(text: '0');
  final List<String> _imageBase64s = [];
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _group = Get.arguments as GroupChatModel;
    _loadMembers();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _deductCtrl.dispose();
    _compensationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final list = await _groupChatSvc.getGroupMembers(_group.memberIds);
    if (mounted) setState(() { _members = list; _loading = false; });
  }

  Future<void> _pickImage() async {
    if (_imageBase64s.length >= 4) {
      Get.snackbar('Giới hạn', 'Tối đa 4 ảnh minh chứng',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFFC62828)),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF1565C0)),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.length > 800 * 1024) {
      Get.snackbar('Ảnh quá lớn', 'Vui lòng chọn ảnh nhỏ hơn 800KB',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _imageBase64s.add(base64Encode(bytes)));
  }

  Future<void> _submit() async {
    if (_selectedWorker == null) {
      Get.snackbar('Thiếu thông tin', 'Vui lòng chọn nhân viên',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      Get.snackbar('Thiếu thông tin', 'Vui lòng nhập nội dung khiếu nại',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _submitting = true);

    try {
      final incident = IncidentModel(
        incidentId: '',
        groupId: _group.groupId,
        jobId: _group.jobId,
        reportedBy: _auth.currentUser?.id ?? '',
        workerId: _selectedWorker!.id,
        workerName:
            '${_selectedWorker!.firstName} ${_selectedWorker!.lastName}'
                .trim(),
        jobTitle: _group.jobTitle,
        description: _descCtrl.text.trim(),
        imageBase64s: List.from(_imageBase64s),
        deductAmount: double.tryParse(_deductCtrl.text) ?? 0,
        compensationAmount:
            double.tryParse(_compensationCtrl.text) ?? 0,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('incidents')
          .add(incident.toMap());

      await NotificationService().create(
        recipientId: _selectedWorker!.id,
        type: 'complaint_received',
        title: 'Khiếu nại về công việc bạn làm',
        body:
            'NTD khiếu nại về ca "${_group.jobTitle}" bạn đã làm. Xem mục Ca làm của tôi.',
        data: {
          'groupId': _group.groupId,
          'jobId': _group.jobId,
        },
      );

      Get.snackbar(
        'Đã gửi khiếu nại',
        'Đã lưu vào Danh mục khiếu nại. Admin sẽ xem xét.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      Get.toNamed(AppRoutes.complaintsCatalog, arguments: _group);

      // Reset form
      setState(() {
        _selectedWorker = null;
        _descCtrl.clear();
        _deductCtrl.text = '0';
        _compensationCtrl.text = '0';
        _imageBase64s.clear();
      });
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể gửi khiếu nại: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.employerPrimary,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.employerGradient)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: Get.back,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Khiếu nại nhân viên',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(_group.jobTitle,
                style:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin nhân viên
                  _buildWorkerPicker(),
                  const SizedBox(height: 16),
                  // Mô tả sự việc
                  _buildDescSection(),
                  const SizedBox(height: 16),
                  // Ảnh minh chứng
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  // Tài chính
                  _buildFinanceSection(),
                  const SizedBox(height: 16),
                  // Lưu ý
                  _buildWarning(),
                  const SizedBox(height: 24),
                  // Nút gửi
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildWorkerPicker() {
    return _SCard(
      title: 'Nhân viên bị khiếu nại',
      icon: Icons.person_off_rounded,
      iconColor: const Color(0xFFC62828),
      child: _loading || _members == null
          ? const Center(child: CircularProgressIndicator())
          : DropdownButtonFormField<UserModel>(
              value: _selectedWorker,
              hint: const Text('Chọn nhân viên'),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8F9FC),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              items: (_members ?? [])
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          '${m.firstName} ${m.lastName}'.trim(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedWorker = v),
            ),
    );
  }

  Widget _buildDescSection() {
    return _SCard(
      title: 'Nội dung khiếu nại',
      icon: Icons.description_rounded,
      iconColor: const Color(0xFFE65100),
      child: TextField(
        controller: _descCtrl,
        maxLines: 5,
        decoration: InputDecoration(
          hintText:
              'Mô tả chi tiết sự việc: vấn đề xảy ra, thời gian, địa điểm, mức độ ảnh hưởng...',
          hintStyle: TextStyle(
              color: Colors.grey.shade400, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF8F9FC),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return _SCard(
      title: 'Ảnh minh chứng (tối đa 4)',
      icon: Icons.photo_library_rounded,
      iconColor: const Color(0xFF1565C0),
      child: Column(
        children: [
          // Lưới ảnh
          if (_imageBase64s.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: _imageBase64s.asMap().entries.map((e) {
                final bytes = base64Decode(e.value);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(bytes,
                          fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => setState(
                            () => _imageBase64s.removeAt(e.key)),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          // Nút thêm
          if (_imageBase64s.length < 4)
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color:
                          const Color(0xFF1565C0).withOpacity(0.3),
                      style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: const Color(0xFF1565C0), size: 28),
                    const SizedBox(height: 6),
                    Text(
                      'Thêm ảnh minh chứng',
                      style: TextStyle(
                          color: const Color(0xFF1565C0),
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFinanceSection() {
    return _SCard(
      title: 'Thông tin tài chính',
      icon: Icons.account_balance_wallet_rounded,
      iconColor: const Color(0xFF7B1FA2),
      child: Column(
        children: [
          _MoneyField(
            label: 'Số tiền trừ lương (VNĐ)',
            controller: _deductCtrl,
            color: const Color(0xFFC62828),
            icon: Icons.remove_circle_outline,
          ),
          const SizedBox(height: 12),
          _MoneyField(
            label: 'Số tiền bồi thường (VNĐ)',
            controller: _compensationCtrl,
            color: const Color(0xFFE65100),
            icon: Icons.payments_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF9800).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_rounded,
              color: Color(0xFFFF9800), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Khiếu nại sẽ được gửi đến Admin để xem xét. '
              'Vui lòng cung cấp thông tin chính xác và đầy đủ minh chứng.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFC62828), Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFC62828).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, color: Colors.white),
          label: Text(
              _submitting ? 'Đang gửi...' : 'Gửi khiếu nại',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────
class _SCard extends StatelessWidget {
  const _SCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  const _MoneyField({
    required this.label,
    required this.controller,
    required this.color,
    required this.icon,
  });
  final String label;
  final TextEditingController controller;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: color),
        prefixIcon: Icon(icon, color: color, size: 20),
        suffixText: 'VNĐ',
        suffixStyle:
            TextStyle(color: color, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: color, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
