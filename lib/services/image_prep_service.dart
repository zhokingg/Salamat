import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// What one preparation pass did, so the caller can log or report it.
@immutable
class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.originalBytes,
    required this.elapsed,
    required this.compressed,
  });

  /// JPEG bytes to upload.
  final Uint8List bytes;

  /// Size of the file as it came off the camera.
  final int originalBytes;

  /// How long the resize + re-encode took.
  final Duration elapsed;

  /// False when the original was returned unchanged (compression failed, or
  /// the frame was already small enough to leave alone).
  final bool compressed;

  int get preparedBytes => bytes.length;

  /// e.g. 6.8 — how many times smaller the upload got.
  double get ratio =>
      preparedBytes == 0 ? 0 : originalBytes / preparedBytes;

  @override
  String toString() => 'PreparedImage(${originalBytes ~/ 1024} KB -> '
      '${preparedBytes ~/ 1024} KB, ${elapsed.inMilliseconds} ms, '
      'compressed: $compressed)';
}

/// Shrinks a camera frame before it is uploaded for recognition.
///
/// WHY THIS EXISTS
///   The camera hands back the sensor's full frame — 3840x2160 and about 2 MB
///   of JPEG on the device this was measured on. All of it was being base64'd
///   and uploaded, and base64 adds a third on top. Most of the wait between
///   the shutter and the result was that upload, not the model: 13 s end to
///   end against 4.5 s spent inside the Edge Function.
///
///   None of those pixels survive anyway. The recognition model is
///   standard-resolution tier: it downscales anything above its limits before
///   it counts a single token, so the bytes above that are paid for in upload
///   time and thrown away on arrival. See [ImagePrepService.kMaxLongEdge] for
///   why that limit works out at 1456 and not the 1568 the docs put on the
///   long edge.
///
/// WHAT IT DOES
///   Long edge to [kMaxLongEdge], JPEG quality [kJpegQuality], EXIF dropped.
///   The plugin applies the EXIF orientation to the pixels first, so dropping
///   the metadata cannot leave the model looking at a sideways plate.
///
/// WHAT IT DOES NOT DO
///   It never enlarges. A frame already at or under the long edge is returned
///   as-is, so a small photo is not re-encoded into a worse one.
class ImagePrepService {
  ImagePrepService._();

  /// Long edge, in pixels, of the image actually uploaded.
  ///
  /// 1456, not the tier's 1568 long-edge limit, because the long edge is not
  /// the binding constraint — the visual-token cap is. Standard tier allows
  /// 1568 visual tokens, and a token is a 28x28 patch, so a 16:9 frame at
  /// 1568x882 costs ceil(1568/28) * ceil(882/28) = 56 * 32 = 1792. Over the
  /// cap, so the server downsizes it again, to about 1456x819 = 52 * 30 =
  /// 1560 tokens.
  ///
  /// Sending 1568 therefore uploads pixels that are thrown away on arrival.
  /// 1456 is the widest edge that survives, which makes this a smaller upload
  /// for an identical token count and an identical image at the model.
  static const int kMaxLongEdge = 1456;

  /// JPEG quality. High enough that compression artefacts do not reach the
  /// point where the docs warn they start costing the model accuracy.
  static const int kJpegQuality = 85;

  /// Result of the most recent call, for the debug overlay and for reporting.
  static PreparedImage? lastResult;

  /// Pixel size of an encoded image, without decoding the whole thing.
  /// Null when the header cannot be read.
  static Future<ui.Size?> _dimensions(File source) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(
        await source.readAsBytes(),
      );
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return ui.Size(
        descriptor.width.toDouble(),
        descriptor.height.toDouble(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[ImagePrep] could not read dimensions: $e');
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// The size to ask for, or null when the frame should be left alone.
  static ui.Size? _targetSize(ui.Size? source) {
    if (source == null || source.width < 1 || source.height < 1) return null;
    final longest = math.max(source.width, source.height);
    if (longest <= kMaxLongEdge) return null;
    final scale = kMaxLongEdge / longest;
    return ui.Size(
      math.max(1, (source.width * scale).roundToDouble()),
      math.max(1, (source.height * scale).roundToDouble()),
    );
  }

  /// Returns JPEG bytes ready to upload.
  ///
  /// Never throws: if the plugin fails for any reason the original file is
  /// returned unchanged, because a large upload is much better than no scan.
  static Future<PreparedImage> prepare(File source) async {
    final sw = Stopwatch()..start();
    final originalBytes = await source.length();

    try {
      // `minWidth`/`minHeight` are MINIMUMS, not a bounding box: the plugin
      // scales so that BOTH are met, which on a 16:9 frame with 1456/1456 gave
      // 2588x1456 — a long edge of 2588, nearly twice what was intended. The
      // token count did not betray it, because the server downscales to its
      // own cap either way; only reading the dimensions out of the uploaded
      // JPEG showed it. So the target is computed here and passed exactly.
      final size = await _dimensions(source);
      final target = _targetSize(size);
      if (target == null) {
        // Already small enough, or the header could not be read. Either way,
        // re-encoding would only cost quality.
        sw.stop();
        final bytes = await source.readAsBytes();
        return lastResult = PreparedImage(
          bytes: bytes,
          originalBytes: originalBytes,
          elapsed: sw.elapsed,
          compressed: false,
        );
      }

      final out = await FlutterImageCompress.compressWithFile(
        source.absolute.path,
        minWidth: target.width.round(),
        minHeight: target.height.round(),
        quality: kJpegQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      sw.stop();

      if (out == null || out.isEmpty || out.length >= originalBytes) {
        // Bigger than what we started with means re-encoding a frame that was
        // already small. Send the original.
        final bytes = await source.readAsBytes();
        return lastResult = PreparedImage(
          bytes: bytes,
          originalBytes: originalBytes,
          elapsed: sw.elapsed,
          compressed: false,
        );
      }

      final result = PreparedImage(
        bytes: out,
        originalBytes: originalBytes,
        elapsed: sw.elapsed,
        compressed: true,
      );
      if (kDebugMode) debugPrint('[ImagePrep] $result');
      return lastResult = result;
    } catch (e) {
      sw.stop();
      if (kDebugMode) debugPrint('[ImagePrep] failed, sending original: $e');
      final bytes = await source.readAsBytes();
      return lastResult = PreparedImage(
        bytes: bytes,
        originalBytes: originalBytes,
        elapsed: sw.elapsed,
        compressed: false,
      );
    }
  }
}
