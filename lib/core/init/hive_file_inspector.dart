import 'dart:typed_data';

/// How a Hive 2.x box file is damaged, judged by the same record rules Hive
/// itself applies when it opens a box.
enum HiveDamageKind {
  /// Every record is whole and its checksum matches.
  none,

  /// Only the last write is unfinished: the last record's header or body is
  /// cut short by the end of the file (or the tail is zero-filled), and no
  /// whole record follows. Hive's crash recovery drops exactly that record.
  tornFinalRecord,

  /// The last record is whole (it ends exactly at the end of the file) but its
  /// checksum does not match: a write that DID finish has been damaged.
  badFinalRecord,

  /// A record that is not the last one is damaged: there are bytes, and
  /// usually whole records, after it. Hive's crash recovery would cut the file
  /// at the damage and drop every record after it.
  middleCorruption,
}

/// Result of [HiveFileInspector.scan]. Read-only facts about one file.
class HiveFileScan {
  final HiveDamageKind kind;

  /// File size in bytes.
  final int size;

  /// Byte offset of the first record that fails Hive's checks (where Hive's
  /// crash recovery would cut the file), or null when the file is intact.
  final int? damageOffset;

  /// Whole, checksum-valid records before [damageOffset].
  final int validRecordsBefore;

  /// Whole, checksum-valid records found after the damage by re-syncing.
  final int validRecordsAfter;

  /// False when the re-sync search after the damage stopped at its work limit,
  /// so [validRecordsAfter] is a lower bound and the damage is treated as
  /// [HiveDamageKind.middleCorruption] (the safe choice).
  final bool scanComplete;

  const HiveFileScan({
    required this.kind,
    required this.size,
    required this.damageOffset,
    required this.validRecordsBefore,
    required this.validRecordsAfter,
    required this.scanComplete,
  });

  Map<String, Object?> toJson() => {
        'damageKind': kind.name,
        'damageOffset': damageOffset,
        'validRecordsBefore': validRecordsBefore,
        'validRecordsAfter': validRecordsAfter,
        'scanComplete': scanComplete,
      };
}

/// Read-only reader of the Hive 2.2.3 file layout. It never writes.
///
/// A box file is a sequence of records:
/// `[uint32 LE length][key][value][uint32 LE CRC-32]`, where `length` counts
/// the whole record and the CRC covers every byte before it. These are the
/// exact rules of `BinaryReaderImpl.readFrame` in hive 2.2.3 for a box with
/// no encryption cipher (this app uses none).
class HiveFileInspector {
  HiveFileInspector._();

  /// Upper bound on bytes checksummed while re-syncing after damage. Past it
  /// the scan stops and reports `scanComplete: false`.
  static const int resyncWorkLimitBytes = 64 * 1024 * 1024;

  static HiveFileScan scan(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    var before = 0;
    while (offset < bytes.length) {
      final length = _validRecordAt(bytes, data, offset);
      if (length == null) break;
      before++;
      offset += length;
    }
    if (offset >= bytes.length) {
      return HiveFileScan(
        kind: HiveDamageKind.none,
        size: bytes.length,
        damageOffset: null,
        validRecordsBefore: before,
        validRecordsAfter: 0,
        scanComplete: true,
      );
    }

    final damage = offset;
    final (after, complete) = _resyncAfter(bytes, data, damage);
    return HiveFileScan(
      kind: complete ? _classify(bytes, data, damage, after) : HiveDamageKind.middleCorruption,
      size: bytes.length,
      damageOffset: damage,
      validRecordsBefore: before,
      validRecordsAfter: after,
      scanComplete: complete,
    );
  }

  static HiveDamageKind _classify(
      Uint8List bytes, ByteData data, int damage, int validAfter) {
    if (validAfter > 0) return HiveDamageKind.middleCorruption;
    final remaining = bytes.length - damage;
    // The length header itself is cut short.
    if (remaining < 4) return HiveDamageKind.tornFinalRecord;
    // A zero-filled tail: space the file system reserved for a write whose
    // data never reached the disk.
    var allZero = true;
    for (var i = damage; i < bytes.length; i++) {
      if (bytes[i] != 0) {
        allZero = false;
        break;
      }
    }
    if (allZero) return HiveDamageKind.tornFinalRecord;

    final length = data.getUint32(damage, Endian.little);
    if (length < 8) return HiveDamageKind.middleCorruption;
    // The record says it is longer than what is left: its write was cut off.
    if (length > remaining) return HiveDamageKind.tornFinalRecord;
    // Whole record, ending exactly at the end of the file, bad checksum.
    if (length == remaining) return HiveDamageKind.badFinalRecord;
    // A whole record followed by bytes that form no valid record.
    return HiveDamageKind.middleCorruption;
  }

  /// Length of the valid record starting at [offset], or null when Hive would
  /// reject it there.
  static int? _validRecordAt(Uint8List bytes, ByteData data, int offset) {
    final remaining = bytes.length - offset;
    if (remaining < 4) return null;
    final length = data.getUint32(offset, Endian.little);
    if (length < 8 || length > remaining) return null;
    final stored = data.getUint32(offset + length - 4, Endian.little);
    return crc32(bytes, offset, length - 4) == stored ? length : null;
  }

  /// Counts valid records after [damage] by trying every later offset.
  static (int, bool) _resyncAfter(Uint8List bytes, ByteData data, int damage) {
    var found = 0;
    var work = 0;
    var p = damage + 1;
    while (p <= bytes.length - 8) {
      final length = data.getUint32(p, Endian.little);
      // Cheap filters before the checksum: a plausible length and a key type
      // Hive can write (0 = uint key, 1 = UTF-8 string key).
      if (length >= 8 &&
          length <= bytes.length - p &&
          (bytes[p + 4] == 0 || bytes[p + 4] == 1)) {
        work += length;
        if (work > resyncWorkLimitBytes) return (found, false);
        final stored = data.getUint32(p + length - 4, Endian.little);
        if (crc32(bytes, p, length - 4) == stored) {
          found++;
          p += length;
          continue;
        }
      }
      p++;
    }
    return (found, true);
  }

  static final List<int> _table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  }, growable: false);

  /// Standard CRC-32 (IEEE), identical to hive 2.2.3 `Crc32.compute` with no
  /// cipher (initial crc 0).
  static int crc32(Uint8List bytes, int offset, int length) {
    var crc = 0xffffffff;
    for (var i = offset; i < offset + length; i++) {
      crc = _table[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
    }
    return crc ^ 0xffffffff;
  }
}
