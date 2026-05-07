import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../i18n/i18n.dart';

/// Capped at 3 to match the server's accepted batch size. Mirrors
/// iOS / RN.
const int _kMaxAttachments = 3;

class AttachmentPickerButton extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<List<String>> onChange;
  final bool disabled;

  const AttachmentPickerButton({
    super.key,
    required this.paths,
    required this.onChange,
    this.disabled = false,
  });

  Future<void> _pick(BuildContext context) async {
    if (disabled) return;
    final picker = ImagePicker();
    final remaining = _kMaxAttachments - paths.length;
    if (remaining <= 0) return;
    try {
      final picked = await picker.pickMultiImage(limit: remaining);
      if (picked.isEmpty) return;
      onChange([...paths, ...picked.map((x) => x.path)]);
    } catch (e) {
      // ignore: avoid_print
      print('[Feddy] attachment pick failed — $e');
    }
  }

  void _remove(int index) {
    final next = [...paths]..removeAt(index);
    onChange(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: disabled || paths.length >= _kMaxAttachments
              ? null
              : () => _pick(context),
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(t('attachment.add')),
        ),
        if (paths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                for (var i = 0; i < paths.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(paths[i]),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: GestureDetector(
                            onTap: disabled ? null : () => _remove(i),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
