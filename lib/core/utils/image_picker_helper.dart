import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

import '../theme/app_theme.dart';

/// Central place for "pick + crop an image" logic.
///
/// WHY THIS EXISTS:
/// `image_cropper_for_web` (the web implementation `image_cropper` pulls in
/// automatically) has a known layout bug — its internal Save/Cancel button
/// row (an `ElevatedButton`) gets built with unbounded width constraints and
/// throws:
///   "BoxConstraints forces an infinite width."
/// at `cropper_dialog.dart`. This is a framework-level layout assertion, not
/// a normal Dart exception, so it CANNOT be caught with a try/catch around
/// the call that opens the dialog — by the time it throws, we're already
/// inside a widget build/layout pass. The only reliable fix is to never
/// build that widget tree on web in the first place.
///
/// USE THIS EVERYWHERE you currently call `ImageCropper()` directly —
/// chat attachments, profile photo, verification photos, circle/event
/// cover images, etc. If you have other screens calling `ImageCropper()`
/// directly, replace those calls with `ImagePickerHelper.cropImage(...)`
/// too, or you'll keep hitting this crash on web from whichever screen
/// still calls it raw.
class ImagePickerHelper {
  ImagePickerHelper._();

  /// Opens the native crop UI for [file] on Android/iOS.
  /// On web, returns [file] unchanged (cropping is skipped entirely —
  /// see the class doc for why).
  /// Also returns the original file untouched if the user cancels, or if
  /// the cropper fails/isn't available for any other reason — cropping
  /// should never be able to block a send/upload flow.
  static Future<XFile?> cropImage(
    XFile file, {
    String toolbarTitle = 'Crop Photo',
    String doneButtonTitle = 'Done',
    String cancelButtonTitle = 'Cancel',
  }) async {
    if (kIsWeb) return file;

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: toolbarTitle,
            toolbarColor: TheyDiColors.dark,
            toolbarWidgetColor: Colors.white,
            backgroundColor: TheyDiColors.dark,
            activeControlsWidgetColor: TheyDiColors.primary,
            statusBarColor: TheyDiColors.dark,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: toolbarTitle,
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            doneButtonTitle: doneButtonTitle,
            cancelButtonTitle: cancelButtonTitle,
          ),
        ],
      );
      if (cropped == null) return file; // user backed out without cropping
      return XFile(cropped.path, name: file.name);
    } catch (_) {
      // Cropper unavailable/failed for any reason — never block the
      // send/upload flow because of it.
      return file;
    }
  }
}