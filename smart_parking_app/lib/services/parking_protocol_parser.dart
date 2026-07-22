import '../models/parking_state.dart';

/// Buffers raw incoming Bluetooth text and splits it into complete
/// newline-terminated lines. Bluetooth Classic sockets deliver bytes in
/// arbitrary chunks — a chunk boundary is NOT guaranteed to line up with
/// a message boundary, and one chunk may contain several messages.
///
/// Handles \n, \r\n and bare \r terminators. Any trailing partial line is
/// kept and prefixed onto the next chunk.
class LineBuffer {
  final StringBuffer _pending = StringBuffer();

  /// Feeds [chunk] in and returns any complete, trimmed, non-empty lines
  /// found so far. Partial trailing data stays buffered.
  List<String> add(String chunk) {
    final data = _pending.toString() + chunk;
    final complete = <String>[];

    int start = 0;
    for (int i = 0; i < data.length; i++) {
      final c = data[i];
      if (c == '\n' || c == '\r') {
        final line = data.substring(start, i).trim();
        if (line.isNotEmpty) complete.add(line);
        start = i + 1;
        // Treat \r\n as a single terminator.
        if (c == '\r' && start < data.length && data[start] == '\n') {
          start++;
          i++;
        }
      }
    }

    _pending
      ..clear()
      ..write(data.substring(start));

    return complete;
  }

  void clear() => _pending.clear();
}

/// Base type for every parsed protocol message. A sealed hierarchy keeps
/// the switch in ParkingController exhaustive and compiler-checked.
sealed class ParsedMessage {
  const ParsedMessage();
}

/// "S1:0,S2:1,S3:0,S4:1" (any order, any subset). Only the slots with a
/// syntactically valid "S<n>:<0|1>" token are included — malformed tokens
/// are silently skipped so a partially-corrupt packet still updates the
/// slots it *did* parse correctly, and never wipes out slots it couldn't
/// read this time.
class SlotStatusMessage extends ParsedMessage {
  final Map<int, bool> occupied; // slotId -> isOccupied
  const SlotStatusMessage(this.occupied);
}

/// "G:1" / "G:0"
class GateMessage extends ParsedMessage {
  final bool open;
  const GateMessage(this.open);
}

/// "LIGHT:<GREEN|YELLOW|RED>"
class LightMessage extends ParsedMessage {
  final TrafficLightState state;
  const LightMessage(this.state);
}

/// "AVAILABLE:<n>"
class AvailableCountMessage extends ParsedMessage {
  final int count;
  const AvailableCountMessage(this.count);
}

/// "OCCUPIED:<n>"
class OccupiedCountMessage extends ParsedMessage {
  final int count;
  const OccupiedCountMessage(this.count);
}

/// "L1:<text>"
class LcdLine1Message extends ParsedMessage {
  final String text;
  const LcdLine1Message(this.text);
}

/// "L2:<text>"
class LcdLine2Message extends ParsedMessage {
  final String text;
  const LcdLine2Message(this.text);
}

/// "E:<name>" — raw text after E: is handed to ParkingEvent.fromRaw()
/// by the controller, this layer just extracts the payload.
class EventMessage extends ParsedMessage {
  final String raw;
  const EventMessage(this.raw);
}

/// Bare "PONG" reply to a PING command.
class PongMessage extends ParsedMessage {
  const PongMessage();
}

/// Anything that doesn't match a known prefix/shape. Carried through
/// (rather than dropped silently) so the diagnostics screen can show it.
class UnknownMessage extends ParsedMessage {
  final String raw;
  const UnknownMessage(this.raw);
}

class ParkingProtocolParser {
  ParkingProtocolParser._();

  static final RegExp _slotToken = RegExp(r'^S(\d+):([01])$');

  /// Parses a single already-trimmed line into a [ParsedMessage].
  /// Pure function, no state — fully unit-testable in isolation from
  /// Bluetooth I/O.
  static ParsedMessage parseLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return UnknownMessage(rawLine);

    if (line == 'PONG') return const PongMessage();

    if (line.startsWith('GATE:')) {
      final value = line.substring(5).trim().toUpperCase();
      if (value == 'OPEN') return const GateMessage(true);
      if (value == 'CLOSED') return const GateMessage(false);
      return UnknownMessage(rawLine);
    }

    if (line.startsWith('G:')) {
      final value = line.substring(2).trim();
      if (value == '1') return const GateMessage(true);
      if (value == '0') return const GateMessage(false);
      return UnknownMessage(rawLine);
    }

    if (line.startsWith('LIGHT:')) {
      final value = line.substring(6).trim().toUpperCase();
      switch (value) {
        case 'GREEN':
          return const LightMessage(TrafficLightState.green);
        case 'YELLOW':
          return const LightMessage(TrafficLightState.yellow);
        case 'RED':
          return const LightMessage(TrafficLightState.red);
      }
      return UnknownMessage(rawLine);
    }

    if (line.startsWith('AVAILABLE:')) {
      final parsed = int.tryParse(line.substring(10).trim());
      if (parsed != null) return AvailableCountMessage(parsed);
      return UnknownMessage(rawLine);
    }

    if (line.startsWith('OCCUPIED:')) {
      final parsed = int.tryParse(line.substring(9).trim());
      if (parsed != null) return OccupiedCountMessage(parsed);
      return UnknownMessage(rawLine);
    }

    if (line.startsWith('L1:')) return LcdLine1Message(line.substring(3));
    if (line.startsWith('L2:')) return LcdLine2Message(line.substring(3));

    if (line.startsWith('E:')) return EventMessage(line.substring(2).trim());

    // Slot status packet: one or more comma-separated "S<n>:<0|1>" tokens.
    // Order-independent, tolerant of malformed individual tokens.
    if (RegExp(r'^S\d+:').hasMatch(line)) {
      final tokens = line.split(',');
      final Map<int, bool> parsed = {};

      for (final token in tokens) {
        final match = _slotToken.firstMatch(token.trim());
        if (match == null) continue; // skip invalid token, keep the rest
        final id = int.parse(match.group(1)!);
        parsed[id] = match.group(2) == '1';
      }

      if (parsed.isNotEmpty) return SlotStatusMessage(parsed);
      return UnknownMessage(rawLine);
    }

    return UnknownMessage(rawLine);
  }
}
