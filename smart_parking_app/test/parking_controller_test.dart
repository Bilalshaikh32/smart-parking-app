import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_system/controllers/parking_controller.dart';
import 'package:smart_parking_system/models/parking_state.dart';
import 'package:smart_parking_system/services/parking_protocol_parser.dart';

void main() {
  group('ParkingController', () {
    test('slots start as unknown before any live data arrives', () {
      final c = ParkingController();
      expect(c.availableCount, 0);
      expect(c.occupiedCount, 0);
      expect(c.lastValidUpdate, isNull);
    });

    test('full slot packet updates counts correctly', () {
      final c = ParkingController();
      c.applyMessage(const SlotStatusMessage({1: false, 2: true, 3: false, 4: true}));
      expect(c.availableCount, 2);
      expect(c.occupiedCount, 2);
      expect(c.lastValidUpdate, isNotNull);
    });

    test('10. a slot in "checking" state still counts as occupied, not available', () {
      final c = ParkingController();
      c.applyMessage(const SlotStatusMessage({1: false, 2: false, 3: false, 4: false}));
      expect(c.availableCount, 4);

      c.applyMessage(const EventMessage('SLOT1_CHECKING'));

      expect(c.occupiedCount, 1); // slot 1 now counts as occupied
      expect(c.availableCount, 3); // and NOT as available
    });

    test('a confirmed SLOTn_AVAILABLE event clears checking and frees the slot', () {
      final c = ParkingController();
      c.applyMessage(const SlotStatusMessage({1: true, 2: false, 3: false, 4: false}));
      c.applyMessage(const EventMessage('SLOT1_CHECKING'));
      expect(c.occupiedCount, 1);

      c.applyMessage(const EventMessage('SLOT1_AVAILABLE'));
      expect(c.occupiedCount, 0);
      expect(c.availableCount, 4);
    });

    test('malformed/empty slot packet preserves previous valid state', () {
      final c = ParkingController();
      c.applyMessage(const SlotStatusMessage({1: true, 2: false, 3: true, 4: false}));
      expect(c.occupiedCount, 2);

      // Simulates parseLine returning UnknownMessage for garbage input —
      // applyMessage should simply ignore it.
      c.applyMessage(const UnknownMessage('GARBAGE'));
      expect(c.occupiedCount, 2);
    });

    test('gate state only updates from a real G: message, not from button press', () {
      final c = ParkingController();
      expect(c.gateState, GateState.unknown);

      c.markGateCommandSent();
      expect(c.gateState, GateState.commandSent);

      // Still commandSent until Arduino actually confirms:
      expect(c.gateState, isNot(GateState.open));

      c.applyMessage(const GateMessage(true));
      expect(c.gateState, GateState.open);
    });

    test('unrecognized E: event does not throw and is stored as unknown', () {
      final c = ParkingController();
      expect(() => c.applyMessage(const EventMessage('SOME_FUTURE_EVENT')), returnsNormally);
      expect(c.latestEvent, isNotNull);
    });

    test('resetToUnknown clears live data so stale state is never shown as current', () {
      final c = ParkingController();
      c.applyMessage(const SlotStatusMessage({1: true, 2: true, 3: true, 4: true}));
      expect(c.lastValidUpdate, isNotNull);

      c.resetToUnknown();
      expect(c.lastValidUpdate, isNull);
      expect(c.availableCount, 0);
      expect(c.occupiedCount, 0);
    });

    test('LCD lines preserve full text after prefix', () {
      final c = ParkingController();
      c.applyMessage(const LcdLine1Message('Parking FULL'));
      c.applyMessage(const LcdLine2Message('Free:0/4'));
      expect(c.lcdLine1, 'Parking FULL');
      expect(c.lcdLine2, 'Free:0/4');
    });
  });
}
