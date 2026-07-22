import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/parking_event.dart';
import '../models/parking_slot.dart';
import '../models/parking_state.dart';
import '../services/parking_protocol_parser.dart';

/// Owns pure parking-domain state (slots, gate, LCD preview, event log)
/// and applies [ParsedMessage]s produced by [BluetoothController]. The
/// Arduino is always the source of truth — this class never guesses slot
/// occupancy from gate events, it only reacts to real S1..S4 / E:SLOTn_*
/// packets.
class ParkingController extends ChangeNotifier {
  List<ParkingSlot> slots =
      List.generate(kTotalSlots, (i) => ParkingSlot.initial(i + 1));

  GateState gateState = GateState.unknown;
  TrafficLightState lightState = TrafficLightState.unknown;
  int? reportedAvailableCount;
  int? reportedOccupiedCount;
  String lcdLine1 = 'SMART PARKING';
  String lcdLine2 = 'Waiting for data...';
  ParkingEvent? latestEvent;
  final List<ParkingEvent> eventLog = [];

  DateTime? lastValidUpdate;
  String? lastPingRoundTrip; // human text, e.g. "Ping OK"

  final Map<int, Timer> _checkingTimeouts = {};
  static const _checkingMaxDuration = Duration(seconds: 5);

  int get availableCount =>
      slots.where((s) => s.countsAsAvailable).length;
  int get occupiedCount => slots.where((s) => s.countsAsOccupied).length;
  int get unknownCount =>
      slots.where((s) => s.state == SlotState.unknown).length;

  bool get isDataStale {
    if (lastValidUpdate == null) return true;
    return DateTime.now().difference(lastValidUpdate!) > kStaleDataThreshold;
  }

  bool get isParkingFull =>
      lastValidUpdate != null && availableCount == 0 && unknownCount == 0;

  TrafficLightState get effectiveLightState {
    if (gateState == GateState.commandSent) {
      return TrafficLightState.yellow;
    }
    if (lightState != TrafficLightState.unknown) {
      return lightState;
    }
    if (lastValidUpdate == null) {
      return TrafficLightState.unknown;
    }
    return availableCount == 0 ? TrafficLightState.red : TrafficLightState.green;
  }

  /// Resets everything to "no live data yet" — called on disconnect so a
  /// stale snapshot is never shown as if it were current.
  void resetToUnknown() {
    for (final t in _checkingTimeouts.values) {
      t.cancel();
    }
    _checkingTimeouts.clear();
    slots = List.generate(kTotalSlots, (i) => ParkingSlot.initial(i + 1));
    gateState = GateState.unknown;
    lightState = TrafficLightState.unknown;
    reportedAvailableCount = null;
    reportedOccupiedCount = null;
    lcdLine1 = 'SMART PARKING';
    lcdLine2 = 'Disconnected';
    lastValidUpdate = null;
    notifyListeners();
  }

  /// Call immediately after tapping Open/Close, BEFORE the Arduino
  /// confirms. Keeps the UI honest that the command was sent, not applied.
  void markGateCommandSent() {
    gateState = GateState.commandSent;
    notifyListeners();
  }

  void applyMessage(ParsedMessage message) {
    switch (message) {
      case SlotStatusMessage(occupied: final occupied):
        _applySlotStatus(occupied);
      case GateMessage(open: final open):
        gateState = open ? GateState.open : GateState.closed;
        _touchLastUpdate();
      case LightMessage(state: final state):
        lightState = state;
        _touchLastUpdate();
      case AvailableCountMessage(count: final count):
        reportedAvailableCount = count;
        _touchLastUpdate();
      case OccupiedCountMessage(count: final count):
        reportedOccupiedCount = count;
        _touchLastUpdate();
      case LcdLine1Message(text: final text):
        lcdLine1 = text;
        _touchLastUpdate();
      case LcdLine2Message(text: final text):
        lcdLine2 = text;
        _touchLastUpdate();
      case EventMessage(raw: final raw):
        _applyEvent(raw);
      case PongMessage():
        lastPingRoundTrip = 'Ping OK · ${_timeLabel(DateTime.now())}';
        _touchLastUpdate();
      case UnknownMessage():
        break; // logged already by BluetoothController's diagnostics
    }
    notifyListeners();
  }

  void _touchLastUpdate() {
    lastValidUpdate = DateTime.now();
  }

  void _applySlotStatus(Map<int, bool> occupiedById) {
    if (occupiedById.isEmpty) return; // malformed packet: keep previous state

    final updated = <ParkingSlot>[];
    for (final slot in slots) {
      if (!occupiedById.containsKey(slot.id)) {
        // This packet didn't mention this slot — preserve previous state.
        updated.add(slot);
        continue;
      }

      final isOccupied = occupiedById[slot.id]!;
      final newState = isOccupied ? SlotState.occupied : SlotState.available;

      // A confirmed S1/S2/S3/S4 packet is the definitive source of truth
      // and immediately clears any pending "checking" timeout.
      _checkingTimeouts.remove(slot.id)?.cancel();

      if (slot.state != newState) {
        updated.add(slot.copyWith(state: newState, since: DateTime.now()));
      } else {
        updated.add(slot);
      }
    }

    slots = updated;
    _touchLastUpdate();
  }

  void _applyEvent(String raw) {
    final event = ParkingEvent.fromRaw(raw);
    latestEvent = event;
    eventLog.insert(0, event);
    if (eventLog.length > kMaxEventLogEntries) eventLog.removeLast();

    if (event.type == ParkingEventType.slotChecking && event.slotId != null) {
      _setSlotChecking(event.slotId!);
    } else if (event.type == ParkingEventType.slotOccupied &&
        event.slotId != null) {
      _checkingTimeouts.remove(event.slotId)?.cancel();
      _setSlotState(event.slotId!, SlotState.occupied);
    } else if (event.type == ParkingEventType.slotAvailable &&
        event.slotId != null) {
      _checkingTimeouts.remove(event.slotId)?.cancel();
      _setSlotState(event.slotId!, SlotState.available);
    }

    _touchLastUpdate();
  }

  void _setSlotChecking(int slotId) {
    _setSlotState(slotId, SlotState.checking);

    // Safety net: if Arduino never sends a final S1..S4 confirmation
    // within ~5s (its own AVAILABLE_CONFIRM_TIME), fall back to
    // "occupied" locally rather than leaving the UI stuck on "checking".
    _checkingTimeouts.remove(slotId)?.cancel();
    _checkingTimeouts[slotId] = Timer(_checkingMaxDuration, () {
      final idx = slots.indexWhere((s) => s.id == slotId);
      if (idx != -1 && slots[idx].state == SlotState.checking) {
        _setSlotState(slotId, SlotState.occupied);
        notifyListeners();
      }
    });
  }

  void _setSlotState(int slotId, SlotState state) {
    slots = [
      for (final s in slots)
        if (s.id == slotId) s.copyWith(state: state, since: DateTime.now()) else s,
    ];
  }

  String _timeLabel(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    for (final t in _checkingTimeouts.values) {
      t.cancel();
    }
    super.dispose();
  }
}
