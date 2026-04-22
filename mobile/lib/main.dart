import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/db/local_db.dart';
import 'core/services/printer/printer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await LocalDb.openAll();

  // Initialize printer service
  final printerService = PrinterService();
  await printerService.initialize();

  runApp(const ProviderScope(child: TillProApp()));
}
