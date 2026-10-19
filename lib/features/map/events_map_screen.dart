import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;

import '../../../core/theme/app_theme.dart';
import 'package:theydi/features/events/models/event_model.dart';

class EventsMapScreen extends StatefulWidget {
  final List<EventModel> events;
  final double? userLat;
  final double? userLng;

  const EventsMapScreen({
    super.key,
    required this.events,
    this.userLat,
    this.userLng,
  });

  @override
  State<EventsMapScreen> createState() => _EventsMapScreenState();
}

const double _kMarkerHeight = 40;
const double _kPopupWidth = 190;
const double _kPopupHeightFallback = 150;

// Pink color consistent with list-view women-led badges
const Color _kFemaleHostPink = Color.fromARGB(255, 255, 29, 162);

class _EventsMapScreenState extends State<EventsMapScreen> {
  EventModel? _selectedEvent;
  Offset? _markerScreenPosition;
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerCache = {};
  Set<Marker> _markers = {};

  final GlobalKey _popupKey = GlobalKey();
  double _popupHeight = _kPopupHeightFallback;

  // eventId → 'Social' | 'Professional' | ''
  // Populated once in initState from a single batched Firestore fetch.
  final Map<String, String> _audienceMap = {};

  // eventId → true if host gender is 'female'
  final Map<String, bool> _womenLedMap = {};

  void _measurePopupAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _popupKey.currentContext?.findRenderObject() as RenderBox?;
      final measured = renderBox?.size.height;
      if (measured != null && measured > 0 && measured != _popupHeight) {
        setState(() => _popupHeight = measured);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAudiences();
    _loadHostGenders();
    _loadMarkers();
  }

  // ── Batch-fetch eventAudience for every event in one go ──────────────────
  // Events were written with 'eventAudience' by create_event_screen.dart.
  // Events created before that field existed get an empty string (badge hidden).
  Future<void> _loadAudiences() async {
    final ids = widget.events.map((e) => e.id).where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return;

    // Firestore 'in' clause supports max 30 items per call; chunk if needed.
    const chunkSize = 30;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize).toList();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('events')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        final updates = <String, String>{};
        for (final doc in snap.docs) {
          updates[doc.id] =
              (doc.data()['eventAudience'] as String? ?? '').trim();
        }
        if (mounted) setState(() => _audienceMap.addAll(updates));
      } catch (_) {
        // Non-fatal — badges simply won't show if fetch fails.
      }
    }
  }

  // ── Batch-fetch host genders to determine women-led events ────────────────
  // Follows the same pattern used in list-view cards: read users/{creatorUid}.gender
  Future<void> _loadHostGenders() async {
    // Collect unique creator UIDs
    final creatorUids = <String>{};
    final eventsByCreator = <String, List<String>>{}; // creatorUid → [eventId]
    for (final event in widget.events) {
      if (event.creatorUid.isNotEmpty) {
        creatorUids.add(event.creatorUid);
        eventsByCreator
            .putIfAbsent(event.creatorUid, () => [])
            .add(event.id);
      }
    }
    if (creatorUids.isEmpty) return;

    final uidList = creatorUids.toList();
    const chunkSize = 30;
    for (var i = 0; i < uidList.length; i += chunkSize) {
      final chunk = uidList.skip(i).take(chunkSize).toList();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        final updates = <String, bool>{};
        for (final doc in snap.docs) {
          final gender =
              (doc.data()['gender'] as String? ?? '').trim().toLowerCase();
          final isFemale = gender == 'female';
          // Mark all events created by this host
          final eventIds = eventsByCreator[doc.id] ?? [];
          for (final eid in eventIds) {
            updates[eid] = isFemale;
          }
        }
        if (mounted) {
          setState(() => _womenLedMap.addAll(updates));
          // Rebuild markers now that we know women-led status
          _loadMarkers();
        }
      } catch (_) {
        // Non-fatal — women-led badges simply won't show if fetch fails.
      }
    }
  }

  LatLng get _initialCenter {
    if (widget.userLat != null && widget.userLng != null) {
      return LatLng(widget.userLat!, widget.userLng!);
    }
    final eventsWithCoords = widget.events
        .where((e) => e.latitude != 0 && e.longitude != 0)
        .toList();
    if (eventsWithCoords.isNotEmpty) {
      return LatLng(
          eventsWithCoords.first.latitude, eventsWithCoords.first.longitude);
    }
    return const LatLng(20.5937, 78.9629);
  }

  Future<void> _onMarkerTap(EventModel event) async {
    if (_mapController == null) return;

    final screenPoint = await _mapController!.getScreenCoordinate(
      LatLng(event.latitude, event.longitude),
    );

    setState(() {
      _selectedEvent = event;
      _markerScreenPosition = Offset(
        screenPoint.x.toDouble(),
        screenPoint.y.toDouble(),
      );
      _popupHeight = _kPopupHeightFallback;
    });
    _measurePopupAfterFrame();

    _mapController!.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(event.latitude, event.longitude),
      ),
    );
  }

  Future<void> _loadMarkers() async {
    final Set<Marker> markerSet = {};

    for (final event in widget.events) {
      if (event.latitude == 0 || event.longitude == 0) continue;

      final isWomenLed = _womenLedMap[event.id] ?? false;
      final icon = await _getMarker(event, isWomenLed);
      markerSet.add(Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude, event.longitude),
        icon: icon,
        anchor: const Offset(0.5, 0.9),
        consumeTapEvents: true,
        onTap: () => _onMarkerTap(event),
      ));
    }

    if (!mounted) return;
    setState(() => _markers = markerSet);
  }

  Future<BitmapDescriptor> _getMarker(EventModel event, bool isWomenLed) async {
    final priceLabel = event.isFree ? "FREE" : "₹${event.price.toInt()}";
    final key = '${priceLabel}_${isWomenLed ? "W" : "N"}';
    if (_markerCache.containsKey(key)) return _markerCache[key]!;
    final icon = await createPriceMarker(priceLabel, event.isFree, isWomenLed);
    _markerCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> createPriceMarker(
      String text, bool isFree, bool isWomenLed) async {
    // Wider marker when women-led indicator needs to show
    final double width = isWomenLed ? 80 : 56;
    const double pillHeight = 26;
    const double stemHeight = 10;
    const double dotRadius = 4;
    const double height = pillHeight + stemHeight + dotRadius;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final accentColor =
        isFree ? const Color(0xff2ECC71) : const Color(0xffFF4D6D);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final bgPaint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final pillWidth = width - 4;
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 2, pillWidth, 18),
      const Radius.circular(9),
    );

    canvas.drawRRect(pill.shift(const Offset(0.5, 1)), shadowPaint);
    canvas.drawRRect(pill, bgPaint);
    canvas.drawRRect(pill, borderPaint);

    if (isWomenLed) {
      // Draw price text on the left portion
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: text.length > 5 ? 7.5 : 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      // Position price text in left half
      final priceAreaWidth = width * 0.55;
      tp.paint(canvas,
          Offset((priceAreaWidth - tp.width) / 2, (pillHeight - tp.height) / 2 - 1));

      // Draw small pink ♀ badge on the right portion
      final femaleX = priceAreaWidth + 1;
      final femaleWidth = pillWidth - priceAreaWidth + 1;
      final femaleRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(femaleX, 4, femaleWidth, 14),
        const Radius.circular(7),
      );
      canvas.drawRRect(
          femaleRect, Paint()..color = _kFemaleHostPink.withValues(alpha: 0.18));
      canvas.drawRRect(
          femaleRect,
          Paint()
            ..color = _kFemaleHostPink.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);

      final ftp = TextPainter(
        text: const TextSpan(
          text: '♀',
          style: TextStyle(
            color: _kFemaleHostPink,
            fontWeight: FontWeight.bold,
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      ftp.layout();
      ftp.paint(canvas,
          Offset(femaleX + (femaleWidth - ftp.width) / 2, 4 + (14 - ftp.height) / 2));
    } else {
      // Standard: price text centered
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: text.length > 5 ? 8 : 9.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas,
          Offset((width - tp.width) / 2, (pillHeight - tp.height) / 2 - 1));
    }

    // Stem + dot
    final centerX = width / 2;
    final stemStartY = pillHeight;
    final dotCenterY = height - dotRadius;

    final stemColor = isWomenLed ? _kFemaleHostPink : accentColor;

    final stemPaint = Paint()
      ..color = stemColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(centerX, stemStartY),
        Offset(centerX, dotCenterY - dotRadius), stemPaint);

    final dotShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(
        Offset(centerX, dotCenterY + 0.5), dotRadius, dotShadowPaint);

    final dotFillPaint = Paint()..color = stemColor;
    canvas.drawCircle(Offset(centerX, dotCenterY), dotRadius, dotFillPaint);

    final dotRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(centerX, dotCenterY), dotRadius, dotRingPaint);

    final picture = recorder.endRecording();
    final image =
        await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      width: width,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsWithCoords = widget.events
        .where((e) => e.latitude != 0 && e.longitude != 0)
        .toList();

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCenter,
              zoom: widget.userLat != null ? 12 : 5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (_) {
              setState(() {
                _selectedEvent = null;
                _markerScreenPosition = null;
              });
            },
            onCameraMove: (_) async {
              if (_selectedEvent == null || _mapController == null) return;
              final point = await _mapController!.getScreenCoordinate(
                LatLng(_selectedEvent!.latitude, _selectedEvent!.longitude),
              );
              if (!mounted) return;
              setState(() {
                _markerScreenPosition = Offset(
                  point.x.toDouble(),
                  point.y.toDouble(),
                );
              });
            },
            myLocationEnabled: widget.userLat != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            markers: _markers,
          ),

          // ── Dark overlay ──
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0D0D14).withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.transparent,
                      const Color(0xFF0D0D14).withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── Marker popup card ──
          if (_selectedEvent != null && _markerScreenPosition != null)
            Positioned(
              left: (_markerScreenPosition!.dx - _kPopupWidth / 2).clamp(
                8.0,
                MediaQuery.of(context).size.width - _kPopupWidth - 8.0,
              ),
              top: _markerScreenPosition!.dy - _kMarkerHeight - _popupHeight,
              child: _MarkerPopupCard(
                key: _popupKey,
                event: _selectedEvent!,
                audience: _audienceMap[_selectedEvent!.id] ?? '',
                isWomenLed: _womenLedMap[_selectedEvent!.id] ?? false,
              ),
            ),

          // ── Top bar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0D14).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TheyDiColors.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.list_outlined,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text('List View',
                              style: TheyDiTextStyles.caption
                                  .copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D14).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TheyDiColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.place_outlined,
                            color: TheyDiColors.primary, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          '${eventsWithCoords.length} events',
                          style: TheyDiTextStyles.caption
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom event preview card ──
          if (_selectedEvent != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: _EventPreviewCard(
                event: _selectedEvent!,
                audience: _audienceMap[_selectedEvent!.id] ?? '',
                isWomenLed: _womenLedMap[_selectedEvent!.id] ?? false,
                onClose: () => setState(() => _selectedEvent = null),
              ),
            ),

          // ── No events hint ──
          if (eventsWithCoords.isEmpty)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D14).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TheyDiColors.divider),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_off_outlined,
                        color: TheyDiColors.textMuted, size: 40),
                    const SizedBox(height: 8),
                    Text('No events with location data',
                        style: TheyDiTextStyles.bodySmall
                            .copyWith(color: TheyDiColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Events need a pinned location to show on map',
                        style: TheyDiTextStyles.caption
                            .copyWith(color: TheyDiColors.textMuted),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared audience badge widget ─────────────────────────────────────────────
// Shows "Social" (green) or "Professional" (blue). Hidden when audience is ''.
class _AudienceBadge extends StatelessWidget {
  final String audience;
  const _AudienceBadge({required this.audience});

  @override
  Widget build(BuildContext context) {
    if (audience.isEmpty) return const SizedBox.shrink();
    final isPro = audience == 'Professional';
    final color = isPro ? Colors.blue : const Color(0xff2ECC71);
    final icon = isPro ? Icons.work_outline : Icons.celebration_outlined;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          audience,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

// ── Women-led badge widget ──────────────────────────────────────────────────
// Pink pill with ♀ symbol, consistent with list-view women-led badges.
class _WomenLedBadge extends StatelessWidget {
  const _WomenLedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kFemaleHostPink.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _kFemaleHostPink.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '♀',
          style: TextStyle(
            color: _kFemaleHostPink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          'Women-led',
          style: TextStyle(
            color: _kFemaleHostPink,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}

// ── Bottom selected-event card ───────────────────────────────────────────────
class _EventPreviewCard extends StatelessWidget {
  final EventModel event;
  final String audience;
  final bool isWomenLed;
  final VoidCallback onClose;

  const _EventPreviewCard({
    required this.event,
    required this.audience,
    required this.isWomenLed,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final images = event.allImages;
    final hasImage = images.isNotEmpty && images.first.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/event/${event.id}', extra: event),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: TheyDiColors.cardLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TheyDiColors.divider, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Event image thumbnail (replaces category initial)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 70,
                height: 70,
                child: hasImage
                    ? Image.network(
                        images.first,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _CategoryPlaceholder(category: event.category);
                        },
                        errorBuilder: (_, __, ___) =>
                            _CategoryPlaceholder(category: event.category),
                      )
                    : _CategoryPlaceholder(category: event.category),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title,
                      style: TheyDiTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  // Badges row: audience + price + women-led
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      _AudienceBadge(audience: audience),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isFree
                              ? Colors.green.withValues(alpha: 0.13)
                              : TheyDiColors.primary.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                          style: TextStyle(
                            color: event.isFree
                                ? Colors.green
                                : TheyDiColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isWomenLed) const _WomenLedBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      '${event.dateTime.day}/${event.dateTime.month} · ${_formatTime(event.dateTime)}',
                      style: TheyDiTextStyles.caption,
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text('${event.venue}, ${event.city}',
                          style: TheyDiTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  // Attendees, duration, spots left
                  Row(children: [
                    const Icon(Icons.people_outline,
                        size: 11, color: TheyDiColors.textMuted),
                    const SizedBox(width: 3),
                    Text(
                      '${event.currentAttendees} going',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: TheyDiColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                    if (event.durationHours > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.timer_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '${event.durationHours} hrs',
                        style: TheyDiTextStyles.caption.copyWith(
                          color: TheyDiColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      event.isFull
                          ? 'Full'
                          : '${event.spotsLeft} spots left',
                      style: TheyDiTextStyles.caption.copyWith(
                        color: event.spotsLeft < 5
                            ? TheyDiColors.error
                            : const Color(0xff2ECC71),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Close button only (price moved to info column)
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: TheyDiColors.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: TheyDiColors.divider),
                ),
                child: const Icon(Icons.close,
                    size: 13, color: TheyDiColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

// ── Category placeholder (fallback when event has no image) ─────────────────
class _CategoryPlaceholder extends StatelessWidget {
  final String category;
  const _CategoryPlaceholder({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: TheyDiColors.gradientPrimary,
      ),
      child: Center(
        child: Text(
          category.isNotEmpty ? category[0] : 'E',
          style: TheyDiTextStyles.displayMedium
              .copyWith(color: Colors.white, fontSize: 24),
        ),
      ),
    );
  }
}

// ── Map marker popup card ────────────────────────────────────────────────────
class _MarkerPopupCard extends StatelessWidget {
  final EventModel event;
  final String audience;
  final bool isWomenLed;

  const _MarkerPopupCard({
    super.key,
    required this.event,
    required this.audience,
    required this.isWomenLed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            width: _kPopupWidth,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  color: Colors.black.withValues(alpha: .18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Badges: audience + price + women-led
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    _AudienceBadge(audience: audience),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: event.isFree
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                        style: TextStyle(
                          color: event.isFree ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (isWomenLed) const _WomenLedBadge(),
                  ],
                ),
              ],
            ),
          ),
          // Pointer triangle
          CustomPaint(
            size: const Size(20, 12),
            painter: _TrianglePainter(),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawShadow(path, Colors.black26, 3, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}