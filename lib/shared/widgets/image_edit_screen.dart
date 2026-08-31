import 'dart:io' show File;
import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_helper.dart';

// NOTE ON DEPENDENCIES
// This screen needs a package that isn't used elsewhere in the files
// you pasted, so add it to pubspec.yaml:
//
//   dependencies:
//     crop_your_image: ^1.0.2   # in-app cropping UI (works on web too)
//     image: ^4.1.7             # pure-Dart pixel ops for rotate
//
// This file targets crop_your_image ^1.0.2's actual public API (verified
// against the package source at that exact tag):
//   - Crop.onCropped is `ValueChanged<Uint8List>` — you get the cropped
//     image bytes directly, there is no CropResult/CropSuccess/CropFailure
//     wrapper in this version (that shape belongs to a newer major version).
//   - Crop.aspectRatio is a plain `double?` (width ÷ height), not a
//     CropAspectRatio class. `null` means free-form cropping.
//   - CropController has NO rotateLeft()/rotateRight() in this version —
//     its public API is only: crop(), cropCircle(), and the setters
//     `image`, `aspectRatio`, `withCircleUi`, `cropRect`, `area`. So
//     rotation below is done manually with the `image` package (rotating
//     the raw bytes) and then pushed back into the cropper by assigning
//     `_cropController.image = rotatedBytes`, which the package's own
//     source confirms re-parses/resets the cropping editor with the new
//     bytes.
// If you upgrade crop_your_image to a major version that adds
// CropResult / built-in rotation, this screen can be simplified again.

/// A basic in-app photo editor shown right after picking an image, before
/// it's sent in a chat. Supports free/fixed-ratio cropping and 90° rotation.
/// Pops with the edited image as a new [XFile], or `null` if the user
/// cancelled.
class ImageEditScreen extends StatefulWidget {
  final XFile imageFile;
  const ImageEditScreen({super.key, required this.imageFile});

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

class _ImageEditScreenState extends State<ImageEditScreen> {
  final _cropController = CropController();
  Uint8List? _originalBytes;

  // Bytes currently fed into the cropper. Starts equal to [_originalBytes]
  // and is replaced whenever the user rotates — the crop_your_image
  // CropController has no built-in rotate, so rotation is implemented by
  // rotating these bytes ourselves and reassigning them to the controller.
  Uint8List? _workingBytes;

  bool _loading = true;
  bool _saving = false;
  bool _rotating = false;
  double? _aspectRatio; // null = free crop, else width/height

  // Bumped on every rotate/aspect-ratio change and folded into the Crop
  // widget's Key below. This version of crop_your_image doesn't reliably
  // re-apply a new `aspectRatio` or a reassigned `image` on an
  // already-mounted Crop widget — changing the Key forces Flutter to fully
  // unmount and remount it, which DOES pick up the new value every time.
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (!mounted) return;
    setState(() {
      _originalBytes = bytes;
      _workingBytes = bytes;
      _loading = false;
    });
  }

  void _setAspectRatio(double? value) {
    if (_aspectRatio == value) return;
    setState(() {
      _aspectRatio = value;
      _revision++;
    });
  }

  Future<void> _rotate(bool clockwise) async {
    if (_workingBytes == null || _rotating || _saving) return;
    setState(() => _rotating = true);
    try {
      final decoded = img.decodeImage(_workingBytes!);
      if (decoded == null) return;
      final rotated = img.copyRotate(decoded, angle: clockwise ? 90 : -90);
      // PNG (lossless) so repeated rotations don't degrade quality — JPEG
      // re-encoding only happens once, at send time, in _onCropped.
      final bytes = Uint8List.fromList(img.encodePng(rotated));
      if (!mounted) return;
      setState(() {
        _workingBytes = bytes;
        _revision++; // forces the Crop widget below to remount with it
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not rotate the image.')),
        );
      }
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  Future<void> _onCropped(Uint8List croppedBytes) async {
    try {
      final fileName = 'edited_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Re-encode to JPEG at send time so the file is compact regardless of
      // how the cropper returned the bytes.
      Uint8List outBytes = croppedBytes;
      final decoded = img.decodeImage(croppedBytes);
      if (decoded != null) {
        outBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 90));
      }

      XFile edited;
      if (kIsWeb) {
        edited =
            XFile.fromData(outBytes, name: fileName, mimeType: 'image/jpeg');
      } else {
        final tmpDir = await getTempDirPath();
        final path = '$tmpDir/$fileName';
        await File(path).writeAsBytes(outBytes);
        edited = XFile(path, name: fileName);
      }

      if (!mounted) return;
      Navigator.of(context).pop(edited);
    } catch (e) {
      // Bail out gracefully instead of hanging on the loading spinner if
      // anything above (decode/encode/file write) fails.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not process the crop.')),
        );
      }
    }
  }

  void _save() {
    if (_saving) return;
    setState(() => _saving = true);
    _cropController.crop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white)),
        ),
        title: const Text('Edit Photo', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: (_saving || _loading) ? null : _save,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: TheyDiColors.gradientPrimary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
      body: (_loading || _originalBytes == null)
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Crop(
                      key: ValueKey('crop_$_revision'),
                      controller: _cropController,
                      image: _workingBytes!,
                      onCropped: _onCropped,
                      aspectRatio: _aspectRatio,
                      withCircleUi: false,
                      baseColor: Colors.black,
                      maskColor: Colors.black.withValues(alpha: 0.75),
                      progressIndicator: const CircularProgressIndicator(
                          color: Colors.white),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF141414),
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 14, bottom: 20),
                  child: Column(
                    children: [
                      _buildAspectRatioBar(),
                      const SizedBox(height: 14),
                      _buildRotateBar(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAspectRatioBar() {
    final options = <String, double?>{
      'Free': null,
      '1:1': 1.0,
      '4:5': 4 / 5,
      '16:9': 16 / 9,
    };
    return SizedBox(
      height: 36,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: options.entries.map((e) {
          final selected = _aspectRatio == e.value;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => _setAspectRatio(e.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? TheyDiColors.primary : Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? TheyDiColors.primary
                        : Colors.white24,
                  ),
                ),
                child: Text(
                  e.key,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRotateBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RotateButton(
          icon: Icons.rotate_left,
          onTap: _rotating ? null : () => _rotate(false),
        ),
        const SizedBox(width: 28),
        SizedBox(
          width: 20,
          height: 20,
          child: _rotating
              ? const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70)
              : null,
        ),
        const SizedBox(width: 28),
        _RotateButton(
          icon: Icons.rotate_right,
          onTap: _rotating ? null : () => _rotate(true),
        ),
      ],
    );
  }
}

class _RotateButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RotateButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}