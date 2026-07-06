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

class _EventsMapScreenState extends State<EventsMapScreen> {
  EventModel? _selectedEvent;
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerCache = {};
  Set<Marker> _markers = {};

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

  void _onMarkerTap(EventModel event) {
    setState(() => _selectedEvent = event);

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          event.latitude,
          event.longitude,
        ),
        14,
      ),
    );
  }

  Future<void> _loadMarkers() async {
    final Set<Marker> markerSet = {};
    if (widget.userLat != null && widget.userLng != null) {
      markerSet.add(
        Marker(
          markerId: const MarkerId("user"),
          position: LatLng(
            widget.userLat!,
            widget.userLng!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      );
    }

    for (final event in widget.events) {
      if (event.latitude == 0 || event.longitude == 0) continue;

      final icon = await createPriceMarker(
        event.isFree ? "FREE" : "₹${event.price.toInt()}",
        event.isFree,
      );

      markerSet.add(
        Marker(
          markerId: MarkerId(event.id),
          position: LatLng(
            event.latitude,
            event.longitude,
          ),
          icon: icon,
          infoWindow: InfoWindow(
            title: event.title,
            snippet: event.isFree ? "FREE" : "₹${event.price.toInt()}",
          ),
          onTap: () => _onMarkerTap(event),
        ),
      );
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

  Future<BitmapDescriptor> createPriceMarker(
    String text,
    bool isFree,
  ) async {
    const double width = 220;
    const double height = 110;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bgPaint = Paint()..color = Colors.white;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final accentColor =
        isFree ? const Color(0xff2ECC71) : const Color(0xffFF4D6D);

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 14, 190, 56),
        const Radius.circular(28),
      ),
      shadowPaint,
    );

    // White pill
    final pill = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 10, 190, 56),
      const Radius.circular(28),
    );

    canvas.drawRRect(pill, bgPaint);
    canvas.drawRRect(pill, borderPaint);

    // Bottom pin
    final path = Path();

    path.moveTo(95, 66);
    path.lineTo(115, 66);
    path.lineTo(105, 82);
    path.close();

    canvas.drawPath(path, Paint()..color = accentColor);

    canvas.drawCircle(
      const Offset(105, 94),
      7,
      Paint()..color = accentColor,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w800,
          fontSize: text.length > 5 ? 22 : 26,
          letterSpacing: .4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    tp.layout();

    tp.paint(
      canvas,
      Offset(
        (210 - tp.width) / 2,
        22,
      ),
    );

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
              });
            },
            myLocationEnabled: widget.userLat != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            markers: _markers,
          ),

          // ── Dark overlay for contrast ──
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

          // ── Event preview card ──
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
