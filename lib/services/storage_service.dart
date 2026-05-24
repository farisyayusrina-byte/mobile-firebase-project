import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Upload gambar resit ke Firebase Storage.
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final ImagePicker _picker = ImagePicker();

  /// Resize on pick so OCR is faster (large photos can take 30–60s).
  Future<XFile?> pickFromGallery() => _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1600,
      );

  Future<XFile?> pickFromCamera() => _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1280,
        maxHeight: 1600,
      );

  /// Upload fail; pulangkan public download URL.
  Future<String> uploadReceiptImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final path =
        'receipts/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final ref = _storage.ref().child(path);

    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return snapshot.ref.getDownloadURL();
  }
}
