import 'dart:convert';
import 'package:flutter/material.dart';

class PersonalAlarmModel {
  final int id;
  final String title;
  final TimeOfDay time;
  final bool isActive;

  PersonalAlarmModel({
    required this.id,
    required this.title,
    required this.time,
    required this.isActive,
  });

  PersonalAlarmModel copyWith({
    int? id,
    String? title,
    TimeOfDay? time,
    bool? isActive,
  }) {
    return PersonalAlarmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'hour': time.hour,
      'minute': time.minute,
      'isActive': isActive,
    };
  }

  factory PersonalAlarmModel.fromMap(Map<String, dynamic> map) {
    return PersonalAlarmModel(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      time: TimeOfDay(
        hour: map['hour']?.toInt() ?? 0,
        minute: map['minute']?.toInt() ?? 0,
      ),
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory PersonalAlarmModel.fromJson(String source) =>
      PersonalAlarmModel.fromMap(json.decode(source));
}
