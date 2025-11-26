import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class SelectedGroupFields {  //stores user's selections to create a group
  String? name;
  DateTime? date;
  String? building;
  String? roomNumber;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String? availabilitySlotDoc;

  SelectedGroupFields({
    this.name, 
    required this.date,
    this.building,
    this.roomNumber,
    this.startTime,
    this.endTime,
    this.availabilitySlotDoc
    });

    Map<String, dynamic> toJson() {
    String hhmm(TimeOfDay t) {
      final hour = t.hour.toString().padLeft(2, '0');
      final minute = t.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    String yyyymmdd(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    
    return {
      'name': name,
      'date': yyyymmdd(date!),
      'startTime': hhmm(startTime!),
      'endTime': hhmm(endTime!),
      'buildingCode': building,
      'roomNumber': roomNumber,
      'availabilitySlotDocument': availabilitySlotDoc 
    };
  }
}

class StudyGroupResponse {  //holds public or private response data for study group
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
  final List<String>? members;  //currently holds displayNames
  final String availabilitySlotDoc;
  bool isExpanded; // manages state of its expansion panel in studygroups.dart

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
    required this.availabilitySlotDoc,
    this.isExpanded = false
  });

  StudyGroupResponse copyWith({
    String? buildingCode,
    String? roomNumber,
    String? date,
    String? startTime,
    String? endTime,
    String? name,
    String? availabilitySlotDoc
  }) {
    return StudyGroupResponse(
      id: this.id,
      buildingCode: buildingCode ?? this.buildingCode,
      roomNumber: roomNumber ?? this.roomNumber,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      name: name ?? this.name,
      quantity: this.quantity,
      access: this.access,
      ownerID: this.ownerID,
      ownerHandle: this.ownerHandle,
      ownerDisplayName: this.ownerDisplayName,
      members: this.members,
      availabilitySlotDoc: availabilitySlotDoc ?? this.availabilitySlotDoc,
      isExpanded: this.isExpanded
    );
  }

  

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

  Map<String, dynamic> toJsonForName() {
    return {
      'name': name
    };
  }
}

class JoinedGroup {  //only holds data from the 'joinedStudyGroups' field in User document
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