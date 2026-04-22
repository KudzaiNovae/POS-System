/// Offline-first Invoice domain model.
///
/// Mirrors the backend schema exactly so payloads can be posted untouched.
/// Totals are recomputed on both ends; the server is authoritative, but we
/// keep client-side computation so drafts render live while the user types.
class InvoiceItem {
  InvoiceItem({
    required this.id,
    this.productId,
    required this.description,
    required this.qty,
    this.unit = 'pc',
    required this.unitPriceCents,
    this.discountCents = 0,
    this.vatClass = 'STANDARD',
  });

  final String id;
  String? productId;
  String description;
  num qty;
  String unit;
  int unitPriceCents;
  int discountCents;
  String vatClass;

  int get lineTotalCents {
    final gross = (unitPriceCents * qty).round() - discountCents;
    return gross < 0 ? 0 : gross;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'productId': productId,
        'description': description,
        'qty': qty,
        'unit': unit,
        'unitPriceCents': unitPriceCents,
        'discountCents': discountCents,
        'lineTotalCents': lineTotalCents,
        'vatClass': vatClass,
      };

  Map<String, dynamic> toApiPayload() => toMap();

  factory InvoiceItem.fromMap(Map<String, dynamic> m) => InvoiceItem(
        id: m['id'] as String,
        productId: m['productId'] as String?,
        description: m['description'] as String,
        qty: m['qty'] as num,
        unit: (m['unit'] as String?) ?? 'pc',
        unitPriceCents: (m['unitPriceCents'] as num).toInt(),
        discountCents: (m['discountCents'] as num?)?.toInt() ?? 0,
        vatClass: (m['vatClass'] as String?) ?? 'STANDARD',
      );
}

class InvoicePayment {
  InvoicePayment({
    required this.id,
    required this.amountCents,
    required this.method,
    this.reference,
    DateTime? paidAt,
  }) : paidAt = paidAt ?? DateTime.now().toUtc();

  final String id;
  final int amountCents;
  final String method;
  final String? reference;
  final DateTime paidAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'amountCents': amountCents,
        'method': method,
        'reference': reference,
        'paidAt': paidAt.toIso8601String(),
      };

  factory InvoicePayment.fromMap(Map<String, dynamic> m) => InvoicePayment(
        id: m['id'] as String,
        amountCents: (m['amountCents'] as num).toInt(),
        method: m['method'] as String,
        reference: m['reference'] as String?,
        paidAt: DateTime.tryParse(m['paidAt'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
      );
}

class Invoice {
  Invoice({
    required this.id,
    this.number,
    this.kind = 'INVOICE',
    this.parentInvoiceId,
    this.customerId,
    this.customerName,
    this.customerTin,
    this.customerEmail,
    this.customerAddress,
    this.status = 'DRAFT',
    DateTime? issueDate,
    this.dueDate,
    this.currency = 'USD',
    this.discountCents = 0,
    this.notes,
    this.terms,
    this.fiscalReceiptNo,
    this.fiscalStatus,
    DateTime? clientCreatedAt,
    required this.items,
    this.payments = const [],
    this.dirty = true,
  })  : issueDate = issueDate ?? DateTime.now(),
        clientCreatedAt = clientCreatedAt ?? DateTime.now().toUtc();

  final String id;
  String? number;
  String kind;
  String? parentInvoiceId;
  String? customerId;
  String? customerName;
  String? customerTin;
  String? customerEmail;
  String? customerAddress;
  String status;
  DateTime issueDate;
  DateTime? dueDate;
  String currency;
  int discountCents;
  String? notes;
  String? terms;
  String? fiscalReceiptNo;
  String? fiscalStatus;
  final DateTime clientCreatedAt;
  List<InvoiceItem> items;
  List<InvoicePayment> payments;
  bool dirty;

  int get subtotalCents =>
      items.fold<int>(0, (a, i) => a + _netOf(i));
  int get vatCents =>
      items.fold<int>(0, (a, i) => a + _vatOf(i));
  int get totalCents {
    final gross = items.fold<int>(0, (a, i) => a + i.lineTotalCents);
    final t = gross - discountCents;
    return t < 0 ? 0 : t;
  }

  int get paidCents =>
      payments.fold<int>(0, (a, p) => a + p.amountCents);
  int get balanceCents => (totalCents - paidCents).clamp(0, 1 << 62);

  int _netOf(InvoiceItem i) {
    final gross = i.lineTotalCents;
    switch (i.vatClass) {
      case 'STANDARD':
        return (gross * 10000) ~/ (10000 + 1500);
      case 'LUXURY':
        return (gross * 10000) ~/ (10000 + 2500);
      default:
        return gross;
    }
  }

  int _vatOf(InvoiceItem i) => i.lineTotalCents - _netOf(i);

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'kind': kind,
        'parentInvoiceId': parentInvoiceId,
        'customerId': customerId,
        'customerName': customerName,
        'customerTin': customerTin,
        'customerEmail': customerEmail,
        'customerAddress': customerAddress,
        'status': status,
        'issueDate': _fmt(issueDate),
        'dueDate': dueDate == null ? null : _fmt(dueDate!),
        'currency': currency,
        'subtotalCents': subtotalCents,
        'vatCents': vatCents,
        'discountCents': discountCents,
        'totalCents': totalCents,
        'paidCents': paidCents,
        'balanceCents': balanceCents,
        'notes': notes,
        'terms': terms,
        'fiscalReceiptNo': fiscalReceiptNo,
        'fiscalStatus': fiscalStatus,
        'clientCreatedAt': clientCreatedAt.toIso8601String(),
        'items': items.map((i) => i.toMap()).toList(),
        'payments': payments.map((p) => p.toMap()).toList(),
        'dirty': dirty,
      };

  Map<String, dynamic> toApiPayload() {
    final m = Map<String, dynamic>.from(toMap());
    m.remove('dirty');
    m.remove('payments'); // payments are posted via their own endpoint
    return m;
  }

  factory Invoice.fromMap(Map<String, dynamic> m) => Invoice(
        id: m['id'] as String,
        number: m['number'] as String?,
        kind: (m['kind'] as String?) ?? 'INVOICE',
        parentInvoiceId: m['parentInvoiceId'] as String?,
        customerId: m['customerId'] as String?,
        customerName: m['customerName'] as String?,
        customerTin: m['customerTin'] as String?,
        customerEmail: m['customerEmail'] as String?,
        customerAddress: m['customerAddress'] as String?,
        status: (m['status'] as String?) ?? 'DRAFT',
        issueDate: _parseDate(m['issueDate']) ?? DateTime.now(),
        dueDate: _parseDate(m['dueDate']),
        currency: (m['currency'] as String?) ?? 'USD',
        discountCents: (m['discountCents'] as num?)?.toInt() ?? 0,
        notes: m['notes'] as String?,
        terms: m['terms'] as String?,
        fiscalReceiptNo: m['fiscalReceiptNo'] as String?,
        fiscalStatus: m['fiscalStatus'] as String?,
        clientCreatedAt:
            DateTime.parse(m['clientCreatedAt'] as String).toUtc(),
        items: ((m['items'] as List?) ?? [])
            .map((e) => InvoiceItem.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        payments: ((m['payments'] as List?) ?? [])
            .map((e) => InvoicePayment.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
        dirty: (m['dirty'] as bool?) ?? false,
      );

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
