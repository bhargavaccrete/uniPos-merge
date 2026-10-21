import 'package:hive/hive.dart';
import '../../../core/constants/hive_box_names.dart';
import '../../../data/models/common/customer_model_125.dart';

/// Generates customer ids as `CUST-<6_DIGIT_SEQUENCE>`, e.g. "CUST-000042",
/// replacing the opaque UUID v4 that used to be shown to shopkeepers.
///
/// Mirrors [SkuGeneratorService]: a single monotonic counter in the shared
/// `appCounters` box. Monotonic matters — `customers.length + 1` would reissue
/// a number after a deletion, and since the id is the Hive key, a repeat would
/// make `box.put` silently overwrite an existing customer.
///
/// The counter is included in backup/restore (`unified_backup_service` exports
/// and re-imports `appCounters`), so restoring a backup doesn't rewind the
/// sequence.
///
/// Only call this when creating a genuinely new customer. Restore paths must
/// keep the id the record already carries — regenerating would orphan every
/// sale whose `customerId` points at the old value.
class CustomerIdGeneratorService {
  static const _sequenceKey = 'lastCustomerSequence';
  static const _prefix = 'CUST';

  Box get _counters => Hive.box(HiveBoxNames.appCounters);
  Box<Customer> get _customers => Hive.box<Customer>(HiveBoxNames.customer);

  Future<String> generate() async {
    var next = (_counters.get(_sequenceKey, defaultValue: 0) as int) + 1;
    var id = _format(next);

    // Belt-and-braces: if the counter ever lags the box (hand-edited data, a
    // partial restore), skip past anything already taken rather than
    // overwriting a real customer.
    while (_customers.containsKey(id)) {
      next++;
      id = _format(next);
    }

    await _counters.put(_sequenceKey, next);
    return id;
  }

  String _format(int sequence) =>
      '$_prefix-${sequence.toString().padLeft(6, '0')}';
}
