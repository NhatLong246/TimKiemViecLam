// Danh mục công việc dùng chung toàn app (Part-time / Full-time).

const Map<String, String> kCategoryLabels = {
  'all': 'Tất cả',
  // Part-time / dịch vụ ngắn hạn
  'boc_vac': 'Bốc vác',
  'lau_don': 'Lau dọn',
  'bung_be': 'Bưng bê',
  'phuc_vu': 'Phục vụ',
  'pha_che': 'Pha chế',
  'tiep_thi': 'Tiếp thị',
  'van_chuyen': 'Vận chuyển',
  'bao_ve': 'Bảo vệ',
  // Full-time / văn phòng & chuyên môn
  'ban_hang': 'Bán hàng',
  'cskh': 'Chăm sóc khách hàng',
  'marketing': 'Marketing / Truyền thông',
  'ke_toan': 'Kế toán / Tài chính',
  'hanh_chinh': 'Hành chính văn phòng',
  'nhan_su': 'Nhân sự',
  'it': 'CNTT / Lập trình',
  'ky_thuat': 'Kỹ thuật / Kỹ sư',
  'thiet_ke': 'Thiết kế / Sáng tạo',
  'du_lieu': 'Phân tích dữ liệu',
  'giao_duc': 'Giáo dục / Gia sư',
  'y_te': 'Y tế / Chăm sóc sức khỏe',
  'khach_san': 'Khách sạn / Du lịch',
  'nha_hang': 'Nhà hàng / F&B',
  'kho_van': 'Kho vận / Logistics',
  'tai_xe': 'Lái xe / Tài xế',
  'san_xuat': 'Sản xuất / Vận hành',
  'xay_dung': 'Xây dựng',
  'luat': 'Pháp lý',
  'ngan_hang': 'Ngân hàng / Bảo hiểm',
  'dich_vu': 'Dịch vụ chuyên nghiệp',
  'other': 'Khác',
};

const Map<String, String> kCategoryIcons = {
  'boc_vac': '🏋️',
  'lau_don': '🧹',
  'bung_be': '🍽️',
  'phuc_vu': '👔',
  'pha_che': '☕',
  'tiep_thi': '📢',
  'van_chuyen': '🚚',
  'bao_ve': '🛡️',
  'ban_hang': '🛒',
  'cskh': '🎧',
  'marketing': '📣',
  'ke_toan': '📊',
  'hanh_chinh': '📋',
  'nhan_su': '👥',
  'it': '💻',
  'ky_thuat': '⚙️',
  'thiet_ke': '🎨',
  'du_lieu': '📈',
  'giao_duc': '📚',
  'y_te': '🏥',
  'khach_san': '🏨',
  'nha_hang': '🍽️',
  'kho_van': '📦',
  'tai_xe': '🚗',
  'san_xuat': '🏭',
  'xay_dung': '🏗️',
  'luat': '⚖️',
  'ngan_hang': '🏦',
  'dich_vu': '💼',
  'other': '💼',
};

/// Danh mục khi đăng Part-time (việc ngắn hạn, dịch vụ).
const List<Map<String, String>> kPartTimeCategoryOptions = [
  {'value': 'boc_vac', 'label': 'Bốc vác'},
  {'value': 'lau_don', 'label': 'Lau dọn'},
  {'value': 'bung_be', 'label': 'Bưng bê'},
  {'value': 'phuc_vu', 'label': 'Phục vụ'},
  {'value': 'pha_che', 'label': 'Pha chế'},
  {'value': 'tiep_thi', 'label': 'Tiếp thị'},
  {'value': 'van_chuyen', 'label': 'Vận chuyển'},
  {'value': 'bao_ve', 'label': 'Bảo vệ'},
  {'value': 'other', 'label': 'Khác'},
];

/// Danh mục khi đăng Full-time (tuyển dụng dài hạn).
const List<Map<String, String>> kFullTimeCategoryOptions = [
  {'value': 'ban_hang', 'label': 'Bán hàng'},
  {'value': 'cskh', 'label': 'Chăm sóc khách hàng'},
  {'value': 'marketing', 'label': 'Marketing / Truyền thông'},
  {'value': 'ke_toan', 'label': 'Kế toán / Tài chính'},
  {'value': 'hanh_chinh', 'label': 'Hành chính văn phòng'},
  {'value': 'nhan_su', 'label': 'Nhân sự'},
  {'value': 'it', 'label': 'CNTT / Lập trình'},
  {'value': 'ky_thuat', 'label': 'Kỹ thuật / Kỹ sư'},
  {'value': 'thiet_ke', 'label': 'Thiết kế / Sáng tạo'},
  {'value': 'du_lieu', 'label': 'Phân tích dữ liệu'},
  {'value': 'giao_duc', 'label': 'Giáo dục / Gia sư'},
  {'value': 'y_te', 'label': 'Y tế / Chăm sóc sức khỏe'},
  {'value': 'khach_san', 'label': 'Khách sạn / Du lịch'},
  {'value': 'nha_hang', 'label': 'Nhà hàng / F&B'},
  {'value': 'phuc_vu', 'label': 'Phục vụ'},
  {'value': 'pha_che', 'label': 'Pha chế / Barista'},
  {'value': 'kho_van', 'label': 'Kho vận / Logistics'},
  {'value': 'van_chuyen', 'label': 'Vận chuyển / Giao hàng'},
  {'value': 'tai_xe', 'label': 'Lái xe / Tài xế'},
  {'value': 'san_xuat', 'label': 'Sản xuất / Vận hành'},
  {'value': 'xay_dung', 'label': 'Xây dựng'},
  {'value': 'tiep_thi', 'label': 'Tiếp thị / PG'},
  {'value': 'bao_ve', 'label': 'Bảo vệ'},
  {'value': 'luat', 'label': 'Pháp lý'},
  {'value': 'ngan_hang', 'label': 'Ngân hàng / Bảo hiểm'},
  {'value': 'lau_don', 'label': 'Vệ sinh / Housekeeping'},
  {'value': 'dich_vu', 'label': 'Dịch vụ chuyên nghiệp'},
  {'value': 'other', 'label': 'Khác'},
];

String categoryLabel(String category) =>
    kCategoryLabels[category] ?? category;

/// Đảm bảo dropdown luôn có giá trị đang chọn (khi sửa bài cũ).
List<Map<String, String>> categoryOptionsFor({
  required bool isFullTime,
  required String selected,
}) {
  final base =
      isFullTime ? kFullTimeCategoryOptions : kPartTimeCategoryOptions;
  if (base.any((c) => c['value'] == selected)) return base;
  return [
    {'value': selected, 'label': categoryLabel(selected)},
    ...base,
  ];
}
