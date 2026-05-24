import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/split_bill_data.dart';
import '../services/receipt_ocr_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/receipt_parser.dart';
import 'add_bill_screen.dart';
import 'split_bill_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.userId,
    this.onSplitBill,
  });

  final String userId;
  final void Function(SplitBillData data)? onSplitBill;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _storage = StorageService();
  final _ocr = ReceiptOcrService();

  XFile? _pickedFile;
  Uint8List? _previewBytes;
  String? _ocrText;
  List<DetectedItem> _detectedItems = [];
  bool _busy = false;
  bool _scanComplete = false;
  bool _bannerDismissed = false;
  String? _scanError;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  void _resetScan() {
    setState(() {
      _pickedFile = null;
      _previewBytes = null;
      _ocrText = null;
      _detectedItems = [];
      _scanComplete = false;
      _bannerDismissed = false;
      _scanError = null;
    });
  }

  Future<void> _pick(ImageSource source) async {
    final file = source == ImageSource.camera
        ? await _storage.pickFromCamera()
        : await _storage.pickFromGallery();
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _pickedFile = file;
      _previewBytes = bytes;
      _scanComplete = false;
      _detectedItems = [];
      _bannerDismissed = false;
      _scanError = null;
    });

    await _processReceipt();
  }

  Future<void> _processReceipt() async {
    final file = _pickedFile;
    if (file == null) return;

    if (!_ocr.isSupported) {
      if (mounted) {
        setState(() {
          _scanError =
              'OCR only works on Android/iOS. Use a phone, or add the bill manually.';
        });
      }
      return;
    }

    setState(() {
      _busy = true;
      _scanError = null;
    });
    try {
      final text = await _ocr.recognizeReceipt(file);
      final items = ReceiptParser.parse(text);

      if (mounted) {
        setState(() {
          _ocrText = text;
          _detectedItems = items;
          _scanComplete = true;
          _bannerDismissed = false;
        });
      }

      if (items.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No items detected. Try a clearer photo or add items manually.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanError = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _splitBill() {
    if (_detectedItems.isEmpty) {
      _openManualAddBill();
      return;
    }

    final data = SplitBillData.fromDetected(
      detected: _detectedItems,
      receiptImage: _pickedFile,
      ocrText: _ocrText,
      suggestedTitle: 'Scanned receipt',
    );
    if (widget.onSplitBill != null) {
      widget.onSplitBill!(data);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SplitBillScreen(
            userId: widget.userId,
            fromDisplayName: 'You',
            data: data,
            onScanReceipt: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  void _openManualAddBill() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddBillScreen(
          userId: widget.userId,
          initialImage: _pickedFile,
          initialOcrText: _ocrText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text(
                'Scan Receipt',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload or capture a receipt to extract items automatically',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              if (!_scanComplete) ...[
                _UploadZone(
                  previewBytes: _previewBytes,
                  busy: _busy,
                  scanError: _scanError,
                  onTakePhoto: () => _pick(ImageSource.camera),
                  onUpload: () => _pick(ImageSource.gallery),
                  onRetry: _processReceipt,
                  onManual: _splitBill,
                ),
              ] else ...[
                if (!_bannerDismissed)
                  _SuccessBanner(
                    itemCount: _detectedItems.length,
                    onDismiss: () => setState(() => _bannerDismissed = true),
                  ),
                if (!_bannerDismissed) const SizedBox(height: 20),
                const Text(
                  'Detected Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _DetectedItemsCard(items: _detectedItems),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetScan,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Scan Another',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _detectedItems.isEmpty ? null : _splitBill,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Split Bill',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const _ScanTipsCard(),
            ],
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({
    required this.itemCount,
    required this.onDismiss,
  });

  final int itemCount;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receipt Scanned Successfully!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    fontSize: 14,
                  ),
                ),
                Text(
                  itemCount == 1
                      ? '1 item detected'
                      : '$itemCount items detected',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryDark.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _DetectedItemsCard extends StatelessWidget {
  const _DetectedItemsCard({required this.items});

  final List<DetectedItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E8E2)),
        ),
        child: Text(
          'No line items found. Tap Scan Another or use Split Bill to add manually.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }

    final total = ReceiptParser.totalOf(items);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8E2)),
      ),
      child: Column(
        children: [
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                if (index > 0)
                  Divider(height: 1, color: Colors.grey.shade200),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.grey.shade500,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'RM ${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadZone extends StatelessWidget {
  const _UploadZone({
    required this.previewBytes,
    required this.busy,
    required this.scanError,
    required this.onTakePhoto,
    required this.onUpload,
    required this.onRetry,
    required this.onManual,
  });

  final Uint8List? previewBytes;
  final bool busy;
  final String? scanError;
  final VoidCallback onTakePhoto;
  final VoidCallback onUpload;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400, width: 1.5),
      ),
      child: previewBytes == null
          ? _EmptyUpload(
              busy: busy,
              onTakePhoto: onTakePhoto,
              onUpload: onUpload,
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    previewBytes!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                if (busy) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Scanning receipt...',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usually 5–20 seconds. Long receipts may take up to 45s.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ] else if (scanError != null) ...[
                  Icon(Icons.error_outline, color: Colors.red.shade400),
                  const SizedBox(height: 8),
                  Text(
                    scanError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onRetry,
                          child: const Text('Retry scan'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: onManual,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child: const Text('Add manually'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Scan again'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _EmptyUpload extends StatelessWidget {
  const _EmptyUpload({
    required this.busy,
    required this.onTakePhoto,
    required this.onUpload,
  });

  final bool busy;
  final VoidCallback onTakePhoto;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            size: 36,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Capture or Upload Receipt',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Our OCR technology will automatically detect items and prices',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        _TakePhotoButton(onPressed: busy ? null : onTakePhoto),
        const SizedBox(height: 12),
        _UploadOutlineButton(onPressed: busy ? null : onUpload),
      ],
    );
  }
}

class _TakePhotoButton extends StatelessWidget {
  const _TakePhotoButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.photo_camera_outlined, size: 20),
        label: const Text(
          'Take Photo',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _UploadOutlineButton extends StatelessWidget {
  const _UploadOutlineButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(Icons.upload_file, color: Colors.grey.shade700, size: 20),
        label: const Text(
          'Upload',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ScanTipsCard extends StatelessWidget {
  const _ScanTipsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEFED),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tips for better scanning:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          _tip('Ensure good lighting on the receipt'),
          _tip('Keep the receipt flat and wrinkle-free'),
          _tip('Make sure all text is visible in frame'),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey.shade700)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}
