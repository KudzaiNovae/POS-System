import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'printer_service.dart';
import 'printer_models.dart';

/// Singleton printer service provider
final printerServiceProvider = Provider<PrinterService>((ref) {
  final service = PrinterService();
  service.initialize();
  return service;
});

/// Printer connection state provider
final printerStateProvider = StreamProvider<PrinterServiceState>((ref) async* {
  final service = ref.watch(printerServiceProvider);

  // Initial state
  yield service.state;

  // Stream updates
  service.onStatusChanged((state) {
    // This won't directly update the stream, but the notifyListeners will trigger rebuilds
  });
});

/// Selected printer provider
final selectedPrinterProvider = Provider<PrinterDevice?>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.selectedPrinter;
});

/// Available printers provider
final availablePrintersProvider = Provider<List<PrinterDevice>>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.availablePrinters;
});

/// Connection status provider
final printerConnectedProvider = Provider<bool>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.isConnected;
});

/// Scanning status provider
final printerScanningProvider = Provider<bool>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.isScanning;
});

/// Print queue provider
final printQueueProvider = Provider<List<PrintJob>>((ref) {
  final service = ref.watch(printerServiceProvider);
  return service.printQueue;
});

/// Printer service notifier for state changes
final printerNotifierProvider = StateNotifierProvider<PrinterNotifier, PrinterServiceState>((ref) {
  final service = ref.watch(printerServiceProvider);
  return PrinterNotifier(service);
});

/// Print job provider factory
final printJobProvider = FutureProvider.family<PrintJob?, String>((ref, jobId) async {
  final service = ref.watch(printerServiceProvider);
  return service.getPrintJobStatus(jobId);
});

/// Notifier for printer state changes
class PrinterNotifier extends StateNotifier<PrinterServiceState> {
  final PrinterService service;

  PrinterNotifier(this.service)
      : super(service.state) {
    service.onStatusChanged((newState) {
      state = newState;
    });
  }
}

/// Extension for easier access to printer service
extension PrinterServiceRef on WidgetRef {
  PrinterService get printer => watch(printerServiceProvider);

  Future<void> connectPrinter(PrinterDevice device) {
    return read(printerServiceProvider).connectPrinter(device);
  }

  Future<void> disconnectPrinter() {
    return read(printerServiceProvider).disconnect();
  }

  Future<void> startScanningPrinters() {
    return read(printerServiceProvider).startScanning();
  }

  void stopScanningPrinters() {
    return read(printerServiceProvider).stopScanning();
  }

  Future<void> printData(List<int> data) {
    return read(printerServiceProvider).print(data);
  }

  Future<String> queuePrintJob(String receiptId, List<int> data) {
    return read(printerServiceProvider).queuePrintJob(
      receiptId: receiptId,
      escposData: data,
    );
  }

  Future<void> printTest() {
    return read(printerServiceProvider).printTest();
  }

  bool cancelPrintJob(String jobId) {
    return read(printerServiceProvider).cancelPrintJob(jobId);
  }
}
