class Product {
  Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.sku,
    this.barcode,
    this.costCents = 0,
    this.stockQty = 0,
    this.reorderLevel = 0,
    this.unit = 'pc',
    this.vatClass = 'STANDARD',
    this.deleted = false,
    this.version = 1,
    DateTime? updatedAt,
    this.dirty = false,
  }) : updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String id;
  String? sku;
  String name;
  String? barcode;
  int priceCents;
  int costCents;
  num stockQty;
  num reorderLevel;
  String unit;
  String vatClass;
  bool deleted;
  int version;
  DateTime updatedAt;
  bool dirty;

  double get price => priceCents / 100.0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'sku': sku,
        'name': name,
        'barcode': barcode,
        'priceCents': priceCents,
        'costCents': costCents,
        'stockQty': stockQty,
        'reorderLevel': reorderLevel,
        'unit': unit,
        'vatClass': vatClass,
        'deleted': deleted,
        'version': version,
        'updatedAt': updatedAt.toIso8601String(),
        'dirty': dirty,
      };

  Map<String, dynamic> toApiPayload() => {
        'id': id,
        'sku': sku,
        'name': name,
        'barcode': barcode,
        'priceCents': priceCents,
        'costCents': costCents,
        'stockQty': stockQty,
        'reorderLevel': reorderLevel,
        'unit': unit,
        'vatClass': vatClass,
        'deleted': deleted,
      };

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as String,
        sku: m['sku'] as String?,
        name: m['name'] as String,
        barcode: m['barcode'] as String?,
        priceCents: (m['priceCents'] as num).toInt(),
        costCents: (m['costCents'] as num?)?.toInt() ?? 0,
        stockQty: (m['stockQty'] as num?) ?? 0,
        reorderLevel: (m['reorderLevel'] as num?) ?? 0,
        unit: m['unit'] as String? ?? 'pc',
        vatClass: m['vatClass'] as String? ?? 'STANDARD',
        deleted: m['deleted'] as bool? ?? false,
        version: (m['version'] as num?)?.toInt() ?? 1,
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        dirty: m['dirty'] as bool? ?? false,
      );
}
