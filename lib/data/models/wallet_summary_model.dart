/// Tóm tắt ví employer (đọc từ `users/{uid}`).
class WalletSummaryModel {
  final double walletBalance;
  final double totalDeposited;
  final double totalSpent;
  /// `null` = không giới hạn chi tiêu mỗi giao dịch.
  final double? walletSpendingLimit;
  final String? companyName;
  final String? momoWithdrawPhone;
  final String? phone;

  const WalletSummaryModel({
    this.walletBalance = 0,
    this.totalDeposited = 0,
    this.totalSpent = 0,
    this.walletSpendingLimit,
    this.companyName,
    this.momoWithdrawPhone,
    this.phone,
  });

  String get defaultMomoPhone =>
      momoWithdrawPhone ?? phone ?? '';

  bool get hasSpendingLimit =>
      walletSpendingLimit != null && walletSpendingLimit! > 0;

  factory WalletSummaryModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const WalletSummaryModel();
    final limit = (map['walletSpendingLimit'] as num?)?.toDouble();
    return WalletSummaryModel(
      walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0,
      totalDeposited: (map['totalDeposited'] as num?)?.toDouble() ?? 0,
      totalSpent: (map['totalSpent'] as num?)?.toDouble() ?? 0,
      walletSpendingLimit:
          limit != null && limit > 0 ? limit : null,
      companyName: map['companyName'] as String?,
      momoWithdrawPhone: map['momoWithdrawPhone'] as String?,
      phone: map['phone'] as String?,
    );
  }
}
