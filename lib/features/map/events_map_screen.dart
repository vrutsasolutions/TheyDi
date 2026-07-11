import 'package:flutter/material.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
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

// Matches the price-pill bitmap height in createPriceMarker() (pill + stem +
// dot = 40px total), used to position the popup so its pointer touches the
// dot instead of covering it.
const double _kMarkerHeight = 40;
const double _kPopupWidth = 190;
// Fallback used only for the first frame before the real height is measured.
const double _kPopupHeightFallback = 150;

class _EventsMapScreenState extends State<EventsMapScreen> {
  EventModel? _selectedEvent;
  Offset? _markerScreenPosition;
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerCache = {};
  Set<Marker> _markers = {};

  // Key + measured height for the marker popup card. Since the card's
  // content (title/address) can wrap to a variable number of lines, we
  // measure its real rendered height after each frame instead of assuming
  // a fixed value, then reposition so the pointer always lands exactly on
  // the pin.
  final GlobalKey _popupKey = GlobalKey();
  double _popupHeight = _kPopupHeightFallback;

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
    _loadMarkers();
  }

  LatLng get _initialCenter {
    if (widget.userLat != null && widget.userLng != null) {
      return LatLng(widget.userLat!, widget.userLng!);
    }
    // Default to India center
    final eventsWithCoords = widget.events
        .where((e) => e.latitude != 0 && e.longitude != 0)
        .toList();
    if (eventsWithCoords.isNotEmpty) {
      return LatLng(
          eventsWithCoords.first.latitude, eventsWithCoords.first.longitude);
    }
    return const LatLng(20.5937, 78.9629); // India center
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
      // Reset to the fallback height for this new card's first frame, then
      // measure its real height once it's actually laid out.
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

      final icon = await _getMarker(event);
      markerSet.add(Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude, event.longitude),
        icon: icon,
        consumeTapEvents: true,
        onTap: () => _onMarkerTap(event),
      ));
    }

    if (!mounted) return;

    setState(() {
      _markers = markerSet;
    });
  }

  Future<BitmapDescriptor> _getMarker(EventModel event) async {
    final key = event.isFree ? "FREE" : "₹${event.price.toInt()}";

    if (_markerCache.containsKey(key)) {
      return _markerCache[key]!;
    }

    final icon = await createPriceMarker(
      key,
      event.isFree,
    );

    _markerCache[key] = icon;

    return icon;
  }

  // ── Smaller price marker with a location dot ──
  // Canvas is 56x40: the 56x26 pill sits on top (unchanged), and a thin
  // stem + small colored dot beneath it marks the exact coordinate, since
  // the marker's default anchor is bottom-center of the whole bitmap.
  Future<BitmapDescriptor> createPriceMarker(
    String text,
    bool isFree,
  ) async {
    const double width = 56;
    const double pillHeight = 26;
    const double stemHeight = 10;
    const double dotRadius = 4;
    const double height = pillHeight + stemHeight + dotRadius; // 40

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

    final pill = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 2, 52, 18),
      const Radius.circular(9),
    );

    canvas.drawRRect(pill.shift(const Offset(0.5, 1)), shadowPaint);

    canvas.drawRRect(pill, bgPaint);
    canvas.drawRRect(pill, borderPaint);

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

    tp.paint(
        canvas,
        Offset(
          (width - tp.width) / 2,
          (pillHeight - tp.height) / 2 - 1,
        ));

    // ── Stem + dot marking the exact pin location ──
    final centerX = width / 2;
    final stemStartY = pillHeight;
    final dotCenterY = height - dotRadius;

    final stemPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX, stemStartY),
      Offset(centerX, dotCenterY - dotRadius),
      stemPaint,
    );

    final dotShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(
        Offset(centerX, dotCenterY + 0.5), dotRadius, dotShadowPaint);

    final dotFillPaint = Paint()..color = accentColor;
    canvas.drawCircle(Offset(centerX, dotCenterY), dotRadius, dotFillPaint);

    final dotRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(centerX, dotCenterY), dotRadius, dotRingPaint);

    final picture = recorder.endRecording();

    final image = await picture.toImage(
      width.toInt(),
      height.toInt(),
    );

    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(
      bytes!.buffer.asUint8List(),
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

            // 👇 ADD THIS HERE
            onCameraMove: (_) async {
              if (_selectedEvent == null || _mapController == null) return;

              final point = await _mapController!.getScreenCoordinate(
                LatLng(
                  _selectedEvent!.latitude,
                  _selectedEvent!.longitude,
                ),
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

          // ── Dark overlay for contrast (rendered first so cards on top stay crisp) ──
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

          // ── Marker popup card, centered above the tapped pin with the
          // pointer triangle touching it (not overlapping). Horizontal
          // position is clamped so the card can't render off-screen near
          // the map edges. ──
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
              ),
            ),

          // ── Top bar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Back / List View toggle
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

                  // Event count badge
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
                onClose: () => setState(() => _selectedEvent = null),
              ),
            ),

          // ── No events on map hint ──
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

// ── Event preview card shown when marker is tapped ──
class _EventPreviewCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onClose;

  const _EventPreviewCard({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
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
            // Category thumbnail
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: TheyDiColors.gradientPrimary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  event.category.isNotEmpty ? event.category[0] : 'E',
                  style: TheyDiTextStyles.displayMedium
                      .copyWith(color: Colors.white, fontSize: 24),
                ),
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '${event.dateTime.day}/${event.dateTime.month} · ${_formatTime(event.dateTime)}',
                        style: TheyDiTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 11, color: TheyDiColors.textMuted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text('${event.venue}, ${event.city}',
                            style: TheyDiTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Price + close
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: TheyDiColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: TheyDiColors.divider),
                    ),
                    child: const Icon(Icons.close,
                        size: 12, color: TheyDiColors.textMuted),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: event.isFree
                        ? Colors.green.withValues(alpha: 0.15)
                        : TheyDiColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.isFree ? 'FREE' : '₹${event.price.toInt()}',
                    style: TheyDiTextStyles.caption.copyWith(
                      color: event.isFree ? Colors.green : TheyDiColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
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

class _MarkerPopupCard extends StatelessWidget {
  final EventModel event;

  const _MarkerPopupCard({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            width: 190,
            padding: const EdgeInsets.all(14),
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
                Text(
                  event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  event.isFree ? "FREE" : "₹${event.price.toInt()}",
                  style: TextStyle(
                    color: event.isFree ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
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
