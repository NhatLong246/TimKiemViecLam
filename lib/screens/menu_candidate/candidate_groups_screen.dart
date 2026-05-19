import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../controller/candidate_dashboard_controller.dart';
import '../../data/models/candidate_dashboard_models.dart';
import 'candidate_menu_scaffold.dart';

class CandidateGroupsScreen extends StatefulWidget {
  const CandidateGroupsScreen({super.key});

  @override
  State<CandidateGroupsScreen> createState() => _CandidateGroupsScreenState();
}

class _CandidateGroupsScreenState extends State<CandidateGroupsScreen> {
  final _ctrl = Get.put(CandidateDashboardController());

  @override
  void initState() {
    super.initState();
    _ctrl.loadGroups();
  }

  @override
  Widget build(BuildContext context) {
    return CandidateMenuScaffold(
      title: 'Nhóm làm việc',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        backgroundColor: candidateMenuPrimary,
        icon: const Icon(Icons.group_add),
        label: const Text('Tạo nhóm'),
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value && _ctrl.groups.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: candidateMenuPrimary),
          );
        }
        return RefreshIndicator(
          color: candidateMenuPrimary,
          onRefresh: _ctrl.loadGroups,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              _joinCard(context),
              const SizedBox(height: 20),
              const Text(
                'Nhóm của bạn',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_ctrl.groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Chưa có nhóm. Tạo nhóm mới hoặc tham gia bằng mã mời.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                ..._ctrl.groups.map(_groupCard),
            ],
          ),
        );
      }),
    );
  }

  Widget _joinCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: Color(0xFF1565C0)),
              SizedBox(width: 8),
              Text(
                'Tham gia nhóm bạn bè',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập mã 6 ký tự bạn nhận từ trưởng nhóm để cùng nhận ca.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _showJoinDialog(context),
            icon: const Icon(Icons.login),
            label: const Text('Nhập mã mời'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupCard(WorkGroup g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.groups, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  g.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoChip(Icons.people_outline, '${g.memberCount} thành viên'),
              const SizedBox(width: 8),
              _infoChip(Icons.work_outline, '${g.completedShifts} ca chung'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mã mời: ${g.inviteCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: g.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã')),
                  );
                },
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Sao chép',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo nhóm mới'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Tên nhóm',
            hintText: 'VD: Team ca tối Q1',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                final g = await _ctrl.createGroup(name);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã tạo nhóm. Mã mời: ${g.inviteCode}'),
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: candidateMenuPrimary),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  Future<void> _showJoinDialog(BuildContext context) async {
    final codeCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tham gia nhóm'),
        content: TextField(
          controller: codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã mời (6 ký tự)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _ctrl.joinGroup(codeCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã tham gia nhóm')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: candidateMenuPrimary),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
  }
}
