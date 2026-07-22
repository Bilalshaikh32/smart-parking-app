import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/bluetooth_controller.dart';
import '../controllers/parking_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shows raw received lines, sent commands, and connection state changes.
/// Internal exception details are never shown here — only the same
/// human-readable messages already surfaced elsewhere in the app.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  Color _tagColor(String tag) {
    switch (tag) {
      case 'RX':
        return AppColors.available;
      case 'TX':
        return AppColors.bluetooth;
      case 'ERR':
        return AppColors.occupied;
      default:
        return AppColors.mutedForeground;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bt = context.watch<BluetoothController>();
    final parking = context.watch<ParkingController>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text('Diagnostics', style: AppTheme.display(size: 17)),
          bottom: TabBar(
            indicatorColor: AppColors.bluetooth,
            labelColor: AppColors.bluetooth,
            unselectedLabelColor: AppColors.mutedForeground,
            tabs: const [Tab(text: 'RAW LOG'), Tab(text: 'EVENTS')],
          ),
          actions: [
            IconButton(
              onPressed: () => bt.clearDiagnosticLog(),
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.occupied),
              tooltip: 'Clear log',
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.surface,
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  _InfoChip(label: 'STATE', value: bt.connectionState.name.toUpperCase()),
                  _InfoChip(label: 'DEVICE', value: bt.connectedDeviceName ?? '--'),
                  _InfoChip(label: 'PERMISSIONS', value: bt.permissionsGranted ? 'GRANTED' : 'NOT GRANTED'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RawLogView(bt: bt, tagColor: _tagColor),
                  _EventsView(events: parking.eventLog),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RawLogView extends StatelessWidget {
  final BluetoothController bt;
  final Color Function(String) tagColor;
  const _RawLogView({required this.bt, required this.tagColor});

  @override
  Widget build(BuildContext context) {
    if (bt.diagnosticLog.isEmpty) {
      return Center(child: Text('No log entries yet.', style: AppTheme.mono(size: 12)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bt.diagnosticLog.length,
      itemBuilder: (context, i) {
        final entry = bt.diagnosticLog[i];
        final t = entry.time;
        final timeLabel =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeLabel, style: AppTheme.mono(size: 10, color: AppColors.mutedForeground)),
              const SizedBox(width: 8),
              Text('[${entry.tag}]',
                  style: AppTheme.mono(size: 10, weight: FontWeight.w700, color: tagColor(entry.tag))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(entry.text, style: AppTheme.mono(size: 11, color: AppColors.foreground)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventsView extends StatelessWidget {
  final List<dynamic> events;
  const _EventsView({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(child: Text('No events yet.', style: AppTheme.mono(size: 12)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        final t = e.time as DateTime;
        final timeLabel =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
        final color = e.isWarning ? AppColors.occupied : (e.isPositive ? AppColors.available : AppColors.bluetooth);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 10),
              Text(timeLabel, style: AppTheme.mono(size: 10, color: AppColors.mutedForeground)),
              const SizedBox(width: 10),
              Expanded(child: Text(e.label as String, style: AppTheme.mono(size: 12, color: AppColors.foreground))),
            ],
          ),
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.mono(size: 9, color: AppColors.mutedForeground)),
        Text(value, style: AppTheme.mono(size: 11, weight: FontWeight.w700)),
      ],
    );
  }
}
