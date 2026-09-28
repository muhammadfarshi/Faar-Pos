import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';

import '../services/talker_service.dart';
import '../../data/local/app_database.dart';
import '../../domain/entities/transaction_entity.dart';

enum PrinterPaperSize { mm58, mm80 }

class PrinterDevice {
  final String name;
  final String id; // MAC address or remote ID
  final int rssi;
  final BluetoothDevice? rawDevice;

  PrinterDevice({
    required this.name,
    required this.id,
    this.rssi = 0,
    this.rawDevice,
  });
}

class PrinterService {
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  bool _isConnecting = false;

  PrinterDevice? get connectedPrinter => _connectedDevice != null
      ? PrinterDevice(
          name: _connectedDevice!.platformName.isNotEmpty
              ? _connectedDevice!.platformName
              : 'Thermal Printer',
          id: _connectedDevice!.remoteId.str,
          rawDevice: _connectedDevice,
        )
      : null;

  bool get isConnected => _connectedDevice != null && _writeCharacteristic != null;

  /// Stream of discovered Bluetooth devices
  Stream<List<PrinterDevice>> scanPrinters({Duration timeout = const Duration(seconds: 8)}) async* {
    try {
      final isAvailable = await FlutterBluePlus.isSupported;
      if (!isAvailable) {
        AppLog.warning('Bluetooth is not available on this device');
        yield [];
        return;
      }

      await FlutterBluePlus.startScan(timeout: timeout);

      yield* FlutterBluePlus.scanResults.map((results) {
        return results
            .where((r) => r.device.platformName.isNotEmpty)
            .map((r) => PrinterDevice(
                  name: r.device.platformName,
                  id: r.device.remoteId.str,
                  rssi: r.rssi,
                  rawDevice: r.device,
                ))
            .toList();
      });
    } catch (e, st) {
      AppLog.error('Error scanning for Bluetooth printers', e, st);
      yield [];
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      AppLog.warning('Error stopping BT scan: $e');
    }
  }

  /// Connect to a specific Bluetooth thermal printer
  Future<bool> connect(BluetoothDevice device) async {
    if (_isConnecting) return false;
    _isConnecting = true;

    try {
      AppLog.info('Connecting to printer: ${device.platformName} (${device.remoteId.str})');
      await device.connect(autoConnect: false, timeout: const Duration(seconds: 10));

      _connectedDevice = device;

      // Discover writable GATT characteristic
      final services = await device.discoverServices();
      BluetoothCharacteristic? targetChar;

      for (final service in services) {
        for (final char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            targetChar = char;
            break;
          }
        }
        if (targetChar != null) break;
      }

      if (targetChar == null) {
        AppLog.error('No writable characteristic found on printer: ${device.platformName}');
        await device.disconnect();
        _connectedDevice = null;
        _isConnecting = false;
        return false;
      }

      _writeCharacteristic = targetChar;
      _isConnecting = false;

      // Save connected printer to settings
      AppDatabase.instance.setSetting('printer_mac', device.remoteId.str);
      AppDatabase.instance.setSetting('printer_name', device.platformName);

      AppLog.info('Successfully connected to thermal printer!');
      return true;
    } catch (e, st) {
      AppLog.error('Failed to connect to printer', e, st);
      _isConnecting = false;
      _connectedDevice = null;
      _writeCharacteristic = null;
      return false;
    }
  }

  /// Disconnect current printer
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      AppLog.warning('Error disconnecting printer: $e');
    } finally {
      _connectedDevice = null;
      _writeCharacteristic = null;
    }
  }

  /// Send raw bytes to connected thermal printer
  Future<bool> printBytes(List<int> bytes) async {
    if (!isConnected || _writeCharacteristic == null) {
      AppLog.warning('Cannot print: No Bluetooth thermal printer connected');
      return false;
    }

    try {
      // Chunk transmission to avoid exceeding BLE MTU limit (typically 128 or 256 bytes)
      const chunkSize = 120;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        await _writeCharacteristic!.write(chunk, withoutResponse: true);
        await Future.delayed(const Duration(milliseconds: 15));
      }
      AppLog.info('Successfully printed ${bytes.length} bytes to thermal printer');
      return true;
    } catch (e, st) {
      AppLog.error('Error writing bytes to printer', e, st);
      return false;
    }
  }

  /// Generate ESC/POS bytes for a full sale transaction
  Future<List<int>> generateReceiptBytes(
    TransactionEntity tx, {
    PrinterPaperSize paperSize = PrinterPaperSize.mm58,
  }) async {
    final profile = await CapabilityProfile.load();
    final pSize = paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(pSize, profile);
    final bytes = <int>[];

    final storeName = AppDatabase.instance.getSetting('store_name') ?? 'FAAR POS FLAGSHIP STORE';
    final storeGstin = AppDatabase.instance.getSetting('store_gstin') ?? '32AAACB1234F1Z0';
    final storeAddress = AppDatabase.instance.getSetting('store_address') ?? 'Kochi, Kerala';
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

    // Header
    bytes.addAll(generator.text(
      storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(generator.text(
      storeAddress,
      styles: const PosStyles(align: PosAlign.center, bold: false),
    ));
    bytes.addAll(generator.text(
      'GSTIN: $storeGstin',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));
    bytes.addAll(generator.hr());

    // Invoice Meta
    bytes.addAll(generator.text('INVOICE: ${tx.receiptNo}', styles: const PosStyles(bold: true)));
    bytes.addAll(generator.text('DATE:    ${dateFormat.format(tx.createdAt)}'));
    if (tx.customerName != null && tx.customerName!.isNotEmpty) {
      bytes.addAll(generator.text('BUYER:   ${tx.customerName}'));
    }
    bytes.addAll(generator.text('PAYMENT: ${tx.paymentMethod.toUpperCase()}'));
    bytes.addAll(generator.hr());

    // Table Header
    if (paperSize == PrinterPaperSize.mm80) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Total', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]));
    } else {
      bytes.addAll(generator.row([
        PosColumn(text: 'Item', width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.hr());

    // Items
    for (final item in tx.items) {
      if (paperSize == PrinterPaperSize.mm80) {
        bytes.addAll(generator.row([
          PosColumn(text: item.productNameSnapshot, width: 6),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.unitPrice.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.lineTotal.toStringAsFixed(2), width: 2, styles: const PosStyles(align: PosAlign.right)),
        ]));
      } else {
        bytes.addAll(generator.row([
          PosColumn(text: item.productNameSnapshot, width: 7),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.right)),
          PosColumn(text: item.lineTotal.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]));
      }
    }
    bytes.addAll(generator.hr());

    // Summary
    bytes.addAll(generator.row([
      PosColumn(text: 'Taxable Amount:', width: 7),
      PosColumn(text: 'Rs. ${tx.totalBaseAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'GST Total Tax:', width: 7),
      PosColumn(text: 'Rs. ${tx.totalTaxAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
    ]));
    if (tx.totalDiscountAmount.toDouble() > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Discount:', width: 7),
        PosColumn(text: '-Rs. ${tx.totalDiscountAmount.toStringAsFixed(2)}', width: 5, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }
    bytes.addAll(generator.hr());

    // Grand Total
    bytes.addAll(generator.row([
      PosColumn(text: 'GRAND TOTAL:', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
      PosColumn(
        text: 'Rs. ${tx.grandTotal.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
      ),
    ]));

    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Thank you for your business!', styles: const PosStyles(align: PosAlign.center, bold: true)));
    bytes.addAll(generator.text('Goods once sold will not be returned', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }

  /// Generate a sample test receipt
  Future<List<int>> generateTestReceiptBytes({PrinterPaperSize paperSize = PrinterPaperSize.mm58}) async {
    final profile = await CapabilityProfile.load();
    final pSize = paperSize == PrinterPaperSize.mm80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(pSize, profile);
    final bytes = <int>[];

    bytes.addAll(generator.text(
      'FAAR POS TEST PRINT',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text('Printer is properly configured!', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text('Paper: ${paperSize == PrinterPaperSize.mm80 ? "80mm" : "58mm"}', styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.text(DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()), styles: const PosStyles(align: PosAlign.center)));
    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}
