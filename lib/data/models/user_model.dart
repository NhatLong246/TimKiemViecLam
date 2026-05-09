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
	final String? avatarUrl;
	final String? gender;
	final DateTime? dateOfBirth;
	// Employer-only fields
	final String? companyName;
	final String? companyAddress;
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
		this.avatarUrl,
		this.gender,
		this.dateOfBirth,
		this.companyName,
		this.companyAddress,
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
		String? avatarUrl,
		String? gender,
		DateTime? dateOfBirth,
		String? companyName,
		String? companyAddress,
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
			avatarUrl: avatarUrl ?? this.avatarUrl,
			gender: gender ?? this.gender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			companyName: companyName ?? this.companyName,
			companyAddress: companyAddress ?? this.companyAddress,
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
			'avatarUrl': avatarUrl,
			'gender': gender,
			'dateOfBirth': dateOfBirth,
			if (companyName != null) 'companyName': companyName,
			if (companyAddress != null) 'companyAddress': companyAddress,
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
			avatarUrl: map['avatarUrl']?.toString(),
			gender: map['gender']?.toString(),
			dateOfBirth: _parseDate(map['dateOfBirth']),
			companyName: map['companyName']?.toString(),
			companyAddress: map['companyAddress']?.toString(),
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

