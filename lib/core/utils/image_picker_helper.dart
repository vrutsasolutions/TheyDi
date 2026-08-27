import 'package:image_picker/image_picker.dart';

/// Central place for "pick + crop an image" logic.
///
/// Cropping is temporarily DISABLED everywhere while the crop UI is being
/// redesigned. `cropImage` is currently a no-op that just returns the
/// original file unchanged — every call site already goes through this
/// helper, so bringing cropping back later only means updating this one
/// function (re-add the `image_cropper` package + its UI settings here).
///
/// USE THIS EVERYWHERE an image needs cropping — chat attachments, profile
/// photo, verification photos, circle/event cover images, etc. If any
/// screen still calls `ImageCropper()` directly, route it through here
/// instead so the disable applies consistently across the app.
class ImagePickerHelper {
  ImagePickerHelper._();

  /// Currently always returns [file] unchanged — cropping is disabled.
  /// Kept as a Future<XFile?> (matching the eventual real implementation)
  /// so call sites don't need to change when cropping is restored.
  static Future<XFile?> cropImage(
    XFile file, {
    String toolbarTitle = 'Crop Photo',
    String doneButtonTitle = 'Done',
    String cancelButtonTitle = 'Cancel',
  }) async {
    return file;
  }
}