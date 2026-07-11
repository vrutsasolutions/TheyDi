import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/services/face_verification_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminVerificationScreen extends StatelessWidget {
  const AdminVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: TheyDiColors.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Verification Requests',
            style: TheyDiTextStyles.headlineMedium,
          ),
          bottom: TabBar(
            labelColor: TheyDiColors.primary,
            unselectedLabelColor: TheyDiColors.textMuted,
            indicatorColor: TheyDiColors.primary,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _RequestList(status: 'pending'),
            _RequestList(status: 'verified'),
            _RequestList(status: 'rejected'),
          ],
        ),
      ),
    );
  }
}

// ── Request List ──────────────────────────────────────────
class _RequestList extends StatelessWidget {
  final String status;
  const _RequestList({required this.status});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('verificationRequests')
          .where('status', isEqualTo: status)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: TheyDiColors.primary),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: TheyDiColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status requests',
                  style: TheyDiTextStyles.bodyMedium.copyWith(
                    color: TheyDiColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _RequestCard(data: data)
                .animate(delay: Duration(milliseconds: index * 50))
                .fade(duration: 300.ms)
                .slideY(begin: 0.1, end: 0);
          },
        );
      },
    );
  }
}

// ── Request Card ──────────────────────────────────────────
class _RequestCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const _RequestCard({required this.data});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _isLoading = false;

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    final success = await FaceVerificationService.approveVerification(
      userId: widget.data['userId'],
      userName: widget.data['userName'] ?? 'User',
    );
    if (mounted) {
      setState(() => _isLoading = false);
      _showSnack(
        success ? '✅ Approved!' : '❌ Failed. Try again.',
        success: success,
      );
    }
  }

  void _viewFullImage(BuildContext context, String url, String title) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 300,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    final success = await FaceVerificationService.rejectVerification(
      userId: widget.data['userId'],
      userName: widget.data['userName'] ?? 'User',
      reason: reason,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      _showSnack(
        success ? '❌ Rejected' : 'Failed. Try again.',
        success: success,
      );
    }
  }

  Future<String?> _showRejectDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: TheyDiColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Rejection Reason', style: TheyDiTextStyles.headlineMedium),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'e.g. Photo is blurry, face not visible...',
            hintStyle: TheyDiTextStyles.caption.copyWith(
              color: TheyDiColors.textMuted,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: TheyDiColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: TheyDiColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? TheyDiColors.primary : TheyDiColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending = widget.data['status'] == 'pending';
    final name = widget.data['userName'] ?? 'Unknown';
    final selfie = widget.data['selfieUrl'] ?? '';
    final live = widget.data['liveSelfieUrl'] ?? '';
    final reason = widget.data['rejectionReason'];
    final submitted = widget.data['submittedAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: TheyDiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TheyDiColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: TheyDiColors.gradientPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TheyDiTextStyles.headlineMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TheyDiTextStyles.labelLarge),
                      if (submitted != null)
                        Text(
                          _formatDate(submitted.toDate()),
                          style: TheyDiTextStyles.caption.copyWith(
                            color: TheyDiColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(
                      widget.data['status'],
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.data['status'].toString().toUpperCase(),
                    style: TheyDiTextStyles.caption.copyWith(
                      color: _statusColor(widget.data['status']),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Photos side by side ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile selfie
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Profile Selfie',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            _viewFullImage(context, selfie, 'Profile Selfie'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: selfie.isNotEmpty
                              ? Stack(
                                  children: [
                                    Image.network(selfie,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _photoPlaceholder()),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.zoom_in,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                )
                              : _photoPlaceholder(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Live selfie
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Live Capture',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            _viewFullImage(context, live, 'Live Capture'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: live.isNotEmpty
                              ? Stack(
                                  children: [
                                    Image.network(live,
                                        height: 160,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _photoPlaceholder()),
                                    Positioned(
                                      bottom: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.zoom_in,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                )
                              : _photoPlaceholder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rejection reason ──
          if (reason != null && reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TheyDiColors.error.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: TheyDiColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: TheyDiColors.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: $reason',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action buttons (pending only) ──
          if (isPending) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: TheyDiColors.primary,
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reject,
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TheyDiColors.error,
                              side: BorderSide(
                                color: TheyDiColors.error.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _approve,
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TheyDiColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: TheyDiColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: TheyDiColors.textMuted,
          size: 32,
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'verified':
        return TheyDiColors.primary;
      case 'rejected':
        return TheyDiColors.error;
      default:
        return TheyDiColors.warning;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
