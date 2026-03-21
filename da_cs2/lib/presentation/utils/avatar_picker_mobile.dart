import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

Future<Uint8List?> pickAndCropAvatar(BuildContext context) async {
  final ImagePicker picker = ImagePicker();

  final ImageSource? source = await showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn nguồn ảnh'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
          child: const Text('Camera'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
          child: const Text('Thư viện'),
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

  final CroppedFile? croppedFile = await ImageCropper().cropImage(
    sourcePath: pickedFile.path,
    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Chỉnh sửa ảnh đại diện',
        toolbarColor: Theme.of(context).primaryColor,
        toolbarWidgetColor: Colors.white,
        initAspectRatio: CropAspectRatioPreset.square,
        lockAspectRatio: true,
      ),
      IOSUiSettings(
        title: 'Chỉnh sửa ảnh đại diện',
        aspectRatioLockEnabled: true,
        resetAspectRatioEnabled: false,
      ),
    ],
  );

  if (croppedFile == null) return null;

  final File imageFile = File(croppedFile.path);
  final bytes = await imageFile.readAsBytes();
  return bytes;
}
