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

class StudyGroupResponse {
  final String id;
  final String buildingCode;
  final String roomNumber;
  final String date;
  final String startTime;
  final String endTime;
  final String name;
  final int quantity;
  final String access; // 'owner', 'member', or 'public'
  final String ownerID;
  final String ownerHandle;
  final String ownerDisplayName;
  final List<String>? members;  
  final String availabilitySlotDoc;

  StudyGroupResponse({
    required this.id,
    required this.buildingCode,
    required this.roomNumber,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.name,
    required this.quantity,
    required this.access,
    required this.ownerID,
    required this.ownerHandle,
    required this.ownerDisplayName,
    this.members,
    required this.availabilitySlotDoc
  });

  factory StudyGroupResponse.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('members')) {
      final List<dynamic> list = json["members"];
      final List<String> memberslist = list.cast<String>();

      return StudyGroupResponse(
      id: json['id'] as String,
      buildingCode: json['buildingCode'] as String,
      roomNumber: json['roomNumber'] as String,
      date: json['date'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      access: json['access'] as String,
      ownerID: json['ownerID'] as String,
      ownerHandle: json['ownerHandle'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      members: memberslist,
      availabilitySlotDoc: json['availabilitySlotDocument'] as String,
    );
    }
    return StudyGroupResponse(    // does not include members field
      id: json['id'] as String,
      buildingCode: json['buildingCode'] as String,
      roomNumber: json['roomNumber'] as String,
      date: json['date'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      access: json['access'] as String,
      ownerID: json['ownerID'] as String,
      ownerHandle: json['ownerHandle'] as String,
      ownerDisplayName: json['ownerDisplayName'] as String,
      availabilitySlotDoc: json['availabilitySlotDocument'] as String,
    );
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