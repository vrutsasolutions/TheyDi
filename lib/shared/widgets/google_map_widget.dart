import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapWidget extends StatefulWidget {
  final double latitude;
  final double longitude;

  final Set<Marker> markers;

  final Function(GoogleMapController)? onMapCreated;

  final void Function(LatLng)? onTap;

  const GoogleMapWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.markers = const {},
    this.onMapCreated,
    this.onTap,
  });

  @override
  State<GoogleMapWidget> createState() => _GoogleMapWidgetState();
}

class _GoogleMapWidgetState extends State<GoogleMapWidget> {
  GoogleMapController? controller;

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(widget.latitude, widget.longitude),
        zoom: 13,
      ),

      markers: widget.markers,

      myLocationEnabled: true,

      myLocationButtonEnabled: true,

      zoomControlsEnabled: true,

      compassEnabled: true,

      mapToolbarEnabled: true,

      onTap: widget.onTap,

      onMapCreated: (c) {
        controller = c;

        widget.onMapCreated?.call(c);
      },
    );
  }
}