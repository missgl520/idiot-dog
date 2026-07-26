// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 图片选择按钮（待接入）
//
// 当前实现：弹出底部菜单提示"待接入"
//
// 后续接入 image_picker 包后替换方向：
//   1. pubspec.yaml 添加依赖：image_picker: ^1.1.2
//   2. import 'package:image_picker/image_picker.dart';
//   3. 相册：ImagePicker().pickImage(source: ImageSource.gallery)
//   4. 相机：ImagePicker().pickImage(source: ImageSource.camera)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
import 'package:flutter/material.dart';

class ImagePickerButton extends StatelessWidget {
  const ImagePickerButton({super.key});

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 接入 image_picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('图片选择器待接入')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(context);
                // TODO: 接入 image_picker
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('相机待接入')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _showPicker(context),
      icon: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600],
        ),
      ),
      tooltip: '添加图片',
    );
  }
}
