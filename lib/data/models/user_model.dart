import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
	final String id;
	final String role; // "candidate" | "employer" | "admin"
	final String firstName;
	final String lastName;
	final String username;
	final String email;
	final String phone;
	final bool isVerified;
	final bool isActive;
	final String? currentSessionId;
	final String? avatarUrl;
	final String? avatarBase64; // ảnh đại diện dạng Base64 (thay thế Firebase Storage)
	final String? gender;
	final DateTime? dateOfBirth;
	final String? cccd;
	final String? cccdImageUrl;   // mặt trước CCCD
	final String? cccdBackImageUrl; // mặt sau CCCD
	// Employer-only fields
	final String? companyName;
	final String? companyAddress;
	final String? companyLogoUrl;
	final String? companyPhone;
	final String? companyWebsite;
	final String? companyTaxCode;
	final String? companySize;     // "1-9" | "10-49" | "50-199" | "200+"
	final String? businessType;   // "individual" | "company" | "cooperative"
	final String? companyDescription;
	final double walletBalance;
	final double totalSpent;
	// Candidate-only fields
	final double averageRating;
	final int totalJobsDone;
	final DateTime? createdAt;
	final DateTime? updatedAt;

	const UserModel({
		required this.id,
		required this.role,
		required this.firstName,
		required this.lastName,
		required this.username,
		required this.email,
		required this.phone,
		this.isVerified = false,
		this.isActive = true,
		this.currentSessionId,
		this.avatarUrl,
		this.avatarBase64,
		this.gender,
		this.dateOfBirth,
		this.cccd,
		this.cccdImageUrl,
		this.cccdBackImageUrl,
		this.companyName,
		this.companyAddress,
		this.companyLogoUrl,
		this.companyPhone,
		this.companyWebsite,
		this.companyTaxCode,
		this.companySize,
		this.businessType,
		this.companyDescription,
		this.walletBalance = 0.0,
		this.totalSpent = 0.0,
		this.averageRating = 0.0,
		this.totalJobsDone = 0,
		this.createdAt,
		this.updatedAt,
	});

	String get fullName => '$firstName $lastName'.trim();

	UserModel copyWith({
		String? id,
		String? role,
		String? firstName,
		String? lastName,
		String? username,
		String? email,
		String? phone,
		bool? isVerified,
		bool? isActive,
		String? currentSessionId,
		String? avatarUrl,
		String? avatarBase64,
		String? gender,
		DateTime? dateOfBirth,
		String? cccd,
		String? cccdImageUrl,
		String? cccdBackImageUrl,
		String? companyName,
		String? companyAddress,
		String? companyLogoUrl,
		String? companyPhone,
		String? companyWebsite,
		String? companyTaxCode,
		String? companySize,
		String? businessType,
		String? companyDescription,
		double? walletBalance,
		double? totalSpent,
		double? averageRating,
		int? totalJobsDone,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return UserModel(
			id: id ?? this.id,
			role: role ?? this.role,
			firstName: firstName ?? this.firstName,
			lastName: lastName ?? this.lastName,
			username: username ?? this.username,
			email: email ?? this.email,
			phone: phone ?? this.phone,
			isVerified: isVerified ?? this.isVerified,
			isActive: isActive ?? this.isActive,
			currentSessionId: currentSessionId ?? this.currentSessionId,
			avatarUrl: avatarUrl ?? this.avatarUrl,
			avatarBase64: avatarBase64 ?? this.avatarBase64,
			gender: gender ?? this.gender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			cccd: cccd ?? this.cccd,
			cccdImageUrl: cccdImageUrl ?? this.cccdImageUrl,
			cccdBackImageUrl: cccdBackImageUrl ?? this.cccdBackImageUrl,
			companyName: companyName ?? this.companyName,
			companyAddress: companyAddress ?? this.companyAddress,
			companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
			companyPhone: companyPhone ?? this.companyPhone,
			companyWebsite: companyWebsite ?? this.companyWebsite,
			companyTaxCode: companyTaxCode ?? this.companyTaxCode,
			companySize: companySize ?? this.companySize,
			businessType: businessType ?? this.businessType,
			companyDescription: companyDescription ?? this.companyDescription,
			walletBalance: walletBalance ?? this.walletBalance,
			totalSpent: totalSpent ?? this.totalSpent,
			averageRating: averageRating ?? this.averageRating,
			totalJobsDone: totalJobsDone ?? this.totalJobsDone,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	Map<String, dynamic> toMap() {
		return <String, dynamic>{
			'uid': id,
			'role': role,
			'firstName': firstName,
			'lastName': lastName,
			'username': username,
			'email': email,
			'phone': phone,
			'isVerified': isVerified,
			'isActive': isActive,
			if (currentSessionId != null) 'currentSessionId': currentSessionId,
			'avatarUrl': avatarUrl,
		if (avatarBase64 != null) 'avatarBase64': avatarBase64,
			'gender': gender,
			'dateOfBirth': dateOfBirth,
			if (cccd != null) 'cccd': cccd,
			if (cccdImageUrl != null) 'cccdImageUrl': cccdImageUrl,
			if (cccdBackImageUrl != null) 'cccdBackImageUrl': cccdBackImageUrl,
			if (companyName != null) 'companyName': companyName,
			if (companyAddress != null) 'companyAddress': companyAddress,
			if (companyLogoUrl != null) 'companyLogoUrl': companyLogoUrl,
			if (companyPhone != null) 'companyPhone': companyPhone,
			if (companyWebsite != null) 'companyWebsite': companyWebsite,
			if (companyTaxCode != null) 'companyTaxCode': companyTaxCode,
			if (companySize != null) 'companySize': companySize,
			if (businessType != null) 'businessType': businessType,
			if (companyDescription != null) 'companyDescription': companyDescription,
			'walletBalance': walletBalance,
			'totalSpent': totalSpent,
			'createdAt': createdAt ?? FieldValue.serverTimestamp(),
			'updatedAt': FieldValue.serverTimestamp(),
		};
	}

	factory UserModel.fromMap(Map<String, dynamic> map) {
		return UserModel(
			id: (map['uid'] ?? map['id'] ?? '').toString(),
			role: (map['role'] ?? 'candidate').toString(),
			firstName: (map['firstName'] ?? '').toString(),
			lastName: (map['lastName'] ?? '').toString(),
			username: (map['username'] ?? '').toString(),
			email: (map['email'] ?? '').toString(),
			phone: (map['phone'] ?? '').toString(),
			isVerified: (map['isVerified'] as bool?) ?? false,
			isActive: (map['isActive'] as bool?) ?? true,
			currentSessionId: map['currentSessionId']?.toString(),
			avatarUrl: map['avatarUrl']?.toString(),
		avatarBase64: map['avatarBase64']?.toString(),
			gender: map['gender']?.toString(),
			dateOfBirth: _parseDate(map['dateOfBirth']),
			cccd: map['cccd']?.toString(),
			cccdImageUrl: map['cccdImageUrl']?.toString(),
			cccdBackImageUrl: map['cccdBackImageUrl']?.toString(),
			companyName: map['companyName']?.toString(),
			companyAddress: map['companyAddress']?.toString(),
			companyLogoUrl: map['companyLogoUrl']?.toString(),
			companyPhone: map['companyPhone']?.toString(),
			companyWebsite: map['companyWebsite']?.toString(),
			companyTaxCode: map['companyTaxCode']?.toString(),
			companySize: map['companySize']?.toString(),
			businessType: map['businessType']?.toString(),
			companyDescription: map['companyDescription']?.toString(),
			walletBalance: (map['walletBalance'] as num?)?.toDouble() ?? 0.0,
			totalSpent: (map['totalSpent'] as num?)?.toDouble() ?? 0.0,
			averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
			totalJobsDone: (map['totalJobsDone'] as num?)?.toInt() ?? 0,
			createdAt: _parseDate(map['createdAt']),
			updatedAt: _parseDate(map['updatedAt']),
		);
	}

	static DateTime? _parseDate(dynamic value) {
		if (value == null) return null;
		if (value is Timestamp) return value.toDate();
		if (value is DateTime) return value;
		if (value is String) return DateTime.tryParse(value);
		return null;
	}
}

