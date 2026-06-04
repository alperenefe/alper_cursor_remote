import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../models/prompt_attachment.dart';

class AttachmentPickException implements Exception {
  AttachmentPickException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Galeri, kamera veya dosya seçici → base64 ekler.
class AttachmentPickerService {
  AttachmentPickerService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<PromptAttachment?> pickFromCamera() async {
    final file = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 4096,
    );
    if (file == null) return null;
    return _fromXFile(file, fallbackName: 'camera.jpg');
  }

  Future<List<PromptAttachment>> pickFromGallery({bool multi = true}) async {
    if (multi) {
      final files = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 4096,
      );
      final out = <PromptAttachment>[];
      for (final f in files) {
        final att = await _fromXFile(f);
        if (att != null) out.add(att);
      }
      return out;
    }
    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 4096,
    );
    if (file == null) return [];
    final one = await _fromXFile(file);
    return one == null ? [] : [one];
  }

  Future<List<PromptAttachment>> pickFiles() async {
    const types = <XTypeGroup>[
      XTypeGroup(
        label: 'Dosyalar',
        extensions: <String>[
          'pdf',
          'txt',
          'md',
          'json',
          'dart',
          'yaml',
          'yml',
          'zip',
          'png',
          'jpg',
          'jpeg',
          'webp',
        ],
      ),
    ];
    final files = await openFiles(acceptedTypeGroups: types);
    final out = <PromptAttachment>[];
    for (final f in files) {
      final att = await _fromXFile(f);
      if (att != null) out.add(att);
    }
    return out;
  }

  Future<PromptAttachment?> _fromXFile(XFile file, {String? fallbackName}) async {
    final bytes = await file.readAsBytes();
    final name = _basename(file.name.isNotEmpty ? file.name : fallbackName ?? 'image.jpg');
    final mime = lookupMimeType(name, headerBytes: bytes) ?? 'image/jpeg';
    return _bytesToAttachment(name: name, mimeType: mime, bytes: bytes);
  }

  PromptAttachment? _bytesToAttachment({
    required String name,
    required String mimeType,
    required List<int> bytes,
  }) {
    if (bytes.length > PromptAttachment.maxBytesPerFile) {
      throw AttachmentPickException(
        '$name çok büyük (en fazla ${PromptAttachment.maxBytesPerFile ~/ (1024 * 1024)} MB).',
      );
    }
    return PromptAttachment(
      name: name,
      mimeType: mimeType,
      base64: base64Encode(bytes),
    );
  }

  String _basename(String path) {
    final sep = path.contains(r'\') ? r'\' : '/';
    final parts = path.split(sep);
    return parts.isEmpty ? path : parts.last;
  }

  /// Mevcut listeye eklerken dosya sayısı ve toplam boyut sınırı.
  static void ensureCanAdd(
    List<PromptAttachment> current,
    List<PromptAttachment> incoming,
  ) {
    if (current.length + incoming.length > PromptAttachment.maxFiles) {
      throw AttachmentPickException(
        'En fazla ${PromptAttachment.maxFiles} ek dosya gönderebilirsiniz.',
      );
    }
    for (final a in incoming) {
      if (a.byteLength > PromptAttachment.maxBytesPerFile) {
        throw AttachmentPickException('${a.name} çok büyük.');
      }
    }
  }
}
