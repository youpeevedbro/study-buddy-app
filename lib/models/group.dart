import 'package:flutter/material.dart';

class Room {
  final String building;
  final String number;
  final String? floor;

  const Room({
    required this.building,
    required this.number,
    this.floor,
  });

  Room copyWith({String? building, String? number, String? floor}) {
    return Room(
      building: building ?? this.building,
      number: number ?? this.number,
      floor: floor ?? this.floor,
    );
  }

  Map<String, dynamic> toJson() => {
        'building': building,
        'number': number,
        if (floor != null) 'floor': floor,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        building: json['building'] as String? ?? '',
        number: json['number'] as String? ?? '',
        floor: json['floor'] as String?,
      );
}

class Group {
  final String name;
  final DateTime date; // logical date (no time)
  final DateTime startTime;
  final DateTime endTime;
  final int maxMembers;
  final String creatorId;
  final Room room;

  const Group({
    required this.name,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.maxMembers,
    required this.creatorId,
    required this.room,
  });

  Group copyWith({
    String? name,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    int? maxMembers,
    String? creatorId,
    Room? room,
  }) {
    return Group(
      name: name ?? this.name,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxMembers: maxMembers ?? this.maxMembers,
      creatorId: creatorId ?? this.creatorId,
      room: room ?? this.room,
    );
  }

  // Backend expects legacy string fields. Keep that here so UI stays stable.
  Map<String, dynamic> toJson() {
    String mmddyyyy(DateTime d) =>
        "${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}";

    String hhmmAmPm(TimeOfDay tod) {
      final hour = tod.hourOfPeriod.toString().padLeft(2, '0');
      final minute = tod.minute.toString().padLeft(2, '0');
      final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:$minute $period';
    }

    final startTod = TimeOfDay.fromDateTime(startTime);
    final endTod = TimeOfDay.fromDateTime(endTime);

    return {
      'name': name,
      'date': mmddyyyy(date),
      'starttime': hhmmAmPm(startTod),
      'endtime': hhmmAmPm(endTod),
      'max_members': maxMembers,
      'creator_id': creatorId,

      // New structured room object for future schema
      'room': room.toJson(),

      // Backward compatibility for current backend
      'location': room.floor == null || room.floor!.isEmpty
          ? '${room.building} - ${room.number}'
          : '${room.building} ${room.floor} - ${room.number}',
    };
  }
}
