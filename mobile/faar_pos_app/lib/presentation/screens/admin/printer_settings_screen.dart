import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/printer_service.dart';
import '../../../data/local/app_database.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  bool _isScanning = false;
  List<PrinterDevice> _devices = [];
  StreamSubscription<List<PrinterDevice>>? _scanSub;
  String _selectedPaperSize = '58'; // '58' or '80'
  bool _isPrintingTest = false;

  @override
  void initState() {
    super.initState();
    _selectedPaperSize = AppDatabase.instance.getSetting('printer_paper_size') ?? '58';
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    PrinterService.instance.stopScan();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _devices = [];
    });

    _scanSub?.cancel();
    _scanSub = PrinterService.instance.scanPrinters().listen(
      (devices) {
        if (mounted) {
          setState(() {
            _devices = devices;
          });
        }
      },
      onDone: () {
        if (mounted) setState(() => _isScanning = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isScanning = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bluetooth scan error: $e'),
              backgroundColor: FaarPosTheme.kDanger,
            ),
          );
        }
      },
    );
  }

  void _connect(PrinterDevice device) async {
    if (device.rawDevice == null) return;

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${device.name}...')),
    );

    final success = await PrinterService.instance.connect(device.rawDevice!);

    if (mounted) {
      if (success) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}!'),
            backgroundColor: FaarPosTheme.kSuccess,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to printer. Ensure Bluetooth is ON and printer is in range.'),
            backgroundColor: FaarPosTheme.kDanger,
          ),
        );
      }
    }
  }

  void _disconnect() async {
    HapticFeedback.lightImpact();
    await PrinterService.instance.disconnect();
    if (mounted) setState(() {});
  }

  void _sendTestPrint() async {
    final printer = PrinterService.instance.connectedPrinter;
    if (printer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please connect a Bluetooth thermal printer first'),
          backgroundColor: FaarPosTheme.kWarning,
        ),
      );
      return;
    }

    setState(() => _isPrintingTest = true);
    HapticFeedback.mediumImpact();

    final size = _selectedPaperSize == '80' ? PrinterPaperSize.mm80 : PrinterPaperSize.mm58;
    final bytes = await PrinterService.instance.generateTestReceiptBytes(paperSize: size);
    final ok = await PrinterService.instance.printBytes(bytes);

    if (mounted) {
      setState(() => _isPrintingTest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Test receipt printed successfully!' : 'Printing failed. Check printer connection.'),
          backgroundColor: ok ? FaarPosTheme.kSuccess : FaarPosTheme.kDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = PrinterService.instance.connectedPrinter;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Card(
              color: connected != null ? FaarPosTheme.kSuccess.withValues(alpha: 0.12) : FaarPosTheme.kSurfaceElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: connected != null ? FaarPosTheme.kSuccess.withValues(alpha: 0.4) : FaarPosTheme.kCardBorder,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      connected != null ? Icons.print : Icons.print_disabled,
                      color: connected != null ? FaarPosTheme.kSuccess : FaarPosTheme.kTextSecondary,
                      size: 36,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connected != null ? 'Printer Connected' : 'No Printer Connected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            connected != null ? '${connected.name} (${connected.id})' : 'Connect a thermal receipt printer via Bluetooth',
                            style: const TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (connected != null)
                      TextButton(
                        onPressed: _disconnect,
                        child: const Text('Disconnect', style: TextStyle(color: FaarPosTheme.kDanger)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Paper Size Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Printer Paper Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text(
                      'Select the thermal roll width for your receipt printer.',
                      style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: '58',
                          label: Text('58mm (2 Inch Standard)'),
                          icon: Icon(Icons.receipt_long),
                        ),
                        ButtonSegment(
                          value: '80',
                          label: Text('80mm (3 Inch Wide)'),
                          icon: Icon(Icons.receipt),
                        ),
                      ],
                      selected: {_selectedPaperSize},
                      onSelectionChanged: (set) {
                        final val = set.first;
                        setState(() => _selectedPaperSize = val);
                        AppDatabase.instance.setSetting('printer_paper_size', val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Test Print & Scan Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(_isScanning ? 'Scanning...' : 'Scan for Printers'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPrintingTest ? null : _sendTestPrint,
                    icon: const Icon(Icons.receipt_outlined),
                    label: const Text('Test Print'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Discovered Devices List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available Bluetooth Printers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (_devices.isNotEmpty)
                  Text('${_devices.length} found', style: const TextStyle(color: FaarPosTheme.kTextSecondary)),
              ],
            ),
            const SizedBox(height: 12),

            if (_devices.isEmpty && !_isScanning)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: FaarPosTheme.kSurfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FaarPosTheme.kCardBorder),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth, size: 40, color: FaarPosTheme.kTextSecondary),
                      SizedBox(height: 12),
                      Text('No Bluetooth printers discovered', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text(
                        'Turn on your thermal printer, enable pairing mode, and tap "Scan for Printers"',
                        style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _devices.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final d = _devices[index];
                  final isThisConnected = connected?.id == d.id;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isThisConnected ? FaarPosTheme.kSuccess : FaarPosTheme.kSurfaceElevated,
                        child: Icon(
                          Icons.print,
                          color: isThisConnected ? Colors.white : FaarPosTheme.kTextPrimary,
                        ),
                      ),
                      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${d.id} • RSSI: ${d.rssi} dBm'),
                      trailing: isThisConnected
                          ? const Chip(
                              label: Text('Connected', style: TextStyle(color: FaarPosTheme.kSuccess, fontSize: 11)),
                              backgroundColor: Colors.transparent,
                            )
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                minimumSize: const Size(80, 36),
                              ),
                              onPressed: () => _connect(d),
                              child: const Text('Connect'),
                            ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
