import 'package:image_picker/image_picker.dart';

import '../utils/receipt_parser.dart';

class SplitBillData {
  SplitBillData({
    required this.items,
    required this.members,
    required this.total,
    this.receiptImage,
    this.ocrText,
    this.suggestedTitle,
  });

  final List<SplitLineItem> items;
  final List<String> members;
  final double total;
  final XFile? receiptImage;
  final String? ocrText;
  final String? suggestedTitle;

  factory SplitBillData.fromDetected({
    required List<DetectedItem> detected,
    List<String>? members,
    XFile? receiptImage,
    String? ocrText,
    String? suggestedTitle,
  }) {
    final items = detected
        .map((e) => SplitLineItem(name: e.name, price: e.price))
        .toList();
    final total = ReceiptParser.totalOf(detected);
    return SplitBillData(
      items: items,
      members: members ?? const ['You'],
      total: total,
      receiptImage: receiptImage,
      ocrText: ocrText,
      suggestedTitle: suggestedTitle,
    );
  }
}

class SplitLineItem {
  SplitLineItem({
    required this.name,
    required this.price,
    this.assignedTo,
  });

  final String name;
  final double price;
  String? assignedTo;
}
