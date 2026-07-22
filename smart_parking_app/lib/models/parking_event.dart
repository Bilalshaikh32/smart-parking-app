/// Every E: event the Arduino firmware can send, plus [unknown] as a safe
/// fallback for anything the firmware might send in the future that this
/// app version doesn't recognize yet (never crash on unknown events).
enum ParkingEventType {
  entry,
  exit,
  entryDenied,
  manualOpen,
  manualClose,
  slotOccupied,
  slotAvailable,
  slotChecking,
  unknown,
}

class ParkingEvent {
  final ParkingEventType type;
  final int? slotId; // set only for SLOTn_* events
  final String raw; // original text after "E:"
  final DateTime time;

  const ParkingEvent({
    required this.type,
    required this.raw,
    required this.time,
    this.slotId,
  });

  String get label {
    switch (type) {
      case ParkingEventType.entry:
        return 'Vehicle entering';
      case ParkingEventType.exit:
        return 'Vehicle exiting';
      case ParkingEventType.entryDenied:
        return 'Parking full — entry denied';
      case ParkingEventType.manualOpen:
        return 'Manual gate opening';
      case ParkingEventType.manualClose:
        return 'Manual gate closing';
      case ParkingEventType.slotOccupied:
        return 'Slot $slotId occupied';
      case ParkingEventType.slotAvailable:
        return 'Slot $slotId available';
      case ParkingEventType.slotChecking:
        return 'Slot $slotId checking...';
      case ParkingEventType.unknown:
        return 'Event: $raw';
    }
  }

  bool get isWarning =>
      type == ParkingEventType.entryDenied || type == ParkingEventType.unknown;

  bool get isPositive =>
      type == ParkingEventType.exit ||
      type == ParkingEventType.slotAvailable ||
      type == ParkingEventType.manualClose;

  static final RegExp _slotEventPattern =
      RegExp(r'^SLOT(\d+)_(OCCUPIED|AVAILABLE|CHECKING)$');

  /// Parses the text that comes after "E:" (already trimmed/uppercased by
  /// the firmware). Never throws — unrecognized text becomes [unknown].
  factory ParkingEvent.fromRaw(String raw, {DateTime? time}) {
    final t = time ?? DateTime.now();
    final clean = raw.trim();

    switch (clean) {
      case 'ENTRY':
        return ParkingEvent(type: ParkingEventType.entry, raw: clean, time: t);
      case 'EXIT':
        return ParkingEvent(type: ParkingEventType.exit, raw: clean, time: t);
      case 'ENTRY_DENIED':
        return ParkingEvent(
            type: ParkingEventType.entryDenied, raw: clean, time: t);
      case 'MANUAL_OPEN':
        return ParkingEvent(
            type: ParkingEventType.manualOpen, raw: clean, time: t);
      case 'MANUAL_CLOSE':
        return ParkingEvent(
            type: ParkingEventType.manualClose, raw: clean, time: t);
    }

    final match = _slotEventPattern.firstMatch(clean);
    if (match != null) {
      final slotId = int.tryParse(match.group(1)!);
      switch (match.group(2)) {
        case 'OCCUPIED':
          return ParkingEvent(
              type: ParkingEventType.slotOccupied,
              raw: clean,
              time: t,
              slotId: slotId);
        case 'AVAILABLE':
          return ParkingEvent(
              type: ParkingEventType.slotAvailable,
              raw: clean,
              time: t,
              slotId: slotId);
        case 'CHECKING':
          return ParkingEvent(
              type: ParkingEventType.slotChecking,
              raw: clean,
              time: t,
              slotId: slotId);
      }
    }

    return ParkingEvent(type: ParkingEventType.unknown, raw: clean, time: t);
  }
}
