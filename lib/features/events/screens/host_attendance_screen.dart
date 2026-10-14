// ─────────────────────────────────────────────────────────────────────────────
// HostAttendanceScreen — Shows which attendees checked in and who didn't
//
// Route args (via GoRouter extra map):
//   eventId    : String
//   eventTitle : String
//
// Data source:
//   • events/{eventId}/checkIns/ — all registered attendees with check-in status
//   • users/{uid} — attendee profile (name, photo)
//
// Features:
//   • Real-time stream of check-in status
//   • Two sections: "Checked In" (green) and "Not Yet Arrived" (grey)
//   • Shows attendee name, photo, booking ref, and check-in time
//   • Counter summary at top
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class HostAttendanceScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const HostAttendanceScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance', style: TheyDiTextStyles.headlineMedium),
            Text(
              eventTitle,
              style: TheyDiTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .doc(eventId)
            .collection('checkIns')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: TheyDiColors.primary),
            );
          }

          if (snapshot.hasError) {
            debugPrint('[HostAttendance] Error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        color: TheyDiColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Could not load attendance data.',
                      style: TheyDiTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TheyDiColors.card,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        '${snapshot.error}',
                        style: TheyDiTextStyles.caption.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline,
                        color: TheyDiColors.textMuted, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'No attendees registered yet',
                      style: TheyDiTextStyles.headlineSmall
                          .copyWith(color: TheyDiColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Once attendees generate their QR tickets, they\'ll appear here.',
                      style: TheyDiTextStyles.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Split into checked-in and not-yet (client-side sort)
          final checkedIn = <QueryDocumentSnapshot>[];
          final notYet = <QueryDocumentSnapshot>[];
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['checkedIn'] == true) {
              checkedIn.add(doc);
            } else {
              notYet.add(doc);
            }
          }

          return Column(
            children: [
              // ── Summary bar ──
              _SummaryBar(
                checkedIn: checkedIn.length,
                total: docs.length,
                notArrived: notYet.length,
              ),
              const Divider(height: 1, color: TheyDiColors.divider),

              // ── List ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (checkedIn.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Checked In',
                        count: checkedIn.length,
                        color: TheyDiColors.success,
                        icon: Icons.check_circle_rounded,
                      ),
                      ...checkedIn.map(
                        (doc) => _AttendeeCard(
                          data: doc.data() as Map<String, dynamic>,
                          isCheckedIn: true,
                        ),
                      ),
                    ],
                    if (notYet.isNotEmpty) ...[
                      _SectionHeader(
                        title: 'Not Yet Arrived',
                        count: notYet.length,
                        color: TheyDiColors.textMuted,
                        icon: Icons.schedule_rounded,
                      ),
                      ...notYet.map(
                        (doc) => _AttendeeCard(
                          data: doc.data() as Map<String, dynamic>,
                          isCheckedIn: false,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary bar at top
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final int checkedIn;
  final int total;
  final int notArrived;

  const _SummaryBar({
    required this.checkedIn,
    required this.total,
    required this.notArrived,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (checkedIn / total * 100).round() : 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: TheyDiColors.card,
      child: Row(
        children: [
          // Circular progress
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: total > 0 ? checkedIn / total : 0,
                  strokeWidth: 5,
                  backgroundColor: TheyDiColors.divider,
                  valueColor: const AlwaysStoppedAnimation(TheyDiColors.success),
                ),
                Text(
                  '$percentage%',
                  style: TheyDiTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatChip(
                      label: 'Arrived',
                      count: checkedIn,
                      color: TheyDiColors.success,
                    ),
                    const SizedBox(width: 12),
                    _StatChip(
                      label: 'Pending',
                      count: notArrived,
                      color: TheyDiColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$total total registered',
                  style: TheyDiTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 300.ms);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TheyDiTextStyles.labelMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TheyDiTextStyles.headlineSmall.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TheyDiTextStyles.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendee card — fetches user profile on build
// ─────────────────────────────────────────────────────────────────────────────

class _AttendeeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isCheckedIn;

  const _AttendeeCard({
    required this.data,
    required this.isCheckedIn,
  });

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '';
    try {
      final date = (ts as Timestamp).toDate();
      return DateFormat('h:mm a').format(date);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendeeUid = data['attendeeUserId'] as String? ?? '';
    final bookingRef = data['bookingRef'] as String? ?? '';
    final checkedInAt = isCheckedIn ? _formatTimestamp(data['checkedInAt']) : '';
    final isFree = data['isFreeEvent'] == true;

    return FutureBuilder<DocumentSnapshot>(
      future: attendeeUid.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(attendeeUid)
              .get()
          : null,
      builder: (context, userSnap) {
        String name = 'Attendee';
        String? photoUrl;

        if (userSnap.hasData && userSnap.data!.exists) {
          final userData = userSnap.data!.data() as Map<String, dynamic>;
          name = userData['displayName'] as String? ??
              userData['name'] as String? ??
              userData['fullName'] as String? ??
              'Attendee';
          photoUrl = userData['profileImageUrl'] as String? ??
              userData['photoUrl'] as String?;
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCheckedIn
                  ? TheyDiColors.success.withValues(alpha: 0.2)
                  : TheyDiColors.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: _buildAvatar(name, photoUrl),
            title: Text(
              name,
              style: TheyDiTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bookingRef.isNotEmpty)
                  Text(
                    bookingRef,
                    style: TheyDiTextStyles.caption.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: TheyDiColors.textMuted,
                    ),
                  ),
                if (isFree)
                  Text(
                    'Free event',
                    style: TheyDiTextStyles.caption.copyWith(
                      color: TheyDiColors.info,
                    ),
                  ),
              ],
            ),
            trailing: isCheckedIn
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: TheyDiColors.success, size: 22),
                      if (checkedInAt.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          checkedInAt,
                          style: TheyDiTextStyles.caption.copyWith(
                            color: TheyDiColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  )
                : const Icon(Icons.schedule_rounded,
                    color: TheyDiColors.textMuted, size: 22),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, String? photoUrl) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 42,
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: isCheckedIn
            ? TheyDiColors.gradientPrimary
            : const LinearGradient(
                colors: [Color(0xFFD1D5DB), Color(0xFF9CA3AF)],
              ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: (photoUrl != null && photoUrl.isNotEmpty)
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16)),
              ),
            )
          : Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
            ),
    );
  }
}