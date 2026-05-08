class BankAccountModel {
  final String id;
  final String accountNumber;
  final String accountHolderName;
  final String bankName;
  final String shortName;
  final String bankCode;
  final String bin;
  final String logo;
  BankAccountModel({
    required this.id,
    required this.accountNumber,
    required this.accountHolderName,
    required this.bankName,
    required this.shortName,
    required this.bankCode,
    required this.bin,
    required this.logo,
  });
  factory BankAccountModel.fromMap(String id, Map<String, dynamic> map) {
    return BankAccountModel(
      id: id,
      accountNumber: map['accountNumber'] ?? '',
      accountHolderName: map['accountHolderName'] ?? '',
      bankName: map['bankName'] ?? '',
      shortName: map['shortName'] ?? '',
      bankCode: map['bankCode'] ?? '',
      bin: map['bin'] ?? '',
      logo: map['logo'] ?? '',
    );
  }
  Map<String, dynamic> toMap() {
    return {
      'accountNumber': accountNumber,
      'accountHolderName': accountHolderName,
      'bankName': bankName,
      'shortName': shortName,
      'bankCode': bankCode,
      'bin': bin,
      'logo': logo,
      'createdAt': DateTime.now(),
    };
  }
}