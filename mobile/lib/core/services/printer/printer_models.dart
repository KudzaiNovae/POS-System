import 'package:flutter/foundation.dart';

/// Represents a physical printer device
class PrinterDevice {
  final String id;
  final String name;
  final PrinterType type;
  final PrinterConnectionType connectionType;
  final bool isConnected;
  final String? address;
  final DateTime? lastConnected;

  const PrinterDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.connectionType,
    this.isConnected = false,
    this.address,
    this.lastConnected,
  });

  PrinterDevice copyWith({
    String? id,
    String? name,
    PrinterType? type,
    PrinterConnectionType? connectionType,
    bool? isConnected,
    String? address,
    DateTime? lastConnected,
  }) {
    return PrinterDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      connectionType: connectionType ?? this.connectionType,
      isConnected: isConnected ?? this.isConnected,
      address: address ?? this.address,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Types of printers supported
enum PrinterType {
  thermal, // Thermal receipt printer (80mm, 58mm)
  inkjet, // Standard inkjet printer
  laser, // Laser printer
  unknown,
}

/// Connection types for printers
enum PrinterConnectionType {
  bluetooth,
  usb,
  network,
  unknown,
}

/// Print job status
enum PrintJobStatus {
  pending,
  printing,
  completed,
  failed,
  cancelled,
}

/// Represents a print job in the queue
class PrintJob {
  final String id;
  final String receiptId;
  final List<int> escposData;
  final DateTime createdAt;
  PrintJobStatus status;
  final String? deviceId;
  String? errorMessage;
  DateTime? completedAt;

  PrintJob({
    required this.id,
    required this.receiptId,
    required this.escposData,
    required this.createdAt,
    this.status = PrintJobStatus.pending,
    this.deviceId,
    this.errorMessage,
    this.completedAt,
  });

  bool get isPending => status == PrintJobStatus.pending;
  bool get isPrinting => status == PrintJobStatus.printing;
  bool get isCompleted => status == PrintJobStatus.completed;
  bool get isFailed => status == PrintJobStatus.failed;

  Duration? get duration => completedAt != null ? completedAt!.difference(createdAt) : null;
}

/// Printer service state
class PrinterServiceState {
  final PrinterDevice? selectedPrinter;
  final List<PrinterDevice> availablePrinters;
  final bool isScanning;
  final bool isConnected;
  final String? connectionError;

  const PrinterServiceState({
    this.selectedPrinter,
    this.availablePrinters = const [],
    this.isScanning = false,
    this.isConnected = false,
    this.connectionError,
  });

  PrinterServiceState copyWith({
    PrinterDevice? selectedPrinter,
    List<PrinterDevice>? availablePrinters,
    bool? isScanning,
    bool? isConnected,
    String? connectionError,
  }) {
    return PrinterServiceState(
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      availablePrinters: availablePrinters ?? this.availablePrinters,
      isScanning: isScanning ?? this.isScanning,
      isConnected: isConnected ?? this.isConnected,
      connectionError: connectionError ?? this.connectionError,
    );
  }
}

/// Print settings
class PrintSettings {
  final int paperWidth; // in mm (80 or 58 for thermal)
  final bool autoPrint; // Auto-print after sale
  final bool showPrintDialog; // Show print dialog before printing
  final String? shopName;
  final String? shopAddress;
  final String? shopPhone;
  final bool printLogo; // Print shop logo
  final bool printBarcode; // Print barcode on receipt
  final bool printQrCode; // Print QR code with sale ID
  final int fontSize; // 0=small, 1=normal, 2=large

  const PrintSettings({
    this.paperWidth = 80,
    this.autoPrint = false,
    this.showPrintDialog = true,
    this.shopName,
    this.shopAddress,
    this.shopPhone,
    this.printLogo = true,
    this.printBarcode = false,
    this.printQrCode = true,
    this.fontSize = 1,
  });

  PrintSettings copyWith({
    int? paperWidth,
    bool? autoPrint,
    bool? showPrintDialog,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
    bool? printLogo,
    bool? printBarcode,
    bool? printQrCode,
    int? fontSize,
  }) {
    return PrintSettings(
      paperWidth: paperWidth ?? this.paperWidth,
      autoPrint: autoPrint ?? this.autoPrint,
      showPrintDialog: showPrintDialog ?? this.showPrintDialog,
      shopName: shopName ?? this.shopName,
      shopAddress: shopAddress ?? this.shopAddress,
      shopPhone: shopPhone ?? this.shopPhone,
      printLogo: printLogo ?? this.printLogo,
      printBarcode: printBarcode ?? this.printBarcode,
      printQrCode: printQrCode ?? this.printQrCode,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  Map<String, dynamic> toJson() => {
    'paperWidth': paperWidth,
    'autoPrint': autoPrint,
    'showPrintDialog': showPrintDialog,
    'shopName': shopName,
    'shopAddress': shopAddress,
    'shopPhone': shopPhone,
    'printLogo': printLogo,
    'printBarcode': printBarcode,
    'printQrCode': printQrCode,
    'fontSize': fontSize,
  };

  factory PrintSettings.fromJson(Map<String, dynamic> json) {
    return PrintSettings(
      paperWidth: json['paperWidth'] as int? ?? 80,
      autoPrint: json['autoPrint'] as bool? ?? false,
      showPrintDialog: json['showPrintDialog'] as bool? ?? true,
      shopName: json['shopName'] as String?,
      shopAddress: json['shopAddress'] as String?,
      shopPhone: json['shopPhone'] as String?,
      printLogo: json['printLogo'] as bool? ?? true,
      printBarcode: json['printBarcode'] as bool? ?? false,
      printQrCode: json['printQrCode'] as bool? ?? true,
      fontSize: json['fontSize'] as int? ?? 1,
    );
  }
}

/// Exception for printer operations
class PrinterException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  PrinterException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'PrinterException: $message${code != null ? ' ($code)' : ''}';
}

/// Callback for printer status updates
typedef PrinterStatusCallback = void Function(PrinterServiceState state);

/// Callback for print job status updates
typedef PrintJobCallback = void Function(PrintJob job);
