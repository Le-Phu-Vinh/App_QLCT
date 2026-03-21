import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickAndCropAvatar(BuildContext context) async {
  final ImagePicker picker = ImagePicker();

  final ImageSource? source = await showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn nguồn ảnh'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          child: const Text('Từ máy tính'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Hủy'),
        ),
      ],
    ),
  );

  if (source == null) return null;

  final XFile? pickedFile = await picker.pickImage(source: source);
  if (pickedFile == null) return null;

  final bytes = await pickedFile.readAsBytes();

  // Web: không có cropper native, chỉ trả về ảnh đã chọn.
  // Người dùng có thể tùy chỉnh avatar bằng cách crop/scale bên UI (ví dụ CircleAvatar fit) hoặc mở rộng sau.
  return bytes;
}
