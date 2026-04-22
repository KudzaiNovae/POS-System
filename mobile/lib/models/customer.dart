/// Customer domain model.
///
/// Mirrors the backend `CustomerDto` so we can post the local copy
/// straight back. Balances live on the server (driven by invoice
/// payments) — clients only display them.
class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.tin,
    this.balanceCents = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.dirty = false,
  })  : createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  final String id;
  String name;
  String? phone;
  String? email;
  String? tin;
  int balanceCents;
  DateTime createdAt;
  DateTime updatedAt;
  bool dirty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'tin': tin,
        'balanceCents': balanceCents,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'dirty': dirty,
      };

  /// Payload accepted by `POST /customers` (upsert).
  Map<String, dynamic> toApiPayload() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'tin': tin,
        'balanceCents': balanceCents,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        tin: m['tin'] as String?,
        balanceCents: (m['balanceCents'] as num?)?.toInt() ?? 0,
        createdAt: _parse(m['createdAt']) ?? DateTime.now().toUtc(),
        updatedAt: _parse(m['updatedAt']) ?? DateTime.now().toUtc(),
        dirty: (m['dirty'] as bool?) ?? false,
      );

  static DateTime? _parse(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString())?.toUtc();
  }
}
