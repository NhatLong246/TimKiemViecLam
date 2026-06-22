import 'package:flutter/material.dart';
import 'package:viecnow/data/models/candidate_profile_models.dart';
import 'package:viecnow/data/models/work_experience_model.dart';

/// Enum định nghĩa các bố cục CV
enum CvLayoutType {
  sidebarLeft, // 2 Cột: Trái nhỏ (Sidebar), Phải to
  sidebarRight, // 2 Cột: Trái to, Phải nhỏ (Sidebar)
  topHeader, // 1 Cột chung Header, dưới chia 2 cột
  minimal, // 1 Cột kéo dài từ trên xuống dưới kiểu truyền thống
}

/// Class cấu hình cho một Mẫu CV (Theme)
class CvTheme {
  final String id;
  final String name;
  final CvLayoutType layout;
  final Color primaryAccent;
  final Color sidebarBg;
  final Color sidebarText;
  final Color mainBg;
  final Color mainText;
  final Color mutedText;

  const CvTheme({
    required this.id,
    required this.name,
    required this.layout,
    required this.primaryAccent,
    required this.sidebarBg,
    required this.sidebarText,
    required this.mainBg,
    required this.mainText,
    required this.mutedText,
  });
}

// 5 Bảng màu (Palettes)
final _emeraldPalette = {
  'accent': const Color(0xFF10B981),
  'darkBg': const Color(0xFF1F2937),
  'darkText': Colors.white,
  'lightBg': Colors.white,
  'lightText': const Color(0xFF111827),
  'muted': const Color(0xFF6B7280),
};
final _navyPalette = {
  'accent': const Color(0xFF2563EB),
  'darkBg': const Color(0xFF1E3A8A),
  'darkText': Colors.white,
  'lightBg': const Color(0xFFF8FAFC),
  'lightText': const Color(0xFF0F172A),
  'muted': const Color(0xFF475569),
};
final _rubyPalette = {
  'accent': const Color(0xFFE11D48),
  'darkBg': const Color(0xFF4C0519),
  'darkText': const Color(0xFFFFE4E6),
  'lightBg': const Color(0xFFFFF1F2),
  'lightText': const Color(0xFF881337),
  'muted': const Color(0xFF9F1239),
};
final _obsidianPalette = {
  'accent': const Color(0xFF374151),
  'darkBg': const Color(0xFF111827),
  'darkText': const Color(0xFFF9FAFB),
  'lightBg': Colors.white,
  'lightText': Colors.black87,
  'muted': const Color(0xFF6B7280),
};
final _amberPalette = {
  'accent': const Color(0xFFD97706),
  'darkBg': const Color(0xFFFFFBEB),
  'darkText': const Color(0xFF78350F),
  'lightBg': Colors.white,
  'lightText': const Color(0xFF451A03),
  'muted': const Color(0xFF92400E),
};

// Khởi tạo 20 mẫu (4 layouts x 5 palettes)
final List<CvTheme> cvTemplates = [
  // L1: Sidebar Left (Classic)
  CvTheme(id: 'sl_em', name: 'Ngọc Bích Cổ Điển', layout: CvLayoutType.sidebarLeft, primaryAccent: _emeraldPalette['accent'] as Color, sidebarBg: _emeraldPalette['darkBg'] as Color, sidebarText: _emeraldPalette['darkText'] as Color, mainBg: _emeraldPalette['lightBg'] as Color, mainText: _emeraldPalette['lightText'] as Color, mutedText: _emeraldPalette['muted'] as Color),
  CvTheme(id: 'sl_na', name: 'Hải Quân Khởi Nghiệp', layout: CvLayoutType.sidebarLeft, primaryAccent: _navyPalette['accent'] as Color, sidebarBg: _navyPalette['darkBg'] as Color, sidebarText: _navyPalette['darkText'] as Color, mainBg: _navyPalette['lightBg'] as Color, mainText: _navyPalette['lightText'] as Color, mutedText: _navyPalette['muted'] as Color),
  CvTheme(id: 'sl_ru', name: 'Đỏ Ruby Quyến Rũ', layout: CvLayoutType.sidebarLeft, primaryAccent: _rubyPalette['accent'] as Color, sidebarBg: _rubyPalette['darkBg'] as Color, sidebarText: _rubyPalette['darkText'] as Color, mainBg: _rubyPalette['lightBg'] as Color, mainText: _rubyPalette['lightText'] as Color, mutedText: _rubyPalette['muted'] as Color),
  CvTheme(id: 'sl_ob', name: 'Đen Huyền Bí', layout: CvLayoutType.sidebarLeft, primaryAccent: _obsidianPalette['accent'] as Color, sidebarBg: _obsidianPalette['darkBg'] as Color, sidebarText: _obsidianPalette['darkText'] as Color, mainBg: _obsidianPalette['lightBg'] as Color, mainText: _obsidianPalette['lightText'] as Color, mutedText: _obsidianPalette['muted'] as Color),
  CvTheme(id: 'sl_am', name: 'Vàng Năng Động', layout: CvLayoutType.sidebarLeft, primaryAccent: _amberPalette['accent'] as Color, sidebarBg: _amberPalette['darkBg'] as Color, sidebarText: _amberPalette['darkText'] as Color, mainBg: _amberPalette['lightBg'] as Color, mainText: _amberPalette['lightText'] as Color, mutedText: _amberPalette['muted'] as Color),

  // L2: Sidebar Right (Nổi Bật)
  CvTheme(id: 'sr_em', name: 'Trái Chiều Ngọc Bích', layout: CvLayoutType.sidebarRight, primaryAccent: _emeraldPalette['accent'] as Color, sidebarBg: _emeraldPalette['darkBg'] as Color, sidebarText: _emeraldPalette['darkText'] as Color, mainBg: _emeraldPalette['lightBg'] as Color, mainText: _emeraldPalette['lightText'] as Color, mutedText: _emeraldPalette['muted'] as Color),
  CvTheme(id: 'sr_na', name: 'Hải Quân Sáng Tạo', layout: CvLayoutType.sidebarRight, primaryAccent: _navyPalette['accent'] as Color, sidebarBg: _navyPalette['darkBg'] as Color, sidebarText: _navyPalette['darkText'] as Color, mainBg: _navyPalette['lightBg'] as Color, mainText: _navyPalette['lightText'] as Color, mutedText: _navyPalette['muted'] as Color),
  CvTheme(id: 'sr_ru', name: 'Máu Lửa Khác Biệt', layout: CvLayoutType.sidebarRight, primaryAccent: _rubyPalette['accent'] as Color, sidebarBg: _rubyPalette['darkBg'] as Color, sidebarText: _rubyPalette['darkText'] as Color, mainBg: _rubyPalette['lightBg'] as Color, mainText: _rubyPalette['lightText'] as Color, mutedText: _rubyPalette['muted'] as Color),
  CvTheme(id: 'sr_ob', name: 'Bóng Tối Tinh Tế', layout: CvLayoutType.sidebarRight, primaryAccent: _obsidianPalette['accent'] as Color, sidebarBg: _obsidianPalette['darkBg'] as Color, sidebarText: _obsidianPalette['darkText'] as Color, mainBg: _obsidianPalette['lightBg'] as Color, mainText: _obsidianPalette['lightText'] as Color, mutedText: _obsidianPalette['muted'] as Color),
  CvTheme(id: 'sr_am', name: 'Nắng Ban Mai', layout: CvLayoutType.sidebarRight, primaryAccent: _amberPalette['accent'] as Color, sidebarBg: _amberPalette['darkBg'] as Color, sidebarText: _amberPalette['darkText'] as Color, mainBg: _amberPalette['lightBg'] as Color, mainText: _amberPalette['lightText'] as Color, mutedText: _amberPalette['muted'] as Color),

  // L3: Top Header (Chuyên Nghiệp)
  CvTheme(id: 'th_em', name: 'Ngọc Bích Lãnh Đạo', layout: CvLayoutType.topHeader, primaryAccent: _emeraldPalette['accent'] as Color, sidebarBg: _emeraldPalette['darkBg'] as Color, sidebarText: _emeraldPalette['darkText'] as Color, mainBg: _emeraldPalette['lightBg'] as Color, mainText: _emeraldPalette['lightText'] as Color, mutedText: _emeraldPalette['muted'] as Color),
  CvTheme(id: 'th_na', name: 'Hải Quân Báo Cáo', layout: CvLayoutType.topHeader, primaryAccent: _navyPalette['accent'] as Color, sidebarBg: _navyPalette['darkBg'] as Color, sidebarText: _navyPalette['darkText'] as Color, mainBg: _navyPalette['lightBg'] as Color, mainText: _navyPalette['lightText'] as Color, mutedText: _navyPalette['muted'] as Color),
  CvTheme(id: 'th_ru', name: 'Cờ Đỏ Đĩnh Đạc', layout: CvLayoutType.topHeader, primaryAccent: _rubyPalette['accent'] as Color, sidebarBg: _rubyPalette['darkBg'] as Color, sidebarText: _rubyPalette['darkText'] as Color, mainBg: _rubyPalette['lightBg'] as Color, mainText: _rubyPalette['lightText'] as Color, mutedText: _rubyPalette['muted'] as Color),
  CvTheme(id: 'th_ob', name: 'Khoa Học Đen', layout: CvLayoutType.topHeader, primaryAccent: _obsidianPalette['accent'] as Color, sidebarBg: _obsidianPalette['darkBg'] as Color, sidebarText: _obsidianPalette['darkText'] as Color, mainBg: _obsidianPalette['lightBg'] as Color, mainText: _obsidianPalette['lightText'] as Color, mutedText: _obsidianPalette['muted'] as Color),
  CvTheme(id: 'th_am', name: 'Vương Giả', layout: CvLayoutType.topHeader, primaryAccent: _amberPalette['accent'] as Color, sidebarBg: _amberPalette['darkBg'] as Color, sidebarText: _amberPalette['darkText'] as Color, mainBg: _amberPalette['lightBg'] as Color, mainText: _amberPalette['lightText'] as Color, mutedText: _amberPalette['muted'] as Color),

  // L4: Minimal (Tối Giản)
  CvTheme(id: 'mi_em', name: 'Xanh Lá Tối Giản', layout: CvLayoutType.minimal, primaryAccent: _emeraldPalette['accent'] as Color, sidebarBg: _emeraldPalette['lightBg'] as Color, sidebarText: _emeraldPalette['lightText'] as Color, mainBg: _emeraldPalette['lightBg'] as Color, mainText: _emeraldPalette['lightText'] as Color, mutedText: _emeraldPalette['muted'] as Color),
  CvTheme(id: 'mi_na', name: 'Harvard Navy', layout: CvLayoutType.minimal, primaryAccent: _navyPalette['accent'] as Color, sidebarBg: _navyPalette['lightBg'] as Color, sidebarText: _navyPalette['lightText'] as Color, mainBg: _navyPalette['lightBg'] as Color, mainText: _navyPalette['lightText'] as Color, mutedText: _navyPalette['muted'] as Color),
  CvTheme(id: 'mi_ru', name: 'Hồng Phấn Gọn Gàng', layout: CvLayoutType.minimal, primaryAccent: _rubyPalette['accent'] as Color, sidebarBg: _rubyPalette['lightBg'] as Color, sidebarText: _rubyPalette['lightText'] as Color, mainBg: _rubyPalette['lightBg'] as Color, mainText: _rubyPalette['lightText'] as Color, mutedText: _rubyPalette['muted'] as Color),
  CvTheme(id: 'mi_ob', name: 'Trắng Đen Truyền Thống', layout: CvLayoutType.minimal, primaryAccent: _obsidianPalette['accent'] as Color, sidebarBg: Colors.white, sidebarText: Colors.black87, mainBg: Colors.white, mainText: Colors.black87, mutedText: Colors.black54),
  CvTheme(id: 'mi_am', name: 'Nâu Sữa Mộc Mạc', layout: CvLayoutType.minimal, primaryAccent: _amberPalette['accent'] as Color, sidebarBg: _amberPalette['lightBg'] as Color, sidebarText: _amberPalette['lightText'] as Color, mainBg: _amberPalette['lightBg'] as Color, mainText: _amberPalette['lightText'] as Color, mutedText: _amberPalette['muted'] as Color),
];

/// Xem trước CV VIP (Hệ thống 20 mẫu Động)
class CvPreviewScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CvPreviewScreen({super.key, required this.userData});

  @override
  State<CvPreviewScreen> createState() => _CvPreviewScreenState();
}

class _CvPreviewScreenState extends State<CvPreviewScreen> {
  final TransformationController _transformationController = TransformationController();
  int _selectedThemeIndex = 0; // Mặc định Ngọc Bích Cổ Điển

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitToScreen();
    });
  }

  void _fitToScreen() {
    if (!mounted) return;
    final screenWidth = MediaQuery.of(context).size.width;
    const paperWidth = 794.0; 
    const padding = 32.0;

    if (screenWidth < paperWidth + padding) {
      final scale = (screenWidth - padding) / paperWidth;
      _transformationController.value = Matrix4.identity()..scale(scale);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _showTemplatePicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Chọn Mẫu CV (20 Mẫu)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: cvTemplates.length,
                    itemBuilder: (context, index) {
                      final theme = cvTemplates[index];
                      final isSelected = index == _selectedThemeIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedThemeIndex = index);
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? theme.primaryAccent : Colors.grey.shade200,
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: theme.primaryAccent.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Preview thu nhỏ
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      if (theme.layout == CvLayoutType.sidebarLeft)
                                        Container(width: 30, color: theme.sidebarBg),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            if (theme.layout == CvLayoutType.topHeader)
                                              Container(height: 30, color: theme.sidebarBg),
                                            Expanded(child: Container(color: theme.mainBg)),
                                          ],
                                        ),
                                      ),
                                      if (theme.layout == CvLayoutType.sidebarRight)
                                        Container(width: 30, color: theme.sidebarBg),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  theme.name,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? theme.primaryAccent : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = cvTemplates[_selectedThemeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      appBar: AppBar(
        title: Text(
          theme.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Thu phóng vừa màn hình',
            icon: const Icon(Icons.fit_screen_rounded, color: Colors.white),
            onPressed: _fitToScreen,
          ),
          IconButton(
            tooltip: 'Lưu PDF (Sắp ra mắt)',
            icon: Icon(Icons.picture_as_pdf_outlined, color: theme.primaryAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng xuất PDF đang được phát triển.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTemplatePicker,
        backgroundColor: theme.primaryAccent,
        icon: const Icon(Icons.palette_outlined, color: Colors.white),
        label: const Text('Đổi Mẫu CV', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: InteractiveViewer(
        transformationController: _transformationController,
        boundaryMargin: const EdgeInsets.symmetric(horizontal: 100, vertical: 1000),
        minScale: 0.1,
        maxScale: 3.0,
        constrained: false,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: _CvA4Paper(
            child: _buildLayout(theme),
          ),
        ),
      ),
    );
  }

  // --- ENGINE CHÍNH: XÂY DỰNG LAYOUT DỰA TRÊN THEME ---

  Widget _buildLayout(CvTheme theme) {
    switch (theme.layout) {
      case CvLayoutType.sidebarLeft:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(theme, 260),
              Expanded(child: _buildMainContent(theme)),
            ],
          ),
        );
      case CvLayoutType.sidebarRight:
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMainContent(theme)),
              _buildSidebar(theme, 260),
            ],
          ),
        );
      case CvLayoutType.topHeader:
        return Column(
          children: [
            _buildTopHeader(theme),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopHeaderLeftCol(theme, 260),
                  Expanded(child: _buildMainContent(theme, isTopHeader: true)),
                ],
              ),
            ),
          ],
        );
      case CvLayoutType.minimal:
        return _buildMinimal(theme);
    }
  }

  // --- CÁC THÀNH PHẦN (COMPONENTS) ---

  Widget _buildSidebar(CvTheme theme, double width) {
    final userData = widget.userData;
    final avatar = (userData['avatarUrl'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();
    final address = (userData['address'] ?? userData['companyAddress'] ?? '').toString().trim();
    final dob = _formatDob(userData['dateOfBirth']);
    final skills = skillsFromUserData(userData);
    final languages = LanguageModel.listFromUserData(userData);

    return Container(
      width: width,
      color: theme.sidebarBg,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.primaryAccent, width: 3),
                image: avatar.isNotEmpty ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null,
              ),
              child: avatar.isEmpty ? Icon(Icons.person, size: 80, color: theme.sidebarText.withValues(alpha: 0.3)) : null,
            ),
          ),
          const SizedBox(height: 32),
          _sidebarTitle('THÔNG TIN LIÊN HỆ', theme),
          const SizedBox(height: 16),
          if (phone.isNotEmpty) _contactItem(Icons.phone, phone, theme),
          if (email.isNotEmpty) _contactItem(Icons.email, email, theme),
          if (dob.isNotEmpty) _contactItem(Icons.cake, dob, theme),
          if (address.isNotEmpty) _contactItem(Icons.location_on, address, theme),
          const SizedBox(height: 32),
          if (skills.isNotEmpty) ...[
            _sidebarTitle('KỸ NĂNG', theme),
            const SizedBox(height: 16),
            ...skills.map((s) => _skillItem(s, theme)),
          ],
          const SizedBox(height: 32),
          if (languages.isNotEmpty) ...[
            _sidebarTitle('NGOẠI NGỮ', theme),
            const SizedBox(height: 16),
            ...languages.map((l) => _languageItem(l, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildMainContent(CvTheme theme, {bool isTopHeader = false}) {
    final userData = widget.userData;
    final fullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final headline = (userData['headline'] ?? '').toString().trim();
    final intro = selfIntroductionFromUserData(userData);
    final experiences = WorkExperienceModel.listFromUserData(userData);
    final educations = EducationModel.listFromUserData(userData);
    final projects = ProjectModel.listFromUserData(userData);

    return Container(
      color: theme.mainBg,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTopHeader) ...[
            Text(
              fullName.isEmpty ? 'TÊN ỨNG VIÊN' : fullName.toUpperCase(),
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.mainText, letterSpacing: 1.5),
            ),
            if (headline.isNotEmpty)
              Text(
                headline.toUpperCase(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.primaryAccent, letterSpacing: 1.2),
              ),
            const SizedBox(height: 36),
          ],
          if (intro.isNotEmpty) ...[
            _mainSectionTitle('MỤC TIÊU NGHỀ NGHIỆP', Icons.track_changes, theme),
            Text(intro, style: TextStyle(fontSize: 14, color: theme.mainText, height: 1.6)),
            const SizedBox(height: 32),
          ],
          if (experiences.isNotEmpty) ...[
            _mainSectionTitle('KINH NGHIỆM', Icons.work, theme),
            ...experiences.map((e) => _timelineExperienceItem(e, theme)),
            const SizedBox(height: 16),
          ],
          if (educations.isNotEmpty) ...[
            _mainSectionTitle('HỌC VẤN', Icons.school, theme),
            ...educations.map((e) => _timelineEducationItem(e, theme)),
          ],
          if (projects.isNotEmpty) ...[
            _mainSectionTitle('DỰ ÁN', Icons.folder, theme),
            ...projects.map((p) => _timelineProjectItem(p, theme)),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader(CvTheme theme) {
    final userData = widget.userData;
    final fullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final headline = (userData['headline'] ?? '').toString().trim();
    final avatar = (userData['avatarUrl'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();

    return Container(
      color: theme.sidebarBg,
      padding: const EdgeInsets.all(40),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              image: avatar.isNotEmpty ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover) : null,
              color: Colors.white24,
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'TÊN ỨNG VIÊN' : fullName.toUpperCase(),
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: theme.sidebarText, letterSpacing: 2.0),
                ),
                if (headline.isNotEmpty)
                  Text(headline.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: theme.primaryAccent)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (phone.isNotEmpty) _contactHeaderItem(Icons.phone, phone, theme),
                    const SizedBox(width: 24),
                    if (email.isNotEmpty) _contactHeaderItem(Icons.email, email, theme),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeaderLeftCol(CvTheme theme, double width) {
    final userData = widget.userData;
    final skills = skillsFromUserData(userData);
    final languages = LanguageModel.listFromUserData(userData);
    final address = (userData['address'] ?? userData['companyAddress'] ?? '').toString().trim();
    final dob = _formatDob(userData['dateOfBirth']);

    return Container(
      width: width,
      color: theme.mainBg,
      padding: const EdgeInsets.fromLTRB(36, 40, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mainSectionTitle('THÔNG TIN', Icons.person, theme),
          if (dob.isNotEmpty) _contactMainItem('Ngày sinh', dob, theme),
          if (address.isNotEmpty) _contactMainItem('Địa chỉ', address, theme),
          const SizedBox(height: 32),
          if (skills.isNotEmpty) ...[
            _mainSectionTitle('KỸ NĂNG', Icons.star, theme),
            ...skills.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $s', style: TextStyle(fontSize: 14, color: theme.mainText, fontWeight: FontWeight.w600)),
                )),
          ],
          const SizedBox(height: 32),
          if (languages.isNotEmpty) ...[
            _mainSectionTitle('NGOẠI NGỮ', Icons.translate, theme),
            ...languages.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• ${l.language}', style: TextStyle(fontSize: 14, color: theme.mainText, fontWeight: FontWeight.w600)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimal(CvTheme theme) {
    final userData = widget.userData;
    final fullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final headline = (userData['headline'] ?? '').toString().trim();
    final phone = (userData['phone'] ?? '').toString().trim();
    final email = (userData['email'] ?? '').toString().trim();
    final address = (userData['address'] ?? '').toString().trim();
    final intro = selfIntroductionFromUserData(userData);
    final experiences = WorkExperienceModel.listFromUserData(userData);
    final educations = EducationModel.listFromUserData(userData);
    final skills = skillsFromUserData(userData);

    return Container(
      color: theme.mainBg,
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            fullName.toUpperCase(),
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.mainText),
          ),
          if (headline.isNotEmpty)
            Text(headline.toUpperCase(), style: TextStyle(fontSize: 16, color: theme.mutedText, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 13, color: theme.mainText)),
              if (phone.isNotEmpty && email.isNotEmpty) const Text('  |  '),
              if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 13, color: theme.mainText)),
              if (address.isNotEmpty) const Text('  |  '),
              if (address.isNotEmpty) Text(address, style: TextStyle(fontSize: 13, color: theme.mainText)),
            ],
          ),
          const SizedBox(height: 36),
          if (intro.isNotEmpty) ...[
            _minimalTitle('TÓM TẮT', theme),
            Text(intro, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: theme.mainText, height: 1.6)),
            const SizedBox(height: 32),
          ],
          if (experiences.isNotEmpty) ...[
            _minimalTitle('KINH NGHIỆM LÀM VIỆC', theme),
            ...experiences.map((e) => _minimalExperience(e, theme)),
            const SizedBox(height: 16),
          ],
          if (educations.isNotEmpty) ...[
            _minimalTitle('HỌC VẤN', theme),
            ...educations.map((e) => _minimalEducation(e, theme)),
            const SizedBox(height: 16),
          ],
          if (skills.isNotEmpty) ...[
            _minimalTitle('KỸ NĂNG CHUYÊN MÔN', theme),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: skills.map((s) => Chip(
                label: Text(s),
                backgroundColor: theme.sidebarBg,
                labelStyle: TextStyle(color: theme.mainText, fontSize: 13, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: BorderSide(color: theme.primaryAccent)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --- SUB WIDGETS ---

  Widget _sidebarTitle(String title, CvTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.sidebarText, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(width: 40, height: 3, color: theme.primaryAccent),
      ],
    );
  }

  Widget _contactItem(IconData icon, String text, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.primaryAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: theme.sidebarText, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _contactHeaderItem(IconData icon, String text, CvTheme theme) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.primaryAccent),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: theme.sidebarText, fontSize: 14)),
      ],
    );
  }

  Widget _contactMainItem(String label, String value, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: theme.mutedText))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 14, color: theme.mainText, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _skillItem(String skill, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(skill, style: TextStyle(color: theme.sidebarText, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) => Container(
              margin: const EdgeInsets.only(right: 6),
              width: 12, height: 12,
              decoration: BoxDecoration(shape: BoxShape.circle, color: index < 4 ? theme.primaryAccent : theme.sidebarText.withValues(alpha: 0.2)),
            )),
          ),
        ],
      ),
    );
  }

  Widget _languageItem(LanguageModel lang, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: theme.primaryAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(lang.language, style: TextStyle(color: theme.sidebarText, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _mainSectionTitle(String title, IconData icon, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: theme.primaryAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 20, color: theme.primaryAccent),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.mainText, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 2, color: theme.primaryAccent.withValues(alpha: 0.2)),
        ],
      ),
    );
  }

  Widget _minimalTitle(String title, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 10),
      child: Column(
        children: [
          Text(title.toUpperCase(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: theme.mainText, letterSpacing: 2.0)),
          const SizedBox(height: 8),
          Container(height: 2, width: 60, color: theme.primaryAccent),
        ],
      ),
    );
  }

  Widget _timelineExperienceItem(WorkExperienceModel e, CvTheme theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _timelineIndicator(theme),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.position.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.mainText)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(e.company, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryAccent)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.mutedText)),
                      const SizedBox(width: 8),
                      Text(e.dateRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.mutedText, fontStyle: FontStyle.italic)),
                    ],
                  ),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(e.description.trim(), style: TextStyle(fontSize: 14, color: theme.mainText, height: 1.6)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineEducationItem(EducationModel e, CvTheme theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _timelineIndicator(theme),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.major.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.mainText)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(e.school, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryAccent)),
                      const SizedBox(width: 8),
                      Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: theme.mutedText)),
                      const SizedBox(width: 8),
                      Text(e.yearRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.mutedText, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineProjectItem(ProjectModel p, CvTheme theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _timelineIndicator(theme),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.mainText)),
                  const SizedBox(height: 4),
                  Text(p.dateRange, style: TextStyle(fontSize: 13, color: theme.mutedText, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineIndicator(CvTheme theme) {
    return Column(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.primaryAccent, width: 3), color: theme.mainBg)),
        Expanded(child: Container(width: 2, color: theme.primaryAccent.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(vertical: 4))),
      ],
    );
  }

  Widget _minimalExperience(WorkExperienceModel e, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.position.toUpperCase(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.mainText)),
              Text(e.dateRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.mutedText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(e.company, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryAccent)),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.description.trim(), style: TextStyle(fontSize: 14, color: theme.mainText, height: 1.6)),
          ],
        ],
      ),
    );
  }

  Widget _minimalEducation(EducationModel e, CvTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.school, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.mainText)),
              Text(e.yearRange, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.mutedText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(e.major, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.primaryAccent)),
        ],
      ),
    );
  }

  static String _formatDob(dynamic value) {
    try {
      if (value == null) return '';
      DateTime? dt;
      if (value is DateTime) dt = value;
      final type = value.runtimeType.toString();
      if (dt == null && type.contains('Timestamp')) {
        final dyn = value as dynamic;
        dt = dyn.toDate() as DateTime?;
      }
      if (dt == null) return '';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _CvA4Paper extends StatelessWidget {
  final Widget child;
  const _CvA4Paper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 794,
      constraints: const BoxConstraints(minHeight: 1123),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}
