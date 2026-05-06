import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 在独立 Isolate 里解码/缩放/JPEG 编码，避免主线程卡死（大图时常见）。
({Uint8List preview, Uint8List thumb}) processPickedImageForUpload(Uint8List originalBytes) {
  final originalImage = img.decodeImage(originalBytes);
  if (originalImage == null) {
    throw StateError('无法解析图片');
  }
  final thumbForPreview = img.copyResize(originalImage, width: 480);
  final previewBytes = img.encodeJpg(thumbForPreview, quality: 82);
  final thumbnail = img.copyResize(originalImage, width: 1080);
  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 80);
  return (
    preview: Uint8List.fromList(previewBytes),
    thumb: Uint8List.fromList(thumbnailBytes),
  );
}
