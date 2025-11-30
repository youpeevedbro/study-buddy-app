import 'dart:async';
import 'package:flutter/material.dart';
import '../services/group_service.dart';

class ActivityBadge extends StatefulWidget {
  final double size;
  final Alignment alignment;

  const ActivityBadge({
    super.key,
    this.size = 22,
    this.alignment = Alignment.topRight,
  });

  @override
  State<ActivityBadge> createState() => _ActivityBadgeState();
}

class _ActivityBadgeState extends State<ActivityBadge> {
  final GroupService _service = const GroupService();
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final groups = await _service.listAllStudyGroups();
      final invites = await _service.listMyIncomingInvites();

      int incoming = 0;

      // Count join requests for groups I own
      for (final g in groups) {
        if (g.access == "owner") {
          final reqs = await _service.listIncomingRequests(g.id);
          incoming += reqs.length;
        }
      }

      // Count invites sent TO me
      incoming += invites.length;

      if (mounted) {
        setState(() {
          _count = incoming;
        });
      }
    } catch (e) {
      // ignore errors silently
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();

    return Align(
      alignment: widget.alignment,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          _count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
