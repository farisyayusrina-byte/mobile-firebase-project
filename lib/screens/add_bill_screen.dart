import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bill.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/receipt_ocr_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/split_widgets.dart';

class AddBillScreen extends StatefulWidget {
  const AddBillScreen({
    super.key,
    required this.userId,
    this.groupId,
    this.groupName,
    this.defaultParticipants,
    this.initialImage,
    this.initialOcrText,
    this.initialItems,
    this.initialTotal,
  });

  final String userId;
  final String? groupId;
  final String? groupName;
  final List<String>? defaultParticipants;
  final XFile? initialImage;
  final String? initialOcrText;
  final List<BillItem>? initialItems;
  final double? initialTotal;

  @override
  State<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends State<AddBillScreen> {
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  final _participantsController = TextEditingController();
  final _ocrController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();

  final _storage = StorageService();
  final _firestore = FirestoreService();
  final _notifications = NotificationService();
  final _ocr = ReceiptOcrService();

  XFile? _pickedFile;
  Uint8List? _previewBytes;
  final List<BillItem> _items = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupName != null) {
      _titleController.text = widget.groupName!;
    }
    if (widget.defaultParticipants != null &&
        widget.defaultParticipants!.isNotEmpty) {
      _participantsController.text = widget.defaultParticipants!.join(', ');
    }
    _applyInitialFromScan();
  }

  Future<void> _applyInitialFromScan() async {
    final file = widget.initialImage;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final items = widget.initialItems ?? [];
    final total = widget.initialTotal;
    final sum = items.fold<double>(0, (s, i) => s + i.price);

    setState(() {
      _pickedFile = file;
      _previewBytes = bytes;
      if (widget.initialOcrText != null && widget.initialOcrText!.isNotEmpty) {
        _ocrController.text = widget.initialOcrText!;
      }
      if (items.isNotEmpty) {
        _items.addAll(items);
      }
      if (total != null && total > 0) {
        _totalController.text = total.toStringAsFixed(2);
      } else if (sum > 0) {
        _totalController.text = sum.toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _totalController.dispose();
    _participantsController.dispose();
    _ocrController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _ocr.dispose();
    super.dispose();
  }

  List<String> get _participants => _participantsController.text
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pickImage(ImageSource source) async {
    final file = source == ImageSource.gallery
        ? await _storage.pickFromGallery()
        : await _storage.pickFromCamera();
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedFile = file;
      _previewBytes = bytes;
    });
  }

  Future<void> _scanReceipt() async {
    final file = _pickedFile;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a receipt image first')),
      );
      return;
    }
    if (!_ocr.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ML Kit OCR is only available on Android/iOS'),
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final text = await _ocr.recognizeReceipt(file);
      _ocrController.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt scanned with ML Kit')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _addItem() {
    final name = _itemNameController.text.trim();
    final price = double.tryParse(_itemPriceController.text) ?? 0;
    if (name.isEmpty) return;

    setState(() {
      _items.add(BillItem(name: name, price: price));
      _itemNameController.clear();
      _itemPriceController.clear();
    });
  }

  Future<void> _saveBill() async {
    final title = _titleController.text.trim();
    final total = double.tryParse(_totalController.text) ?? 0;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill title is required')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      String? imageUrl;
      if (_pickedFile != null) {
        imageUrl = await _storage.uploadReceiptImage(_pickedFile!);
      }

      final billId = await _firestore.createBill(
        userId: widget.userId,
        title: title,
        total: total,
        participants: _participants,
        items: _items,
        receiptImageUrl: imageUrl,
        ocrText: _ocrController.text.trim().isEmpty
            ? null
            : _ocrController.text.trim(),
        groupId: widget.groupId,
      );

      await _notifications.notifyBillSaved(
        userId: widget.userId,
        billTitle: title,
        billId: billId,
        members: _participants.isEmpty ? const ['You'] : _participants,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add bill'),
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FormSectionCard(
                  title: 'Bill details',
                  icon: Icons.edit_note,
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Group dinner',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _totalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total (RM)',
                          prefixText: 'RM ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _participantsController,
                        decoration: const InputDecoration(
                          labelText: 'Participants',
                          hintText: 'Ali, Abu, Siti',
                          helperText: 'Separate names with commas',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FormSectionCard(
                  title: 'Digital receipt',
                  icon: Icons.cloud_upload_outlined,
                  child: Column(
                    children: [
                      if (_previewBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _previewBytes!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          height: 120,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 40),
                              SizedBox(height: 8),
                              Text('No receipt selected'),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _pickImage(ImageSource.gallery),
                              icon: const Icon(Icons.photo),
                              label: const Text('Gallery'),
                            ),
                          ),
                          if (!kIsWeb) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _pickImage(ImageSource.camera),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _scanReceipt,
                        icon: const Icon(Icons.document_scanner),
                        label: const Text('Scan with ML Kit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ocrController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Receipt text (OCR)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FormSectionCard(
                  title: 'Items to split',
                  icon: Icons.list_alt,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _itemNameController,
                              decoration: const InputDecoration(
                                labelText: 'Item name',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _itemPriceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('Add item'),
                      ),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._items.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: const Icon(
                                Icons.fastfood,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(item.name),
                            trailing: Text(
                              'RM ${item.price.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x44000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _busy ? null : _saveBill,
            child: Text(_busy ? 'Saving...' : 'Save bill'),
          ),
        ),
      ),
    );
  }
}
