/// A parking slot's confirmed display state.
///
/// - [available]: sensor confirms the slot is empty.
/// - [occupied]: sensor confirms a vehicle is present.
/// - [checking]: detection was briefly lost; Arduino is still inside the
///   5-second confirmation window. STILL COUNTS AS OCCUPIED.
/// - [unknown]: no valid packet received yet for this slot (e.g. right
///   after app launch, before the first S1/S2/S3/S4 packet arrives).
enum SlotState { available, occupied, checking, unknown }

class ParkingSlot {
  final int id; // 1..4
  final SlotState state;
  final DateTime since;

  const ParkingSlot({
    required this.id,
    required this.state,
    required this.since,
  });

  ParkingSlot copyWith({SlotState? state, DateTime? since}) => ParkingSlot(
        id: id,
        state: state ?? this.state,
        since: since ?? this.since,
      );

  /// Per the spec's counting rules: available -> free, everything else
  /// (occupied, checking, unknown) counts as NOT available.
  bool get countsAsAvailable => state == SlotState.available;

  /// checking + occupied both count toward the occupied total.
  bool get countsAsOccupied =>
      state == SlotState.occupied || state == SlotState.checking;

  static ParkingSlot initial(int id) =>
      ParkingSlot(id: id, state: SlotState.unknown, since: DateTime.now());
}

/// Formats a Duration like "1h 4m", "12m 30s", "45s".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}
