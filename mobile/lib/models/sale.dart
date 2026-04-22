class SaleItem {
  SaleItem({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.qty,
    required this.unitPriceCents,
    this.vatClass = 'STANDARD',
    this.netCents = 0,
    this.vatCents = 0,
  });

  final String id;
  final String productId;
  final String nameSnapshot;
  final num qty;
  final int unitPriceCents;
  final String vatClass;
  int netCents;
  int vatCents;

  int get lineTotalCents => (unitPriceCents * qty).round();

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'nameSnapshot': nameSnapshot,
        'qty': qty,
        'unitPriceCents': unitPriceCents,
        'lineTotalCents': lineTotalCents,
        'vatClass': vatClass,
        'netCents': netCents,
        'vatCents': vatCents,
      };

  Map<String, dynamic> toApiPayload() => toMap();

  factory SaleItem.fromMap(Map<String, dynamic> m) => SaleItem(
        id: m['id'] as String,
        productId: m['productId'] as String,
        nameSnapshot: m['nameSnapshot'] as String,
        qty: m['qty'] as num,
        unitPriceCents: (m['unitPriceCents'] as num).toInt(),
        vatClass: (m['vatClass'] as String?) ?? 'STANDARD',
        netCents: (m['netCents'] as num?)?.toInt() ?? 0,
        vatCents: (m['vatCents'] as num?)?.toInt() ?? 0,
      );
}

class Sale {
  Sale({
    required this.id,
    required this.items,
    required this.paymentMethod,
    this.paymentRef,
    this.cashierId,
    this.customerId,
    this.customerName,
    this.customerTin,
    this.status = 'COMPLETED',
    this.taxCents = 0,
    this.subtotalCents = 0,
    this.vatCents = 0,
    this.fiscalReceiptNo,
    this.fiscalStatus = 'PENDING',
    this.fiscalReference,
    this.fiscalQrPayload,
    DateTime? clientCreatedAt,
    this.dirty = true,
  }) : clientCreatedAt = clientCreatedAt ?? DateTime.now().toUtc();

  final String id;
  final String? cashierId;
  final String? customerId;
  String? customerName;
  String? customerTin;
  final int taxCents;
  int subtotalCents;
  int vatCents;
  final String paymentMethod;
  final String? paymentRef;
  String status;

  // --- ZIMRA fiscal fields (filled by server or client QR formatter) ---
  String? fiscalReceiptNo;
  String fiscalStatus;
  String? fiscalReference;
  String? fiscalQrPayload;

  final DateTime clientCreatedAt;
  final List<SaleItem> items;
  bool dirty;

  int get totalCents =>
      items.fold<int>(0, (acc, i) => acc + i.lineTotalCents) + taxCents;
  double get total => totalCents / 100.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'cashierId': cashierId,
        'customerId': customerId,
        'customerName': customerName,
        'customerTin': customerTin,
        'taxCents': taxCents,
        'subtotalCents': subtotalCents,
        'vatCents': vatCents,
        'totalCents': totalCents,
        'paymentMethod': paymentMethod,
        'paymentRef': paymentRef,
        'status': status,
        'fiscalReceiptNo': fiscalReceiptNo,
        'fiscalStatus': fiscalStatus,
        'fiscalReference': fiscalReference,
        'fiscalQrPayload': fiscalQrPayload,
        'clientCreatedAt': clientCreatedAt.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
        'dirty': dirty,
      };

  Map<String, dynamic> toApiPayload() => {
        'id': id,
        'cashierId': cashierId,
        'customerId': customerId,
        'customerName': customerName,
        'customerTin': customerTin,
        'totalCents': totalCents,
        'subtotalCents': subtotalCents,
        'vatCents': vatCents,
        'taxCents': taxCents,
        'paymentMethod': paymentMethod,
        'paymentRef': paymentRef,
        'status': status,
        'clientCreatedAt': clientCreatedAt.toIso8601String(),
        'items': items.map((i) => i.toApiPayload()).toList(),
      };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        cashierId: m['cashierId'] as String?,
        customerId: m['customerId'] as String?,
        customerName: m['customerName'] as String?,
        customerTin: m['customerTin'] as String?,
        taxCents: (m['taxCents'] as num?)?.toInt() ?? 0,
        subtotalCents: (m['subtotalCents'] as num?)?.toInt() ?? 0,
        vatCents: (m['vatCents'] as num?)?.toInt() ?? 0,
        paymentMethod: m['paymentMethod'] as String,
        paymentRef: m['paymentRef'] as String?,
        status: m['status'] as String? ?? 'COMPLETED',
        fiscalReceiptNo: m['fiscalReceiptNo'] as String?,
        fiscalStatus: m['fiscalStatus'] as String? ?? 'PENDING',
        fiscalReference: m['fiscalReference'] as String?,
        fiscalQrPayload: m['fiscalQrPayload'] as String?,
        clientCreatedAt:
            DateTime.parse(m['clientCreatedAt'] as String).toUtc(),
        items: (m['items'] as List)
            .map((e) => SaleItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        dirty: m['dirty'] as bool? ?? false,
      );
}
