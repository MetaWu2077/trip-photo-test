import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 按最长边约束缩放图片（长边 ≤ maxDim），保持宽高比，不填满到固定尺寸。
///
/// 内部使用 [img.copyResize]，当原图宽 > 高时以 width 为基准缩放，
/// 当原图高 ≥ 宽时以 height 为基准缩放，实现"最长边 ≤ maxDim"约束。
img.Image _resizeLongestSide(img.Image src, int maxDim) {
  if (src.width <= maxDim && src.height <= maxDim) return src;
  if (src.width > src.height) {
    return img.copyResize(src, width: maxDim);
  } else {
    return img.copyResize(src, height: maxDim);
  }
}

/// 在独立 Isolate 里解码/缩放/JPEG 编码，避免主线程卡死（大图时常见）。
///
/// [resizeMaxDimension] 缩略图最长边目标值（默认 1080）。
/// [thumbQuality] 缩略图 JPEG 压缩质量（默认 60，100-200KB 目标）。
/// [previewMaxDimension] 预览图最长边目标值（默认 480）。
/// [previewQuality] 预览图 JPEG 压缩质量（默认 82）。
({Uint8List preview, Uint8List thumb}) processPickedImageForUpload(
  Uint8List originalBytes, {
  int resizeMaxDimension = 1080,
  int thumbQuality = 60,
  int previewMaxDimension = 480,
  int previewQuality = 82,
}) {
  final originalImage = img.decodeImage(originalBytes);
  if (originalImage == null) {
    throw StateError('无法解析图片');
  }
  final thumbForPreview = _resizeLongestSide(originalImage, previewMaxDimension);
  final previewBytes = img.encodeJpg(thumbForPreview, quality: previewQuality);
  final thumbnail = _resizeLongestSide(originalImage, resizeMaxDimension);
  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 60);
  return (
    preview: Uint8List.fromList(previewBytes),
    thumb: Uint8List.fromList(thumbnailBytes),
  );
}

