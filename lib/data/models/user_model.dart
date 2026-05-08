import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
	final String id;
	final String firstName;
	final String lastName;
	final String username;
	final String email;
	final String phone;
	final String? avatarUrl;
	final String? gender;
	final DateTime? dateOfBirth;
	final DateTime? createdAt;
	final DateTime? updatedAt;

	const UserModel({
		required this.id,
		required this.firstName,
		required this.lastName,
		required this.username,
		required this.email,
		required this.phone,
		this.avatarUrl,
		this.gender,
		this.dateOfBirth,
		this.createdAt,
		this.updatedAt,
	});

	String get fullName => '$firstName $lastName'.trim();

	UserModel copyWith({
		String? id,
		String? firstName,
		String? lastName,
		String? username,
		String? email,
		String? phone,
		String? avatarUrl,
		String? gender,
		DateTime? dateOfBirth,
		DateTime? createdAt,
		DateTime? updatedAt,
	}) {
		return UserModel(
			id: id ?? this.id,
			firstName: firstName ?? this.firstName,
			lastName: lastName ?? this.lastName,
			username: username ?? this.username,
			email: email ?? this.email,
			phone: phone ?? this.phone,
			avatarUrl: avatarUrl ?? this.avatarUrl,
			gender: gender ?? this.gender,
			dateOfBirth: dateOfBirth ?? this.dateOfBirth,
			createdAt: createdAt ?? this.createdAt,
			updatedAt: updatedAt ?? this.updatedAt,
		);
	}

	Map<String, dynamic> toMap() {
		return <String, dynamic>{
			'id': id,
			'firstName': firstName,
			'lastName': lastName,
			'username': username,
			'email': email,
			'phone': phone,
			'avatarUrl': avatarUrl,
			'gender': gender,
			'dateOfBirth': dateOfBirth,
			'createdAt': createdAt ?? FieldValue.serverTimestamp(),
			'updatedAt': FieldValue.serverTimestamp(),
		};
	}

	factory UserModel.fromMap(Map<String, dynamic> map) {
		return UserModel(
			id: (map['id'] ?? map['uid'] ?? '').toString(),
			firstName: (map['firstName'] ?? '').toString(),
			lastName: (map['lastName'] ?? '').toString(),
			username: (map['username'] ?? '').toString(),
			email: (map['email'] ?? '').toString(),
			phone: (map['phone'] ?? '').toString(),
			avatarUrl: map['avatarUrl']?.toString(),
			gender: map['gender']?.toString(),
			dateOfBirth: _parseDate(map['dateOfBirth']),
			createdAt: _parseDate(map['createdAt']),
			updatedAt: _parseDate(map['updatedAt']),
		);
	}

	static DateTime? _parseDate(dynamic value) {
		if (value == null) {
			return null;
		}
		if (value is Timestamp) {
			return value.toDate();
		}
		if (value is DateTime) {
			return value;
		}
		if (value is String) {
			return DateTime.tryParse(value);
		}
		return null;
	}
}
