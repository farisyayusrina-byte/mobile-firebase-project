/// Parsed line item from receipt OCR text.
class DetectedItem {
  const DetectedItem({required this.name, required this.price});

  final String name;
  final double price;
}

class ReceiptParser {
  static final _linePrice = RegExp(
    r'^(.*?)(?:\s+)(?:RM\s*)?(\d{1,4}(?:\.\d{1,2})?)\s*$',
    caseSensitive: false,
  );

  static final _rmPrice = RegExp(
    r'RM\s*(\d{1,4}(?:\.\d{1,2})?)',
    caseSensitive: false,
  );

  /// Extract item names and prices from OCR text.
  static List<DetectedItem> parse(String text) {
    if (text.trim().isEmpty) return [];

    final items = <DetectedItem>[];
    final skipWords = {
      'total',
      'subtotal',
      'tax',
      'gst',
      'sst',
      'change',
      'cash',
      'thank',
      'receipt',
      'date',
      'time',
    };

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.length < 3) continue;

      final lower = line.toLowerCase();
      if (skipWords.any((w) => lower.startsWith(w))) continue;

      DetectedItem? item;

      final lineMatch = _linePrice.firstMatch(line);
      if (lineMatch != null) {
        final name = lineMatch.group(1)!.trim();
        final price = double.tryParse(lineMatch.group(2)!);
        if (name.isNotEmpty && price != null && price > 0 && price < 10000) {
          item = DetectedItem(name: name, price: price);
        }
      }

      if (item == null) {
        final prices = _rmPrice.allMatches(line).toList();
        if (prices.isNotEmpty) {
          final last = prices.last;
          final price = double.tryParse(last.group(1)!);
          final name = line.substring(0, last.start).trim();
          if (name.isNotEmpty && price != null && price > 0 && price < 10000) {
            item = DetectedItem(name: name, price: price);
          }
        }
      }

      if (item != null) {
        items.add(item);
      }
    }

    return items;
  }

  static double totalOf(List<DetectedItem> items) =>
      items.fold(0, (sum, i) => sum + i.price);
}
