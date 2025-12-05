import 'package:flutter/material.dart';
import 'grad_button.dart';

class RoomSlotCard extends StatelessWidget {
  final String roomLabel;
  final String timeRangeLabel;
  final bool isActiveNow;
  final int checkinsCount;
  final int reportCount;
  final bool canReportLocked;
  final bool canCheckInOut;
  final bool showCheckOut;
  final VoidCallback onReportLocked;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final Color accent;
  // Optional building name to show under header
  final String? buildingName;
  // Group mode: replaces actions with a single +Add button
  final bool groupMode;
  final VoidCallback? onAdd;

  static const double _actionHeight = 36.0;

  const RoomSlotCard({
    super.key,
    required this.roomLabel,
    required this.timeRangeLabel,
    required this.isActiveNow,
    required this.checkinsCount,
    required this.reportCount,
    required this.canReportLocked,
    required this.canCheckInOut,
    required this.showCheckOut,
    required this.onReportLocked,
    required this.onCheckIn,
    required this.onCheckOut,
    this.accent = const Color(0xFFE7E9CE),
    this.buildingName,
    this.groupMode = false,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasReports = reportCount > 0;
    final reportLabel = '$reportCount Locked Report${reportCount == 1 ? '' : 's'}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EB),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + status pill (match StudyGroup style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    roomLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActiveNow ? const Color(0xFF81C784) : const Color(0xFFE57373),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isActiveNow ? 'Active now' : 'Not active',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            if (buildingName != null && buildingName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.location_city, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      buildingName!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Removed text status; using pill above.
            const SizedBox(height: 5),

            // Time
            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Available:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeRangeLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Divider(height: 1, thickness: 0.7, color: Color(0xFFE2DDCF)),

            const SizedBox(height: 8),

            // Actions row
            if (!groupMode) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left block: Locked button and count below (expanded)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IgnorePointer(
                          ignoring: !canReportLocked,
                          child: Opacity(
                            opacity: canReportLocked ? 1.0 : 0.4,
                            child: SizedBox(
                              height: _actionHeight,
                              child: GradientButton(
                                borderRadius: BorderRadius.circular(16.0),
                                onPressed: onReportLocked,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.lock_outline, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Locked',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (hasReports) ...[
                          const SizedBox(height: 6),
                          Text(
                            reportLabel,
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Right block: Check-in / Check-out button (expanded)
                  Expanded(
                    child: IgnorePointer(
                      ignoring: !canCheckInOut,
                      child: Opacity(
                        opacity: canCheckInOut ? 1.0 : 0.4,
                        child: SizedBox(
                          height: _actionHeight,
                          child: GradientButton(
                            borderRadius: BorderRadius.circular(16.0),
                            onPressed: showCheckOut ? onCheckOut : onCheckIn,
                            child: Text(
                              showCheckOut ? 'Check-out' : 'Check-in',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Group mode: single +Add button centered
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: _actionHeight,
                      child: GradientButton(
                        borderRadius: BorderRadius.circular(16.0),
                        onPressed: onAdd,
                        child: const Text(
                          '+Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Footer
            if (!groupMode)
              Text(
                checkinsCount == 0
                    ? 'No one checked in yet'
                    : '$checkinsCount student${checkinsCount == 1 ? '' : 's'} checked in',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}