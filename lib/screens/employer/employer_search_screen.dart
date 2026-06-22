import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/job_post_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/job_criteria_model.dart';
import '../../routes/app_routes.dart';
import '../profile/cv_preview_screen.dart';
import '../../data/constants/language_proficiency_levels.dart';
import '../../data/services/candidate_discovery_service.dart';
import '../profile/job_criteria_options.dart';
import 'candidate_discovery_screen.dart';
import 'hire_request_sheet.dart';
import 'employer_reviews_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EmployerSearchScreen
// Argument (optional): Map {'openFilter': true}
// ─────────────────────────────────────────────────────────────────────────────
class EmployerSearchScreen extends StatefulWidget {
  const EmployerSearchScreen({super.key});

  @override
  State<EmployerSearchScreen> createState() => _EmployerSearchScreenState();
}

class _EmployerSearchScreenState extends State<EmployerSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  String _query = '';

  // ── Bộ lọc bài đăng ──────────────────────────────────────────────────────
  String _postStatus = 'all'; // all|pending|approved|active|closed|rejected
  String _postJobType = 'all'; // all|full_time|part_time

  // ── Bộ lọc người làm ─────────────────────────────────────────────────────
  String _workerSort = 'name';   // name|date
  String _workerHired = 'all';   // all|hired|not_hired
  String _workerLocation = 'Tất cả';
  String _workerGender = 'Tất cả'; // Tất cả|male|female|other
  String _workerCategory = 'Tất cả';
  String _workerLanguage = 'Tất cả';
  String _workerLanguageLevel = 'Tất cả';
  String _workerExperience = 'Tất cả'; // Tất cả|has_exp|no_exp

  // Firestore
  final _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      final args = Get.arguments;
      if (args is Map && args['openFilter'] == true) {
        Future.delayed(const Duration(milliseconds: 400), _showFilterSheet);
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildSearchHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _PostsTab(
                  query: _query,
                  status: _postStatus,
                  jobType: _postJobType,
                  uid: _uid ?? '',
                  db: _db,
                ),
                _WorkersTab(
                  query: _query,
                  sort: _workerSort,
                  hired: _workerHired,
                  location: _workerLocation,
                  gender: _workerGender,
                  category: _workerCategory,
                  language: _workerLanguage,
                  languageLevel: _workerLanguageLevel,
                  experience: _workerExperience,
                  uid: _uid ?? '',
                  db: _db,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header với search bar ─────────────────────────────────────────────────
  Widget _buildSearchHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: Get.back,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Search input
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search_rounded,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _focusNode,
                          onChanged: (v) => setState(() => _query = v.trim()),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A1A2E),
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Tìm bài đăng, người làm...',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Filter button
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      if (_hasActiveFilter())
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5252),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: const Color(0xFF7B1FA2),
        unselectedLabelColor: Colors.grey.shade500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        indicatorColor: const Color(0xFF7B1FA2),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.work_outline_rounded, size: 18),
                SizedBox(width: 6),
                Text('Bài đăng'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded, size: 18),
                SizedBox(width: 6),
                Text('Người làm'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter sheet ──────────────────────────────────────────────────────────
  void _showFilterSheet() {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Title
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF7B1FA2),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bộ lọc tìm kiếm',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setS(() {
                        if (_tab.index == 0) {
                          _postStatus = 'all';
                          _postJobType = 'all';
                        } else {
                          _workerSort = 'name';
                          _workerHired = 'all';
                          _workerLocation = 'Tất cả';
                          _workerGender = 'Tất cả';
                          _workerCategory = 'Tất cả';
                          _workerLanguage = 'Tất cả';
                          _workerLanguageLevel = 'Tất cả';
                          _workerExperience = 'Tất cả';
                        }
                      });
                      setState(() {
                        if (_tab.index == 0) {
                          _postStatus = 'all';
                          _postJobType = 'all';
                        } else {
                          _workerSort = 'name';
                          _workerHired = 'all';
                          _workerLocation = 'Tất cả';
                          _workerGender = 'Tất cả';
                          _workerCategory = 'Tất cả';
                          _workerLanguage = 'Tất cả';
                          _workerLanguageLevel = 'Tất cả';
                          _workerExperience = 'Tất cả';
                        }
                      });
                    },
                    child: const Text(
                      'Đặt lại',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tab.index == 0) ...[
                        // ─── Bài đăng filters ─────────────────────────────────────
                        _FilterSection(
                          title: 'Trạng thái bài đăng',
                          icon: Icons.work_outline_rounded,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final e in _postStatusOptions.entries)
                                _FilterChip(
                                  label: e.value,
                                  selected: _postStatus == e.key,
                                  onTap: () => setS(() {
                                    _postStatus = e.key;
                                    setState(() => _postStatus = e.key);
                                  }),
                                  color: _postStatusColor(e.key),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Loại công việc',
                          icon: Icons.schedule_rounded,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Tất cả',
                                selected: _postJobType == 'all',
                                onTap: () => setS(() {
                                  _postJobType = 'all';
                                  setState(() => _postJobType = 'all');
                                }),
                                color: const Color(0xFF7B1FA2),
                              ),
                              _FilterChip(
                                label: 'Full-time',
                                selected: _postJobType == 'full_time',
                                onTap: () => setS(() {
                                  _postJobType = 'full_time';
                                  setState(() => _postJobType = 'full_time');
                                }),
                                color: const Color(0xFF1565C0),
                              ),
                              _FilterChip(
                                label: 'Part-time',
                                selected: _postJobType == 'part_time',
                                onTap: () => setS(() {
                                  _postJobType = 'part_time';
                                  setState(() => _postJobType = 'part_time');
                                }),
                                color: const Color(0xFF2E7D32),
                              ),
                            ],
                          ),
                        ),
                        if (_postJobType == 'full_time') ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_search_rounded, size: 20),
                              label: const Text('Tìm ứng viên Full-time',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1565C0),
                                side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                Get.back(); // close bottom sheet
                                Get.to(() => const CandidateDiscoveryScreen());
                              },
                            ),
                          ),
                        ],
                      ] else ...[
                        // ─── Người làm filters ────────────────────────────────────
                        _FilterSection(
                          title: 'Sắp xếp người làm',
                          icon: Icons.people_outline_rounded,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Tên A–Z',
                                selected: _workerSort == 'name',
                                onTap: () => setS(() {
                                  _workerSort = 'name';
                                  setState(() => _workerSort = 'name');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Mới nhất',
                                selected: _workerSort == 'date',
                                onTap: () => setS(() {
                                  _workerSort = 'date';
                                  setState(() => _workerSort = 'date');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Trạng thái thuê',
                          icon: Icons.check_circle_outline_rounded,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Tất cả',
                                selected: _workerHired == 'all',
                                onTap: () => setS(() {
                                  _workerHired = 'all';
                                  setState(() => _workerHired = 'all');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Đã thuê',
                                selected: _workerHired == 'hired',
                                onTap: () => setS(() {
                                  _workerHired = 'hired';
                                  setState(() => _workerHired = 'hired');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Chưa thuê',
                                selected: _workerHired == 'not_hired',
                                onTap: () => setS(() {
                                  _workerHired = 'not_hired';
                                  setState(() => _workerHired = 'not_hired');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Khu vực ứng viên',
                          icon: Icons.location_on_outlined,
                          child: DropdownButtonFormField<String>(
                            value: _workerLocation,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: ['Tất cả', ...JobCriteriaOptions.locations].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setS(() {
                                  _workerLocation = val;
                                  setState(() => _workerLocation = val);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Giới tính',
                          icon: Icons.face_rounded,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              _FilterChip(
                                label: 'Tất cả',
                                selected: _workerGender == 'Tất cả',
                                onTap: () => setS(() {
                                  _workerGender = 'Tất cả';
                                  setState(() => _workerGender = 'Tất cả');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Nam',
                                selected: _workerGender == 'male',
                                onTap: () => setS(() {
                                  _workerGender = 'male';
                                  setState(() => _workerGender = 'male');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Nữ',
                                selected: _workerGender == 'female',
                                onTap: () => setS(() {
                                  _workerGender = 'female';
                                  setState(() => _workerGender = 'female');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                              _FilterChip(
                                label: 'Khác',
                                selected: _workerGender == 'other',
                                onTap: () => setS(() {
                                  _workerGender = 'other';
                                  setState(() => _workerGender = 'other');
                                }),
                                color: const Color(0xFF00695C),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Nghề nghiệp',
                          icon: Icons.category_outlined,
                          child: DropdownButtonFormField<String>(
                            value: _workerCategory,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: ['Tất cả', ...JobCriteriaOptions.careers].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setS(() {
                                  _workerCategory = val;
                                  setState(() => _workerCategory = val);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Kinh nghiệm làm việc',
                          icon: Icons.history_edu_outlined,
                          child: DropdownButtonFormField<String>(
                            value: _workerExperience,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả')),
                              DropdownMenuItem(value: 'no_exp', child: Text('Chưa có kinh nghiệm')),
                              DropdownMenuItem(value: 'under_1', child: Text('Dưới 1 năm')),
                              DropdownMenuItem(value: '1_to_3', child: Text('1 - 3 năm')),
                              DropdownMenuItem(value: '3_to_5', child: Text('3 - 5 năm')),
                              DropdownMenuItem(value: 'over_5', child: Text('Trên 5 năm')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setS(() {
                                  _workerExperience = val;
                                  setState(() => _workerExperience = val);
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Ngoại ngữ',
                          icon: Icons.translate_rounded,
                          child: DropdownButtonFormField<String>(
                            value: _workerLanguage,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: ['Tất cả', ...LanguageProficiencyLevels.languageOptions].map((lang) {
                              return DropdownMenuItem<String>(
                                value: lang,
                                child: Text(lang),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setS(() {
                                  _workerLanguage = val;
                                  _workerLanguageLevel = 'Tất cả';
                                  setState(() {
                                    _workerLanguage = val;
                                    _workerLanguageLevel = 'Tất cả';
                                  });
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        _FilterSection(
                          title: 'Trình độ ngoại ngữ',
                          icon: Icons.grade_outlined,
                          child: DropdownButtonFormField<String>(
                            value: _workerLanguageLevel,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            icon: const Icon(Icons.arrow_drop_down),
                            isExpanded: true,
                            items: () {
                              final List<String> levels = ['Tất cả'];
                              if (_workerLanguage != 'Tất cả') {
                                if (_workerLanguage == 'Tiếng Anh') {
                                  levels.addAll(['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'IELTS', 'TOEIC']);
                                } else {
                                  levels.addAll(LanguageProficiencyLevels.forLanguage(_workerLanguage));
                                }
                              }
                              return levels.map((lvl) {
                                return DropdownMenuItem<String>(
                                  value: lvl,
                                  child: Text(lvl),
                                );
                              }).toList();
                            }(),
                            onChanged: (val) {
                              if (val != null) {
                                setS(() {
                                  _workerLanguageLevel = val;
                                  setState(() => _workerLanguageLevel = val);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: Get.back,
                  child: const Text(
                    'Áp dụng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasActiveFilter() {
    if (_tab.index == 0) {
      return _postStatus != 'all' || _postJobType != 'all';
    } else {
      return _workerSort != 'name' ||
          _workerHired != 'all' ||
          _workerLocation != 'Tất cả' ||
          _workerGender != 'Tất cả' ||
          _workerCategory != 'Tất cả' ||
          _workerLanguage != 'Tất cả' ||
          _workerLanguageLevel != 'Tất cả' ||
          _workerExperience != 'Tất cả';
    }
  }

  static const _postStatusOptions = {
    'all': 'Tất cả',
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'active': 'Đang tuyển',
    'closed': 'Đã đóng',
    'rejected': 'Từ chối',
  };

  Color _postStatusColor(String s) {
    switch (s) {
      case 'approved':
        return const Color(0xFF2E7D32);
      case 'pending':
        return const Color(0xFFE65100);
      case 'active':
        return const Color(0xFF1565C0);
      case 'closed':
        return Colors.grey;
      case 'rejected':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFF7B1FA2);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Bài đăng
// ─────────────────────────────────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.query,
    required this.status,
    required this.jobType,
    required this.uid,
    required this.db,
  });

  final String query;
  final String status;
  final String jobType;
  final String uid;
  final FirebaseFirestore db;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('jobPosts')
          .where('employerId', isEqualTo: uid)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var posts = (snap.data?.docs ?? []).map((d) {
          final data = d.data() as Map<String, dynamic>;
          data['jobId'] = d.id;
          return JobPostModel.fromMap(data);
        }).toList();

        // Lọc theo status
        if (status != 'all') {
          posts = posts.where((p) => p.status == status).toList();
        }
        // Lọc theo jobType
        if (jobType != 'all') {
          posts = posts.where((p) => p.jobType == jobType).toList();
        }
        // Tìm theo query
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          posts = posts
              .where(
                (p) =>
                    p.title.toLowerCase().contains(q) ||
                    p.category.toLowerCase().contains(q) ||
                    (p.description.toLowerCase().contains(q)),
              )
              .toList();
        }

        // Sắp xếp mới nhất trước
        posts.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );

        if (posts.isEmpty) {
          return _emptyState(
            icon: Icons.work_off_outlined,
            title: query.isNotEmpty
                ? 'Không tìm thấy bài đăng'
                : 'Chưa có bài đăng nào',
            sub: query.isNotEmpty
                ? 'Thử tìm kiếm với từ khóa khác'
                : 'Bài đăng của bạn sẽ hiển thị ở đây',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: posts.length,
          itemBuilder: (_, i) => _PostCard(post: posts[i], query: query),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Người làm
// ─────────────────────────────────────────────────────────────────────────────
class _WorkersTab extends StatelessWidget {
  const _WorkersTab({
    required this.query,
    required this.sort,
    required this.uid,
    required this.db,
    required this.hired,
    required this.location,
    required this.gender,
    required this.category,
    required this.language,
    required this.languageLevel,
    required this.experience,
  });

  final String query;
  final String sort;
  final String uid;
  final FirebaseFirestore db;
  final String hired;
  final String location;
  final String gender;
  final String category;
  final String language;
  final String languageLevel;
  final String experience;

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    // Stream 1: Accepted applications to check hired status
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('applications')
          .where('employerId', isEqualTo: uid)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (ctx, appsSnap) {
        if (appsSnap.connectionState == ConnectionState.waiting && !appsSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final appsDocs = appsSnap.data?.docs ?? [];
        final hiredIds = appsDocs
            .map((d) => (d.data() as Map<String, dynamic>)['candidateId'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();

        // Stream 2: All candidates
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('users')
              .where('role', isEqualTo: 'candidate')
              .snapshots(),
          builder: (ctx2, usersSnap) {
            if (usersSnap.connectionState == ConnectionState.waiting && !usersSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userDocs = usersSnap.data?.docs ?? [];
            
            // Map raw documents to _WorkerEntry and pair with JobCriteriaModel
            final parsedWorkers = userDocs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final first = data['firstName'] as String? ?? '';
              final last = data['lastName'] as String? ?? '';
              data['uid'] = d.id;
              
              final userModel = UserModel.fromMap(data);
              final criteria = JobCriteriaModel.fromUserData(data);
              
              return _ParsedWorker(
                worker: _WorkerEntry(
                  uid: d.id,
                  name: '$first $last'.trim(),
                  avatarUrl: data['avatarUrl'] as String?,
                  phone: data['phoneNumber'] as String? ?? data['phone'] as String? ?? '',
                  rating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
                  jobsDone: (data['totalJobsDone'] as int?) ?? 0,
                  userModel: userModel,
                  isHired: hiredIds.contains(d.id),
                ),
                criteria: criteria,
                languages: data['languages'] as List? ?? [],
                workExperiences: data['workExperiences'] as List? ?? [],
                hasWorkExperience: data['hasWorkExperience'] as bool? ?? (data['workExperiences'] as List? ?? []).isNotEmpty,
              );
            }).toList();

            var filtered = parsedWorkers;

            // 1. Lọc theo trạng thái thuê
            if (hired == 'hired') {
              filtered = filtered.where((w) => hiredIds.contains(w.worker.uid)).toList();
            } else if (hired == 'not_hired') {
              filtered = filtered.where((w) => !hiredIds.contains(w.worker.uid)).toList();
            }

            // 2. Lọc theo khu vực
            if (location != 'Tất cả') {
              filtered = filtered.where((w) {
                if (w.criteria == null) return false;
                return w.criteria!.locations.any((loc) =>
                    loc.toLowerCase().contains(location.toLowerCase()));
              }).toList();
            }

            // 3. Lọc theo giới tính
            if (gender != 'Tất cả') {
              filtered = filtered.where((w) => w.worker.userModel.gender == gender).toList();
            }

            // 4. Lọc theo nghề nghiệp
            if (category != 'Tất cả') {
              filtered = filtered.where((w) {
                if (w.criteria == null) return false;
                return w.criteria!.careers.any((c) =>
                    c.toLowerCase().contains(category.toLowerCase()));
              }).toList();
            }

            // 5. Lọc theo ngoại ngữ
            if (language != 'Tất cả') {
              filtered = filtered.where((w) {
                if (language == 'Khác') {
                  final commonLanguages = ['tiếng anh', 'english', 'tiếng trung', 'chinese', 'tiếng nhật', 'japanese', 'tiếng hàn', 'korean'];
                  return w.languages.any((lang) {
                    final name = (lang['language'] as String? ?? '').toLowerCase();
                    return !commonLanguages.any((common) => name.contains(common));
                  });
                }
                final targetLang = language.toLowerCase();
                return w.languages.any((lang) {
                  final name = (lang['language'] as String? ?? '').toLowerCase();
                  if (targetLang == 'tiếng anh') {
                    return name.contains('anh') || name.contains('english');
                  } else if (targetLang == 'tiếng trung') {
                    return name.contains('trung') || name.contains('chinese');
                  } else if (targetLang == 'tiếng nhật') {
                    return name.contains('nhật') || name.contains('japanese');
                  } else if (targetLang == 'tiếng hàn') {
                    return name.contains('hàn') || name.contains('korean');
                  }
                  return name.contains(targetLang);
                });
              }).toList();
            }

            // 6. Lọc theo trình độ ngoại ngữ
            if (languageLevel != 'Tất cả' && language != 'Tất cả') {
              filtered = filtered.where((w) {
                final targetLang = language.toLowerCase();
                final targetLevel = languageLevel.toLowerCase();
                return w.languages.any((lang) {
                  final name = (lang['language'] as String? ?? '').toLowerCase();
                  
                  bool langMatch = false;
                  if (targetLang == 'tiếng anh') {
                    langMatch = name.contains('anh') || name.contains('english');
                  } else if (targetLang == 'tiếng trung') {
                    langMatch = name.contains('trung') || name.contains('chinese');
                  } else if (targetLang == 'tiếng nhật') {
                    langMatch = name.contains('nhật') || name.contains('japanese');
                  } else if (targetLang == 'tiếng hàn') {
                    langMatch = name.contains('hàn') || name.contains('korean');
                  } else if (targetLang == 'khác') {
                    final commonLanguages = ['tiếng anh', 'english', 'tiếng trung', 'chinese', 'tiếng nhật', 'japanese', 'tiếng hàn', 'korean'];
                    langMatch = !commonLanguages.any((common) => name.contains(common));
                  } else {
                    langMatch = name.contains(targetLang);
                  }
                  
                  if (!langMatch) return false;
                  
                  final lvl = (lang['level'] as String? ?? '').toLowerCase();
                  return lvl.contains(targetLevel) || lvl == targetLevel;
                });
              }).toList();
            }

            // 7. Lọc theo kinh nghiệm làm việc (số năm)
            if (experience != 'Tất cả') {
              filtered = filtered.where((w) {
                double totalYears = 0;
                for (final exp in w.workExperiences) {
                  try {
                    final map = Map<String, dynamic>.from(exp);
                    final startDateStr = map['startDate'] as String? ?? '';
                    final endDateStr = map['endDate'] as String? ?? '';
                    final currentlyWorking = map['currentlyWorking'] as bool? ?? false;

                    if (startDateStr.isEmpty) continue;

                    final startParts = startDateStr.split('/');
                    if (startParts.length < 2) continue;
                    final startMonth = int.tryParse(startParts[0]) ?? 1;
                    final startYear = int.tryParse(startParts[1]) ?? DateTime.now().year;
                    final startDateTime = DateTime(startYear, startMonth);

                    DateTime endDateTime;
                    if (currentlyWorking) {
                      endDateTime = DateTime.now();
                    } else {
                      if (endDateStr.isEmpty) continue;
                      final endParts = endDateStr.split('/');
                      if (endParts.length < 2) continue;
                      final endMonth = int.tryParse(endParts[0]) ?? 1;
                      final endYear = int.tryParse(endParts[1]) ?? DateTime.now().year;
                      endDateTime = DateTime(endYear, endMonth);
                    }

                    final diffDays = endDateTime.difference(startDateTime).inDays;
                    final diffMonths = diffDays / 30.437;
                    totalYears += diffMonths / 12.0;
                  } catch (_) {}
                }

                if (experience == 'no_exp') {
                  return totalYears < 0.05;
                } else if (experience == 'under_1') {
                  return totalYears > 0.05 && totalYears < 1.0;
                } else if (experience == '1_to_3') {
                  return totalYears >= 1.0 && totalYears <= 3.0;
                } else if (experience == '3_to_5') {
                  return totalYears >= 3.0 && totalYears <= 5.0;
                } else if (experience == 'over_5') {
                  return totalYears > 5.0;
                }
                return true;
              }).toList();
            }

            // 7. Lọc theo query (Tên hoặc SĐT hoặc Vị trí mong muốn)
            if (query.isNotEmpty) {
              final q = query.toLowerCase();
              filtered = filtered.where((w) {
                final nameMatches = w.worker.name.toLowerCase().contains(q);
                final phoneMatches = w.worker.phone.contains(q);
                final positionMatches = w.criteria?.position.toLowerCase().contains(q) ?? false;
                return nameMatches || phoneMatches || positionMatches;
              }).toList();
            }

            // 8. Sắp xếp
            if (sort == 'name') {
              filtered.sort((a, b) => a.worker.name.compareTo(b.worker.name));
            } else if (sort == 'date') {
              filtered.sort((a, b) {
                final dateA = a.worker.userModel.createdAt ?? DateTime(2000);
                final dateB = b.worker.userModel.createdAt ?? DateTime(2000);
                return dateB.compareTo(dateA); // Mới nhất lên trước
              });
            }

            if (filtered.isEmpty) {
              return _emptyState(
                icon: Icons.search_off_rounded,
                title: 'Không tìm thấy người làm',
                sub: 'Thử điều chỉnh bộ lọc hoặc từ khóa tìm kiếm khác',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: filtered.length,
              itemBuilder: (_, i) =>
                  _WorkerCard(worker: filtered[i].worker, query: query),
            );
          },
        );
      },
    );
  }
}

// Wrapper class helper
class _ParsedWorker {
  final _WorkerEntry worker;
  final JobCriteriaModel? criteria;
  final List<dynamic> languages;
  final List<dynamic> workExperiences;
  final bool hasWorkExperience;
  _ParsedWorker({
    required this.worker,
    this.criteria,
    required this.languages,
    required this.workExperiences,
    required this.hasWorkExperience,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Post card
// ─────────────────────────────────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.query});

  final JobPostModel post;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Get.toNamed(AppRoutes.postManagement),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B1FA2), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.work_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HighlightText(
                        text: post.title,
                        query: query,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _StatusBadge(status: post.status),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              post.jobType == 'full_time'
                                  ? 'Full-time'
                                  : 'Part-time',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${post.filledSlots}/${post.slots} người',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.attach_money_rounded,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                          Expanded(
                            child: Text(
                              _formatSalary(post.salary, post.salaryType),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (post.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Đăng: ${DateFormat('dd/MM/yyyy').format(post.createdAt!)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade300,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatSalary(double salary, String type) {
    final fmt = NumberFormat('#,###', 'vi');
    final s = fmt.format(salary.toInt());
    switch (type) {
      case 'per_hour':
        return '$s đ/giờ';
      case 'per_day':
        return '$s đ/ngày';
      case 'per_month':
        return '$s đ/tháng';
      default:
        return '$s đ';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Worker card
// ─────────────────────────────────────────────────────────────────────────────
class _WorkerCard extends StatelessWidget {
  const _WorkerCard({required this.worker, required this.query});

  final _WorkerEntry worker;
  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Get.bottomSheet(
              _SearchCandidateProfileSheet(worker: worker),
              isScrollControlled: true,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00695C), Color(0xFF1565C0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF7B1FA2).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: worker.avatarUrl != null
                          ? ClipOval(
                              child: Image.network(
                                worker.avatarUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _avatarFallback(worker.name),
                              ),
                            )
                          : _avatarFallback(worker.name),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _HighlightText(
                            text: worker.name.isEmpty
                                ? 'Người dùng'
                                : worker.name,
                            query: query,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (worker.phone.isNotEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  worker.phone,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Rating stars
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  i < worker.rating.round()
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 14,
                                  color: const Color(0xFFFFC107),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${worker.rating.toStringAsFixed(1)} • ${worker.jobsDone} việc',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade300,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      worker.isHired ? Icons.send_rounded : Icons.person_add_alt_1_rounded,
                      size: 16,
                    ),
                    label: Text(
                      worker.isHired ? 'Thuê lại' : 'Thuê ngay',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: worker.isHired ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      showHireRequestSheet(
                        context: context,
                        candidateId: worker.userModel.id,
                        candidateName: worker.name.isEmpty
                            ? 'Người làm'
                            : worker.name,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  static const _labels = {
    'pending': 'Chờ duyệt',
    'approved': 'Đã duyệt',
    'active': 'Đang tuyển',
    'closed': 'Đã đóng',
    'rejected': 'Từ chối',
    'draft': 'Nháp',
  };
  static const _colors = {
    'pending': Color(0xFFE65100),
    'approved': Color(0xFF2E7D32),
    'active': Color(0xFF1565C0),
    'closed': Colors.grey,
    'rejected': Color(0xFFC62828),
    'draft': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    final label = _labels[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Highlight từ khóa tìm kiếm trong text
class _HighlightText extends StatelessWidget {
  const _HighlightText({
    required this.text,
    required this.query,
    required this.style,
  });
  final String text;
  final String query;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);
    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final idx = lower.indexOf(qLower);
    if (idx < 0) return Text(text, style: style);

    return RichText(
      text: TextSpan(
        children: [
          if (idx > 0)
            TextSpan(
              text: text.substring(0, idx),
              style: style.copyWith(color: Colors.grey.shade700),
            ),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: style.copyWith(
              backgroundColor: const Color(0xFF7B1FA2).withOpacity(0.15),
              color: const Color(0xFF7B1FA2),
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(
              text: text.substring(idx + query.length),
              style: style.copyWith(color: Colors.grey.shade700),
            ),
        ],
      ),
    );
  }
}

Widget _emptyState({
  required IconData icon,
  required String title,
  required String sub,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFF7B1FA2).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 44,
              color: const Color(0xFF7B1FA2).withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.grey.shade500,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Filter section ────────────────────────────────────────────────────────────
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Filter chip ────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.25),
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Worker entry model ────────────────────────────────────────────────────────
class _WorkerEntry {
  final String uid;
  final String name;
  final String? avatarUrl;
  final String phone;
  final double rating;
  final int jobsDone;
  final UserModel userModel;
  final bool isHired;

  const _WorkerEntry({
    required this.uid,
    required this.name,
    this.avatarUrl,
    required this.phone,
    required this.rating,
    required this.jobsDone,
    required this.userModel,
    required this.isHired,
  });
}

// ─── Search Candidate Profile Sheet ───────────────────────────────────────────
class _SearchCandidateProfileSheet extends StatefulWidget {
  final _WorkerEntry worker;

  const _SearchCandidateProfileSheet({
    required this.worker,
  });

  @override
  State<_SearchCandidateProfileSheet> createState() => _SearchCandidateProfileSheetState();
}

class _SearchCandidateProfileSheetState extends State<_SearchCandidateProfileSheet> {
  UserModel? _fullUser;
  Map<String, dynamic>? _fullUserData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _recordProfileView();
    _fetchFullUser();
  }

  Future<void> _recordProfileView() async {
    final empId = FirebaseAuth.instance.currentUser?.uid;
    if (empId != null) {
      await CandidateDiscoveryService().recordProfileView(
        candidateId: widget.worker.uid,
        employerId: empId,
      );
    }
  }

  Future<void> _fetchFullUser() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.worker.uid)
          .get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            final data = Map<String, dynamic>.from(doc.data()!);
            data['uid'] = doc.id;
            _fullUserData = data;
            _fullUser = UserModel.fromMap(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _SearchCandidateAvatar(
                avatarUrl: widget.worker.avatarUrl,
                name: widget.worker.name,
              ),
              const SizedBox(height: 16),
              Text(
                widget.worker.name.isNotEmpty ? widget.worker.name : 'Ứng viên',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SearchStarRating(rating: widget.worker.rating),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.worker.rating.toStringAsFixed(1)} sao • ${widget.worker.jobsDone} việc',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                )
              else if (_fullUser != null) ...[
                _buildInfoRow(
                  Icons.email_outlined,
                  'Email',
                  _fullUser!.email.isNotEmpty ? _fullUser!.email : 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.phone_outlined,
                  'Số điện thoại',
                  _fullUser!.phone.isNotEmpty ? _fullUser!.phone : 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.person_outline,
                  'Giới tính',
                  _fullUser!.gender ?? 'Chưa cập nhật',
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  Icons.cake_outlined,
                  'Ngày sinh',
                  _fullUser!.dateOfBirth != null
                      ? DateFormat('dd/MM/yyyy').format(_fullUser!.dateOfBirth!)
                      : 'Chưa cập nhật',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_fullUserData != null) {
                        Get.to(() => CvPreviewScreen(userData: _fullUserData!));
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                    label: const Text(
                      'Xem CV ứng viên',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1FA2),
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.to(
                        () => const EmployerReviewsScreen(),
                        arguments: {
                          'uid': widget.worker.uid,
                          'title':
                              'Đánh giá về ${widget.worker.name.isNotEmpty ? widget.worker.name : 'ứng viên'}',
                        },
                      );
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text(
                      'Xem đánh giá về ứng viên',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1FA2),
                      side: const BorderSide(color: Color(0xFF7B1FA2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ] else
                Text(
                  'Không thể lấy thông tin chi tiết.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B1FA2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF7B1FA2), size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchCandidateAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;

  const _SearchCandidateAvatar({this.avatarUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF7B1FA2).withOpacity(0.12),
      backgroundImage: avatarUrl?.isNotEmpty == true
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl?.isNotEmpty != true
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Color(0xFF7B1FA2),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}

class _SearchStarRating extends StatelessWidget {
  final double rating;

  const _SearchStarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return Icon(
            Icons.star_rounded,
            size: 13,
            color: Colors.amber.shade500,
          );
        } else if (i < rating && rating - i >= 0.5) {
          return Icon(
            Icons.star_half_rounded,
            size: 13,
            color: Colors.amber.shade500,
          );
        }
        return Icon(
          Icons.star_outline_rounded,
          size: 13,
          color: Colors.grey.shade300,
        );
      }),
    );
  }
}
