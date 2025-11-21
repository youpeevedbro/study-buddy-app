import 'package:flutter/material.dart';

class Group {
  final String name;
  final DateTime date; // logical date (no time)
  final TimeOfDay startTime; // time only
  final TimeOfDay endTime; // time only
  final String creatorId;
  final String building;
  final String room; // room number/code

  const Group({
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.creatorId,
    required this.building,
    required this.room,
  });

  Group copyWith({
    String? name,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? creatorId,
    String? building,
    String? room,
  }) {
    return Group(
      name: name ?? this.name,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      creatorId: creatorId ?? this.creatorId,
      building: building ?? this.building,
      room: room ?? this.room,
    );
  }

  // Backend expects legacy string fields.
  Map<String, dynamic> toJson() {
    String mmddyyyy(DateTime d) =>
        "${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}";

    String hhmmAmPm(TimeOfDay tod) {
      final hour = tod.hourOfPeriod.toString().padLeft(2, '0');
      final minute = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }

    return {
      'name': name,
      'date': mmddyyyy(date),
      'starttime': hhmmAmPm(startTime),
      'endtime': hhmmAmPm(endTime),
      'creator_id': creatorId,
      'building': building,
      'room': room,
    };
  }
}

class JoinedGroup {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final String date;
  bool isExpanded;

  JoinedGroup({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.date,
    this.isExpanded = false
  });


  factory JoinedGroup.fromJson(Map<String, dynamic> json) {
    return JoinedGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      date: json['date'] as String,
    );
  }
}