import 'dart:convert';
import 'package:crypto/crypto.dart' as _crypto;

import '../db/local_db.dart';
import '../../models/sale.dart';

/// Builds a ZIMRA-compatible QR payload on-device so offline receipts still
/// carry a verifiable footer. When the server finalises fiscalisation it
/// returns the authoritative value which overwrites this one.
///
/// Format matches FiscalService.buildQrPayload on the server:
///   TIN | VAT# | receiptNo | ISO8601 datetime | totalCents | vatCents | hash16
class FiscalQr {
  static String build(Sale sale) {
    final tin = LocalDb.metaBox.get('tin', defaultValue: '') as String;
    final vatNo = LocalDb.metaBox.get('vatNumber', defaultValue: '') as String;
    final rx = sale.fiscalReceiptNo ?? _provisionalReceiptNo(sale);
    final canon = [
      tin,
      vatNo,
      rx,
      sale.clientCreatedAt.toIso8601String(),
      sale.totalCents.toString(),
      sale.vatCents.toString(),
    ].join('|');
    final h = _sha256Hex(canon).substring(0, 16);
    return '$canon|$h';
  }

  static String _provisionalReceiptNo(Sale sale) {
    // Offline fallback: include shop short-code + timestamp tail of UUID.
    final tail = sale.id.replaceAll('-', '').substring(0, 6).toUpperCase();
    final d = sale.clientCreatedAt.toLocal();
    final stamp =
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    return 'OFFLINE-$stamp-$tail';
  }

  static String _sha256Hex(String input) {
    // Prefer crypto package when available; fall back to a naive impl so the
    // receipt still prints if the dependency isn't wired on a given target.
    try {
      final bytes = utf8.encode(input);
      return _crypto.sha256.convert(bytes).toString();
    } catch (_) {
      // Emergency fallback — not cryptographically strong, but deterministic.
      return _fallbackHash(input);
    }
  }

  static String _fallbackHash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0') * 4;
  }
}
