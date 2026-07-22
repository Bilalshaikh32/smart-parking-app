import 'package:flutter_test/flutter_test.dart';
import 'package:smart_parking_system/services/parking_protocol_parser.dart';

void main() {
  group('LineBuffer', () {
    test('1. full slot packet in a single chunk', () {
      final buf = LineBuffer();
      final lines = buf.add('S1:0,S2:1,S3:0,S4:1\n');
      expect(lines, ['S1:0,S2:1,S3:0,S4:1']);
    });

    test('2. partial packet split across multiple byte chunks', () {
      final buf = LineBuffer();
      final first = buf.add('S1:0,S2:');
      expect(first, isEmpty); // no complete line yet

      final second = buf.add('1,S3:0,S4:1\nG:0\nL1:Available:2\n');
      expect(second, [
        'S1:0,S2:1,S3:0,S4:1',
        'G:0',
        'L1:Available:2',
      ]);
    });

    test('3. multiple messages arriving in one chunk', () {
      final buf = LineBuffer();
      final lines = buf.add('S1:0,S2:1,S3:0,S4:1\nG:1\nE:ENTRY\n');
      expect(lines, ['S1:0,S2:1,S3:0,S4:1', 'G:1', 'E:ENTRY']);
    });

    test('handles \\r\\n line endings', () {
      final buf = LineBuffer();
      final lines = buf.add('G:1\r\nG:0\r\n');
      expect(lines, ['G:1', 'G:0']);
    });

    test('handles bare \\r line endings', () {
      final buf = LineBuffer();
      final lines = buf.add('G:1\rG:0\r');
      expect(lines, ['G:1', 'G:0']);
    });

    test('trims extra spaces and ignores empty lines', () {
      final buf = LineBuffer();
      final lines = buf.add('  G:1  \n\n\n   \nG:0\n');
      expect(lines, ['G:1', 'G:0']);
    });

    test('a message split across three separate chunks reconstructs correctly', () {
      final buf = LineBuffer();
      expect(buf.add('S1'), isEmpty);
      expect(buf.add(':0,S2:1'), isEmpty);
      expect(buf.add(',S3:0,S4:1\n'), ['S1:0,S2:1,S3:0,S4:1']);
    });
  });

  group('ParkingProtocolParser.parseLine', () {
    test('4. gate packets', () {
      expect(ParkingProtocolParser.parseLine('G:1'), isA<GateMessage>());
      expect((ParkingProtocolParser.parseLine('G:1') as GateMessage).open, true);
      expect((ParkingProtocolParser.parseLine('G:0') as GateMessage).open, false);
    });

    test('5. LCD packets preserve full text after prefix', () {
      final l1 = ParkingProtocolParser.parseLine('L1:Parking FULL') as LcdLine1Message;
      expect(l1.text, 'Parking FULL');

      final l2 = ParkingProtocolParser.parseLine('L2:Free:0/4') as LcdLine2Message;
      expect(l2.text, 'Free:0/4');
    });

    test('6. event packets', () {
      final e = ParkingProtocolParser.parseLine('E:ENTRY_DENIED') as EventMessage;
      expect(e.raw, 'ENTRY_DENIED');
    });

    test('1 (again). full slot packet parses every slot correctly', () {
      final msg = ParkingProtocolParser.parseLine('S1:0,S2:1,S3:0,S4:1') as SlotStatusMessage;
      expect(msg.occupied, {1: false, 2: true, 3: false, 4: true});
    });

    test('slot packet supports any order', () {
      final msg = ParkingProtocolParser.parseLine('S4:1,S1:0,S3:0,S2:1') as SlotStatusMessage;
      expect(msg.occupied, {4: true, 1: false, 3: false, 2: true});
    });

    test('7. malformed slot packet: invalid token skipped, valid tokens kept', () {
      final msg = ParkingProtocolParser.parseLine('S1:0,S2:X,S3:9,S4:1') as SlotStatusMessage;
      expect(msg.occupied, {1: false, 4: true});
    });

    test('completely malformed slot packet returns UnknownMessage (no crash)', () {
      expect(ParkingProtocolParser.parseLine('S1:X,S2:Y'), isA<UnknownMessage>());
    });

    test('8. totally unknown packet does not crash', () {
      expect(ParkingProtocolParser.parseLine('GARBAGE_DATA_!!!'), isA<UnknownMessage>());
      expect(ParkingProtocolParser.parseLine(''), isA<UnknownMessage>());
    });

    test('PONG response', () {
      expect(ParkingProtocolParser.parseLine('PONG'), isA<PongMessage>());
    });

    test('9. checking event parses with correct slot id', () {
      final e = ParkingProtocolParser.parseLine('E:SLOT2_CHECKING') as EventMessage;
      expect(e.raw, 'SLOT2_CHECKING');
    });

    test('duplicate slot values in one packet: last one wins, does not crash', () {
      final msg = ParkingProtocolParser.parseLine('S1:0,S1:1') as SlotStatusMessage;
      expect(msg.occupied[1], true);
    });

    test('missing slot values (only some slots present) parses what is there', () {
      final msg = ParkingProtocolParser.parseLine('S2:1') as SlotStatusMessage;
      expect(msg.occupied, {2: true});
    });
  });
}
