/// ESC/POS command builder for thermal printers
/// Generates byte sequences for Epson-compatible thermal receipt printers
class ESCPOSBuilder {
  static const _ESC = 0x1B;
  static const _GS = 0x1D;
  static const _LF = 0x0A;
  static const _CR = 0x0D;
  static const _NUL = 0x00;

  final List<int> _data = [];
  int _currentAlign = 0; // 0=left, 1=center, 2=right

  /// Add raw bytes
  void addRaw(List<int> bytes) {
    _data.addAll(bytes);
  }

  /// Initialize printer
  void initialize() {
    _data.addAll([_ESC, 0x40]); // ESC @
    setAlign(0); // Reset to left align
  }

  /// Reset printer
  void reset() {
    _data.addAll([_ESC, 0x40]); // ESC @
  }

  /// Line feed
  void lineFeed({int count = 1}) {
    for (int i = 0; i < count; i++) {
      _data.add(_LF);
    }
  }

  /// Set text alignment (0=left, 1=center, 2=right)
  void setAlign(int align) {
    if (align < 0 || align > 2) align = 0;
    _currentAlign = align;
    _data.addAll([_ESC, 0x61, align]); // ESC a
  }

  /// Add text with current formatting
  void text(String content) {
    _data.addAll(utf8Encode(content));
    lineFeed();
  }

  /// Add text without line feed
  void textNoFeed(String content) {
    _data.addAll(utf8Encode(content));
  }

  /// Set bold mode
  void setBold(bool bold) {
    _data.addAll([_ESC, 0x45, bold ? 1 : 0]); // ESC E
  }

  /// Set underline mode
  void setUnderline(bool underline) {
    _data.addAll([_ESC, 0x2D, underline ? 1 : 0]); // ESC -
  }

  /// Set font size (0=1x1, 1=2x2, 2=3x3, etc.)
  void setFontSize(int size) {
    if (size < 0 || size > 8) size = 0;
    _data.addAll([_GS, 0x21, size]); // GS !
  }

  /// Set double width
  void setDoubleWidth(bool double_) {
    _data.addAll([_ESC, 0x0E, double_ ? 1 : 0]); // ESC SO
  }

  /// Set double height
  void setDoubleHeight(bool double_) {
    _data.addAll([_ESC, 0x0D, double_ ? 1 : 0]); // ESC CR
  }

  /// Print title/header text
  void title(String content, {int size = 2}) {
    setFontSize(size);
    setBold(true);
    setAlign(1); // center
    text(content);
    setBold(false);
    setFontSize(0);
    setAlign(0); // left
  }

  /// Print two columns of text (left and right aligned)
  void dualColumn(String left, String right, {int width = 32}) {
    final maxLeftWidth = (width * 2 / 3).toInt();
    final maxRightWidth = width - maxLeftWidth;

    String leftPad = left.length > maxLeftWidth ? left.substring(0, maxLeftWidth - 1) : left;
    String rightPad = right.length > maxRightWidth ? right.substring(0, maxRightWidth - 1) : right;

    final spaces = width - leftPad.length - rightPad.length;
    final padding = ' ' * (spaces > 0 ? spaces : 1);

    text('$leftPad$padding$rightPad');
  }

  /// Print horizontal line
  void line({int char = 45, int width = 32}) { // 45 = '-'
    text(String.fromCharCode(char) * width);
  }

  /// Print divider (dots)
  void divider({int width = 32}) {
    line(char: 46, width: width); // 46 = '.'
  }

  /// Cut paper (partial cut)
  void cutPartial() {
    _data.addAll([_GS, 0x56, 1]); // GS V
  }

  /// Cut paper (full cut)
  void cutFull() {
    _data.addAll([_GS, 0x56, 0]); // GS V
  }

  /// Beep
  void beep({int duration = 50}) {
    _data.addAll([_ESC, 0x42, (duration ~/ 10).clamp(1, 25)]); // ESC B
  }

  /// Drawer kick (open cash drawer)
  void openDrawer() {
    _data.addAll([_ESC, 0x70, 0, 25, 250]); // ESC p
  }

  /// Print barcode (CODE128 format)
  void barcode(String data, {int width = 2, int height = 50}) {
    // GS h (height)
    _data.addAll([_GS, 0x68, height]);
    // GS w (width)
    _data.addAll([_GS, 0x77, width]);
    // GS k (barcode type 73=CODE128)
    _data.addAll([_GS, 0x6B, 73, data.length]);
    _data.addAll(utf8Encode(data));
    lineFeed();
  }

  /// Print QR code
  void qrcode(String data, {int size = 4}) {
    if (size < 1 || size > 8) size = 4;

    // GS ( k - Store QR code data
    final encodedData = utf8Encode(data);
    final pL = (encodedData.length + 3) & 0xFF;
    final pH = ((encodedData.length + 3) >> 8) & 0xFF;

    _data.addAll([_GS, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    _data.addAll(encodedData);

    // GS ( k - Set QR code size
    _data.addAll([_GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, size]);

    // GS ( k - Print QR code
    _data.addAll([_GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    lineFeed();
  }

  /// Get the final ESC/POS data
  List<int> build() {
    reset();
    lineFeed(count: 3);
    return List<int>.from(_data);
  }

  /// Get bytes without final reset/line feeds
  List<int> getRawBytes() {
    return List<int>.from(_data);
  }

  /// Encode string to UTF-8 bytes with fallback
  static List<int> utf8Encode(String text) {
    try {
      return _utf8.encode(text);
    } catch (e) {
      // Fallback: ASCII only
      return text.codeUnits.map((c) => c > 127 ? 63 : c).toList(); // 63 = '?'
    }
  }

  /// Simple UTF-8 encoder
  static const _utf8 = _UTF8Encoder();
}

/// Simple UTF-8 encoder
class _UTF8Encoder {
  const _UTF8Encoder();

  List<int> encode(String text) {
    final bytes = <int>[];
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);

      if (codeUnit < 0x80) {
        bytes.add(codeUnit);
      } else if (codeUnit < 0x800) {
        bytes.add(0xC0 | (codeUnit >> 6));
        bytes.add(0x80 | (codeUnit & 0x3F));
      } else if (codeUnit < 0x10000) {
        bytes.add(0xE0 | (codeUnit >> 12));
        bytes.add(0x80 | ((codeUnit >> 6) & 0x3F));
        bytes.add(0x80 | (codeUnit & 0x3F));
      }
    }
    return bytes;
  }
}

/// Receipt formatter using ESC/POS
class ReceiptFormatter {
  final ESCPOSBuilder builder = ESCPOSBuilder();

  /// Format receipt for a sale
  List<int> formatSaleReceipt({
    required String shopName,
    required String saleId,
    required List<Map<String, dynamic>> items,
    required int subtotalCents,
    required int vatCents,
    required int totalCents,
    String? paymentMethod,
    String? currency = 'KES',
    String? shopAddress,
    String? shopPhone,
    bool printQrCode = true,
  }) {
    builder.initialize();

    // Header
    if (shopName.isNotEmpty) {
      builder.title(shopName, size: 2);
    }

    if (shopAddress != null && shopAddress.isNotEmpty) {
      builder.setAlign(1);
      builder.text(shopAddress);
      builder.setAlign(0);
    }

    if (shopPhone != null && shopPhone.isNotEmpty) {
      builder.setAlign(1);
      builder.text(shopPhone);
      builder.setAlign(0);
    }

    builder.line();

    // Sale info
    builder.text('Sale ID: $saleId');
    builder.text('Date: ${DateTime.now().toString().split('.')[0]}');
    builder.line();

    // Items header
    builder.text('Item             Qty  Price    Total');
    builder.divider();

    // Items
    for (final item in items) {
      final name = (item['name'] as String?) ?? 'Unknown';
      final qty = item['quantity'] ?? 0;
      final price = (item['unitPrice'] as int?) ?? 0;
      final total = (item['lineTotal'] as int?) ?? 0;

      final truncatedName = name.length > 15 ? name.substring(0, 15) : name;
      final qtyStr = qty.toString();
      final priceStr = '${(price / 100).toStringAsFixed(0)}';
      final totalStr = '${(total / 100).toStringAsFixed(0)}';

      builder.text('${truncatedName.padRight(15)} ${qtyStr.padLeft(3)} ${priceStr.padLeft(5)} ${totalStr.padLeft(6)}');
    }

    builder.line();

    // Totals
    final subtotalStr = (subtotalCents / 100).toStringAsFixed(2);
    final vatStr = (vatCents / 100).toStringAsFixed(2);
    final totalStr = (totalCents / 100).toStringAsFixed(2);

    builder.dualColumn('Subtotal:', '$currency $subtotalStr');
    builder.dualColumn('VAT:', '$currency $vatStr');

    builder.setFontSize(1);
    builder.setBold(true);
    builder.dualColumn('TOTAL:', '$currency $totalStr', width: 32);
    builder.setBold(false);
    builder.setFontSize(0);

    builder.line();

    // Payment
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      builder.text('Payment: $paymentMethod');
    }

    // QR Code
    if (printQrCode) {
      builder.lineFeed();
      builder.setAlign(1);
      builder.qrcode(saleId, size: 4);
      builder.setAlign(0);
    }

    builder.lineFeed(count: 3);
    builder.cutFull();

    return builder.build();
  }

  /// Format simple test receipt
  List<int> formatTestReceipt({String shopName = 'Test Shop'}) {
    builder.initialize();
    builder.title('PRINT TEST', size: 2);
    builder.line();
    builder.text('This is a test receipt');
    builder.text('All features working');
    builder.line();
    builder.text('Date: ${DateTime.now().toString().split('.')[0]}');
    builder.lineFeed(count: 3);
    builder.cutFull();
    return builder.build();
  }
}
