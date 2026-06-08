import 'dart:convert';
import 'package:flutter/material.dart';

class PersonalAlarmModel {
  final int id;
  final String title;
  final DateTime scheduledTime;
  final String? note;
  final bool isActive;

  PersonalAlarmModel({
    required this.id,
    required this.title,
    required this.scheduledTime,
    this.note,
    required this.isActive,
  });

  PersonalAlarmModel copyWith({
    int? id,
    String? title,
    DateTime? scheduledTime,
    String? note,
    bool? isActive,
  }) {
    return PersonalAlarmModel(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'note': note,
      'isActive': isActive,
    };
  }

  factory PersonalAlarmModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedTime;
    
    if (map.containsKey('scheduledTime')) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(map['scheduledTime']);
    } else {
      // Fallback cho dữ liệu cũ (TimeOfDay)
      final now = DateTime.now();
      final int hour = map['hour']?.toInt() ?? 0;
      final int minute = map['minute']?.toInt() ?? 0;
      parsedTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      // Nếu là báo thức cũ và giờ đã qua trong ngày, dời sang ngày mai
      if (parsedTime.isBefore(now)) {
        parsedTime = parsedTime.add(const Duration(days: 1));
      }
    }

    return PersonalAlarmModel(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      scheduledTime: parsedTime,
      note: map['note'],
      isActive: map['isActive'] ?? true,
    );
  }

  String toJson() => json.encode(toMap());

  factory PersonalAlarmModel.fromJson(String source) =>
      PersonalAlarmModel.fromMap(json.decode(source));
}
