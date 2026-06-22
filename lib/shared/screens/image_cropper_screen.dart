import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ImageCropperScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double? aspectRatio;
  final String title;

  const ImageCropperScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
    this.title = 'Crop Image',
  });

  @override
  State<ImageCropperScreen> createState() => _ImageCropperScreenState();
}

class _ImageCropperScreenState extends State<ImageCropperScreen> {
  ui.Image? _image;
  bool _loading = true;
  String? _errorMessage;

  // Zoom & Pan states
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  
  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _localFocalPoint = Offset.zero;

  // Selected aspect ratio
  late double? _currentAspectRatio;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _currentAspectRatio = widget.aspectRatio ?? 1.0; // Default to 1:1 if not provided
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(widget.imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _image = frameInfo.image;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load image: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _cropImage() async {
    if (_image == null) return;

    setState(() => _loading = true);

    try {
      // Get viewport and layout measurements
      final size = MediaQuery.of(context).size;
      final screenWidth = size.width;
      final screenHeight = size.height - 240; // height of viewport container (leaving room for controls)

      final imgAspect = _image!.width / _image!.height;
      final viewAspect = screenWidth / screenHeight;

      double imageDisplayWidth;
      double imageDisplayHeight;

      if (imgAspect > viewAspect) {
        imageDisplayWidth = screenWidth;
        imageDisplayHeight = screenWidth / imgAspect;
      } else {
        imageDisplayHeight = screenHeight;
        imageDisplayWidth = screenHeight * imgAspect;
      }

      final activeRatio = _currentAspectRatio ?? 1.0;
      double cropWidth, cropHeight;
      if (activeRatio > viewAspect) {
        cropWidth = screenWidth - 32;
        cropHeight = cropWidth / activeRatio;
      } else {
        cropHeight = screenHeight - 32;
        cropWidth = cropHeight * activeRatio;
      }

      final cropLeft = (screenWidth - cropWidth) / 2;
      final cropTop = (screenHeight - cropHeight) / 2;

      final cx = screenWidth / 2;
      final cy = screenHeight / 2;

      final ccx = imageDisplayWidth / 2;
      final ccy = imageDisplayHeight / 2;

      // Map crop window corners back to child local coordinates
      final leftC = (cropLeft - _offset.dx - cx) / _scale + ccx;
      final topC = (cropTop - _offset.dy - cy) / _scale + ccy;
      final widthC = cropWidth / _scale;
      final heightC = cropHeight / _scale;

      // Scale to original image pixels
      final scaleX = _image!.width / imageDisplayWidth;
      final scaleY = _image!.height / imageDisplayHeight;

      final origLeft = leftC * scaleX;
      final origTop = topC * scaleY;
      final origWidth = widthC * scaleX;
      final origHeight = heightC * scaleY;

      // Clamp coordinates to stay within image boundaries
      final srcLeft = origLeft.clamp(0.0, _image!.width.toDouble());
      final srcTop = origTop.clamp(0.0, _image!.height.toDouble());
      final srcRight = (origLeft + origWidth).clamp(0.0, _image!.width.toDouble());
      final srcBottom = (origTop + origHeight).clamp(0.0, _image!.height.toDouble());

      final srcWidth = srcRight - srcLeft;
      final srcHeight = srcBottom - srcTop;

      if (srcWidth <= 0 || srcHeight <= 0) {
        throw Exception("Invalid crop area");
      }

      // Draw onto canvas to perform crop
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

      canvas.drawImageRect(
        _image!,
        Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight),
        Rect.fromLTWH(0, 0, srcWidth, srcHeight),
        paint,
      );

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(srcWidth.toInt(), srcHeight.toInt());
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      final croppedBytes = byteData!.buffer.asUint8List();

      if (mounted) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Cropping failed: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: TheyDiColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Determine sizes
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height - 240; // Leave room for top/bottom bar & zoom controls

    final imgAspect = _image!.width / _image!.height;
    final viewAspect = screenWidth / screenHeight;

    double imageDisplayWidth;
    double imageDisplayHeight;

    if (imgAspect > viewAspect) {
      imageDisplayWidth = screenWidth;
      imageDisplayHeight = screenWidth / imgAspect;
    } else {
      imageDisplayHeight = screenHeight;
      imageDisplayWidth = screenHeight * imgAspect;
    }

    final activeRatio = _currentAspectRatio ?? 1.0;
    double cropWidth, cropHeight;
    if (activeRatio > viewAspect) {
      cropWidth = screenWidth - 32;
      cropHeight = cropWidth / activeRatio;
    } else {
      cropHeight = screenHeight - 32;
      cropWidth = cropHeight * activeRatio;
    }

    final cropLeft = (screenWidth - cropWidth) / 2;
    final cropTop = (screenHeight - cropHeight) / 2;
    final cropRect = Rect.fromLTWH(cropLeft, cropTop, cropWidth, cropHeight);

    final cx = screenWidth / 2;
    final cy = screenHeight / 2;

    // Minimum scale required to fully cover the crop window
    final minScale = max(cropWidth / imageDisplayWidth, cropHeight / imageDisplayHeight);
    final maxScale = max(minScale + 4.0, 8.0);

    // Initial scale/offset set up
    if (!_isInit) {
      _scale = minScale;
      _offset = Offset.zero;
      _isInit = true;
    }

    // Helper to constrain pan and zoom
    void clampConstraints() {
      if (_scale < minScale) {
        _scale = minScale;
      }
      if (_scale > maxScale) {
        _scale = maxScale;
      }

      double txMin = cropLeft + cropWidth - cx - _scale * imageDisplayWidth / 2;
      double txMax = cropLeft - cx + _scale * imageDisplayWidth / 2;
      double tyMin = cropTop + cropHeight - cy - _scale * imageDisplayHeight / 2;
      double tyMax = cropTop - cy + _scale * imageDisplayHeight / 2;

      // Handle edge cases
      if (txMin > txMax) {
        double temp = txMin;
        txMin = txMax;
        txMax = temp;
      }
      if (tyMin > tyMax) {
        double temp = tyMin;
        tyMin = tyMax;
        tyMax = temp;
      }

      _offset = Offset(
        _offset.dx.clamp(txMin, txMax),
        _offset.dy.clamp(tyMin, tyMax),
      );
    }

    // Keep state values clamped during structural builds
    clampConstraints();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: TheyDiTextStyles.headlineMedium.copyWith(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: TheyDiColors.primary, size: 28),
            onPressed: _cropImage,
          ),
        ],
      ),
      body: Column(
        children: [
          // Viewport area
          Expanded(
            child: ClipRect(
              child: GestureDetector(
                onScaleStart: (details) {
                  _baseScale = _scale;
                  _baseOffset = _offset;
                  _localFocalPoint = details.localFocalPoint;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    _scale = _baseScale * details.scale;
                    _offset = _baseOffset + (details.localFocalPoint - _localFocalPoint);
                    clampConstraints();
                  });
                },
                child: Stack(
                  children: [
                    // Base image
                    Positioned.fill(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: Transform(
                            transform: Matrix4.identity()
                              ..setEntry(0, 0, _scale)
                              ..setEntry(1, 1, _scale)
                              ..setEntry(0, 3, _offset.dx)
                              ..setEntry(1, 3, _offset.dy),
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: imageDisplayWidth,
                              height: imageDisplayHeight,
                              child: RawImage(
                                image: _image!,
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Mask overlay
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: CropOverlayPainter(
                            cropRect: cropRect,
                            isCircular: widget.aspectRatio == 1.0, // circular if 1:1 (profile)
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Controls area
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Zoom Slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.zoom_out, color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() {
                              _scale = (_scale - 0.25).clamp(minScale, maxScale);
                              clampConstraints();
                            });
                          },
                        ),
                        Expanded(
                          child: Slider(
                            value: _scale.clamp(minScale, maxScale),
                            min: minScale,
                            max: maxScale,
                            activeColor: TheyDiColors.primary,
                            inactiveColor: Colors.grey[800],
                            onChanged: (value) {
                              setState(() {
                                _scale = value;
                                clampConstraints();
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.zoom_in, color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() {
                              _scale = (_scale + 0.25).clamp(minScale, maxScale);
                              clampConstraints();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (widget.aspectRatio == null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ratioButton('1:1', 1.0),
                        const SizedBox(width: 8),
                        _ratioButton('16:9', 16 / 9),
                        const SizedBox(width: 8),
                        _ratioButton('4:3', 4 / 3),
                        const SizedBox(width: 8),
                        _ratioButton('2:3', 2 / 3),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Pinch to zoom or use slider • Drag to position',
                    style: TheyDiTextStyles.bodySmall.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioButton(String label, double ratio) {
    final isSelected = (_currentAspectRatio! - ratio).abs() < 0.01;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: TheyDiColors.primary,
      backgroundColor: Colors.grey[900],
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[400],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _currentAspectRatio = ratio;
            _isInit = false; // trigger re-initialization for the new aspect ratio
          });
        }
      },
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;
  final bool isCircular;

  CropOverlayPainter({required this.cropRect, this.isCircular = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5) // Reduced overlay opacity to make image clearly visible
      ..style = PaintingStyle.fill;

    final pathScreen = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final pathCutout = Path();
    if (isCircular) {
      pathCutout.addOval(cropRect);
    } else {
      pathCutout.addRect(cropRect);
    }

    final pathOverlay = Path.combine(PathOperation.difference, pathScreen, pathCutout);
    canvas.drawPath(pathOverlay, paint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (isCircular) {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRect(cropRect, borderPaint);

      // Grid lines
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4) // High contrast gridlines
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final wThird = cropRect.width / 3;
      final hThird = cropRect.height / 3;

      canvas.drawLine(
        Offset(cropRect.left + wThird, cropRect.top),
        Offset(cropRect.left + wThird, cropRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left + wThird * 2, cropRect.top),
        Offset(cropRect.left + wThird * 2, cropRect.bottom),
        gridPaint,
      );

      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + hThird),
        Offset(cropRect.right, cropRect.top + hThird),
        gridPaint,
      );
      canvas.drawLine(
        Offset(cropRect.left, cropRect.top + hThird * 2),
        Offset(cropRect.right, cropRect.top + hThird * 2),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || oldDelegate.isCircular != isCircular;
  }
}
