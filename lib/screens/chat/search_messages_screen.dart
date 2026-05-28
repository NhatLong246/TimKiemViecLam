import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../common/styles/app_colors.dart';
import '../../controller/login_controller.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/models/group_chat_model.dart';
import '../../data/services/group_chat_service.dart';
import '../messaging/chat_room_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SearchMessagesScreen — Tìm kiếm tin nhắn trong nhóm
// Argument: GroupChatModel
// ─────────────────────────────────────────────────────────────────────────────
class SearchMessagesScreen extends StatefulWidget {
  const SearchMessagesScreen({super.key});

  @override
  State<SearchMessagesScreen> createState() => _SearchMessagesScreenState();
}

class _SearchMessagesScreenState extends State<SearchMessagesScreen> {
  late final GroupChatModel _group;
  final _service = GroupChatService();
  final _searchCtrl = TextEditingController();

  List<ChatMessageModel>? _results;
  bool _searching = false;
  String _lastQuery = '';

  void _onSearchTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _group = Get.arguments as GroupChatModel;
    _searchCtrl.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;

    if (q.isEmpty) {
      setState(() => _results = null);
      return;
    }

    setState(() => _searching = true);
    final results = await _service.searchMessages(_group.groupId, q);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
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
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 14,
            ),
            cursorColor: AppColors.employerPrimary,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            onChanged: (v) {
              if (v.trim().length >= 2) {
                _search(v);
              } else if (v.trim().isEmpty) {
                setState(() {
                  _results = null;
                  _lastQuery = '';
                });
              }
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tin nhắn...',
              hintStyle: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade600,
                size: 20,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade600,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _results = null;
                          _lastQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nhập từ khóa để tìm kiếm',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Tìm kiếm trong tin nhắn văn bản của nhóm',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    if (_results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.find_in_page_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Không tìm thấy kết quả',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Thử tìm với từ khóa khác',
                style: TextStyle(
                    color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Text(
            'Tìm thấy ${_results!.length} kết quả cho "$_lastQuery"',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _results!.length,
            itemBuilder: (_, i) => _ResultCard(
              msg: _results![i],
              query: _lastQuery,
              groupId: _group.groupId,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.msg,
    required this.query,
    required this.groupId,
  });
  final ChatMessageModel msg;
  final String query;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(msg.createdAt);

    return InkWell(
      onTap: () {
        final isEmployer =
            Get.find<AuthController>().currentUser?.role == 'employer';
        Get.to(
          () => ChatRoomScreen(
            groupId: groupId,
            isEmployer: isEmployer,
          ),
          transition: Transition.rightToLeft,
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender + time
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      AppColors.employerPrimary.withOpacity(0.12),
                  child: Text(
                    msg.senderName.isNotEmpty
                        ? msg.senderName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.employerPrimary,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg.senderName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                Text(dateStr,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
            const SizedBox(height: 8),
            // Highlighted content
            _HighlightedText(text: msg.content, query: query),
          ],
        ),
      ),
    ),
    );
  }
}

// Widget hiển thị text với phần khớp query được highlight
class _HighlightedText extends StatelessWidget {
  const _HighlightedText({required this.text, required this.query});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 14));
    }

    final lower = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(
            backgroundColor: Color(0xFFFFEB3B),
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121)),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
        children: spans,
      ),
    );
  }
}
