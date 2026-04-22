import 'dart:async';
import 'package:flutter/foundation.dart';
import 'printer_models.dart';

/// Main printer service for managing device connections and printing
class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();

  factory PrinterService() {
    return _instance;
  }

  PrinterService._internal();

  // State management
  PrinterServiceState _state = const PrinterServiceState();
  final List<PrintJob> _printQueue = [];
  final Map<String, PrintJob> _jobHistory = {};

  bool _isInitialized = false;
  bool _isPrinting = false;
  Timer? _scanTimer;
  Timer? _printQueueTimer;

  // Callbacks
  final List<PrinterStatusCallback> _statusCallbacks = [];
  final List<PrintJobCallback> _jobCallbacks = [];

  // Getters
  PrinterServiceState get state => _state;
  PrinterDevice? get selectedPrinter => _state.selectedPrinter;
  List<PrinterDevice> get availablePrinters => _state.availablePrinters;
  bool get isConnected => _state.isConnected;
  bool get isScanning => _state.isScanning;
  List<PrintJob> get printQueue => List.from(_printQueue);
  bool get isPrinting => _isPrinting;

  /// Initialize printer service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start print queue processor
      _startPrintQueueProcessor();
      _isInitialized = true;
      _notifyStateChanged();
    } catch (e) {
      _updateConnectionError('Failed to initialize: $e');
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _scanTimer?.cancel();
    _printQueueTimer?.cancel();
    _statusCallbacks.clear();
    _jobCallbacks.clear();
    super.dispose();
  }

  /// Start scanning for available devices
  Future<void> startScanning() async {
    if (_state.isScanning) return;

    _state = _state.copyWith(isScanning: true);
    _notifyStateChanged();

    try {
      // Simulate device scanning - in production would use platform channels
      await Future.delayed(const Duration(seconds: 1));

      // Mock devices for demonstration
      final devices = [
        PrinterDevice(
          id: 'device_1',
          name: 'Thermal Printer',
          type: PrinterType.thermal,
          connectionType: PrinterConnectionType.bluetooth,
          address: '00:11:22:33:44:55',
        ),
        PrinterDevice(
          id: 'device_2',
          name: 'USB Printer',
          type: PrinterType.thermal,
          connectionType: PrinterConnectionType.usb,
        ),
      ];

      _state = _state.copyWith(
        availablePrinters: devices,
        isScanning: false,
      );
      _notifyStateChanged();
    } catch (e) {
      _updateConnectionError('Scan failed: $e');
    }
  }

  /// Stop scanning
  void stopScanning() {
    _scanTimer?.cancel();
    _state = _state.copyWith(isScanning: false);
    _notifyStateChanged();
  }

  /// Connect to a printer
  Future<void> connectPrinter(PrinterDevice device) async {
    try {
      // Update selected printer
      final updated = device.copyWith(isConnected: true);
      _state = _state.copyWith(
        selectedPrinter: updated,
        isConnected: true,
        connectionError: null,
      );
      _notifyStateChanged();
    } catch (e) {
      _updateConnectionError('Connection failed: $e');
      rethrow;
    }
  }

  /// Disconnect current printer
  Future<void> disconnect() async {
    if (_state.selectedPrinter == null) return;

    try {
      _state = _state.copyWith(
        selectedPrinter: null,
        isConnected: false,
      );
      _notifyStateChanged();
    } catch (e) {
      _updateConnectionError('Disconnection failed: $e');
    }
  }

  /// Print data
  Future<void> print(List<int> data, {String? deviceId}) async {
    if (!isConnected && _state.selectedPrinter == null) {
      throw PrinterException(
        message: 'No printer connected',
        code: 'NO_PRINTER',
      );
    }

    final device = deviceId != null
        ? _state.availablePrinters.firstWhere(
          (d) => d.id == deviceId,
          orElse: () => throw PrinterException(
            message: 'Device not found',
            code: 'DEVICE_NOT_FOUND',
          ),
        )
        : _state.selectedPrinter;

    try {
      _isPrinting = true;
      notifyListeners();

      // Simulate printing - in production would send to actual device
      await Future.delayed(const Duration(milliseconds: 500));

      _isPrinting = false;
      notifyListeners();
    } catch (e) {
      _isPrinting = false;
      notifyListeners();
      throw PrinterException(
        message: 'Print failed: $e',
        originalError: e,
      );
    }
  }

  /// Queue a print job
  Future<String> queuePrintJob({
    required String receiptId,
    required List<int> escposData,
  }) async {
    final job = PrintJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      receiptId: receiptId,
      escposData: escposData,
      createdAt: DateTime.now(),
      deviceId: _state.selectedPrinter?.id,
    );

    _printQueue.add(job);
    _notifyJobStatusChanged(job);

    return job.id;
  }

  /// Get print job status
  PrintJob? getPrintJobStatus(String jobId) {
    try {
      return _printQueue.firstWhere((j) => j.id == jobId);
    } catch (_) {
      return _jobHistory[jobId];
    }
  }

  /// Cancel print job
  bool cancelPrintJob(String jobId) {
    try {
      final job = _printQueue.firstWhere((j) => j.id == jobId);
      if (job.isPending || job.isPrinting) {
        job.status = PrintJobStatus.cancelled;
        _notifyJobStatusChanged(job);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Print test page
  Future<void> printTest() async {
    if (!isConnected) {
      throw PrinterException(
        message: 'No printer connected',
        code: 'NO_PRINTER',
      );
    }

    try {
      _isPrinting = true;
      notifyListeners();

      // Simulate test print
      await Future.delayed(const Duration(milliseconds: 300));

      _isPrinting = false;
      notifyListeners();
    } catch (e) {
      _isPrinting = false;
      notifyListeners();
      throw PrinterException(
        message: 'Test print failed: $e',
        originalError: e,
      );
    }
  }

  /// Register status callback
  void onStatusChanged(PrinterStatusCallback callback) {
    _statusCallbacks.add(callback);
  }

  /// Register job callback
  void onJobStatusChanged(PrintJobCallback callback) {
    _jobCallbacks.add(callback);
  }

  /// Remove callbacks
  void removeStatusCallback(PrinterStatusCallback callback) {
    _statusCallbacks.remove(callback);
  }

  void removeJobCallback(PrintJobCallback callback) {
    _jobCallbacks.remove(callback);
  }

  // Private methods

  void _notifyStateChanged() {
    notifyListeners();
    for (final callback in _statusCallbacks) {
      callback(_state);
    }
  }

  void _notifyJobStatusChanged(PrintJob job) {
    notifyListeners();
    for (final callback in _jobCallbacks) {
      callback(job);
    }
  }

  void _updateConnectionError(String error) {
    _state = _state.copyWith(
      isScanning: false,
      connectionError: error,
    );
    _notifyStateChanged();
  }

  void _startPrintQueueProcessor() {
    _printQueueTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _processPrintQueue();
    });
  }

  Future<void> _processPrintQueue() async {
    if (_isPrinting || _printQueue.isEmpty) return;

    final job = _printQueue.firstWhere(
      (j) => j.isPending,
      orElse: () => null as dynamic,
    ) as PrintJob?;

    if (job == null) return;

    try {
      job.status = PrintJobStatus.printing;
      _notifyJobStatusChanged(job);

      // Send to printer
      await print(job.escposData, deviceId: job.deviceId);

      job.status = PrintJobStatus.completed;
      job.completedAt = DateTime.now();
      _notifyJobStatusChanged(job);

      _printQueue.removeWhere((j) => j.id == job.id);
      _jobHistory[job.id] = job;
    } catch (e) {
      job.status = PrintJobStatus.failed;
      job.errorMessage = e.toString();
      _notifyJobStatusChanged(job);

      // Keep failed jobs in queue for retry
      _printQueue.removeWhere((j) => j.id == job.id && !j.isFailed);
      _jobHistory[job.id] = job;
    }
  }
}
