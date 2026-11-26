import '../../../core/di/service_locator.dart';
import '../../../data/models/common/customer_model_125.dart';
import '../../../data/repositories/common/customer_repository.dart';

/// The customer-account updates one retail sale makes — credit, loyalty
/// points spent, purchase total, points earned, visit — applied AFTER the sale
/// is saved, each exactly once.
///
/// Checkout used to apply these before saving the sale. When the save failed,
/// the customer had already been charged; the retry charged them again
/// (BLK-13). Now the sale is saved first and this runs after it; a retry after
/// a failure here re-runs only the steps that did not complete, so no step can
/// ever be applied twice.
///
/// Each step is ONE customer write. Before it, the step records the fields it
/// moves as they are (`before`) and as the step will leave them (`after`).
/// A step found half-way (after a failure, or restored by
/// `RetailCheckoutCommit` after a crash) is resolved from those two
/// predictions only: fields == after → it was applied; == before → apply it
/// now; anything else → something else changed this customer, so it is never
/// guessed: the step becomes `review` and [onReview] reports it.
class CheckoutCustomerPosting {
  static const String _pending = 'pending';
  static const String _applying = 'applying';
  static const String _done = 'done';
  static const String _review = 'review';

  static const double _eps = 1e-6;

  final String kind;
  final String customerId;
  final List<_Step> _steps;
  final List<Map<String, dynamic>> _state;

  /// Called after every state change, so a persisted copy stays current.
  Future<void> Function()? persist;

  /// Called once when a step turns `review`.
  Future<void> Function(PostingConflict conflict)? onReview;

  CheckoutCustomerPosting._(this.kind, this.customerId, this._steps,
      [List<Map<String, dynamic>>? state])
      : _state = state ??
            [for (final _ in _steps) <String, dynamic>{'s': _pending}];

  /// A paid (or part-paid) sale: points spent, any unpaid balance onto the
  /// customer's credit, then purchase total + points earned + visit.
  ///
  /// The unpaid balance moves the credit ONLY: the purchase step below
  /// records the sale's purchase total and visit once. Booking the balance
  /// through `updateAfterCreditSale` counted a part-paid sale's purchase and
  /// visit twice.
  factory CheckoutCustomerPosting.paidSale({
    required String customerId,
    required int pointsRedeemed,
    required double dueAmount,
    required double grandTotal,
    required int pointsEarned,
  }) =>
      CheckoutCustomerPosting._('paid', customerId, [
        if (pointsRedeemed > 0) _Step.redeem(pointsRedeemed),
        if (dueAmount > 0) _Step.credit(dueAmount),
        _Step.purchase(grandTotal, pointsEarned),
      ]);

  /// A Pay Later sale: the whole bill onto the customer's credit (with the
  /// purchase total and visit), then points spent. Same steps and order
  /// checkout always used.
  factory CheckoutCustomerPosting.creditSale({
    required String customerId,
    required double grandTotal,
    required int pointsRedeemed,
  }) =>
      CheckoutCustomerPosting._('credit', customerId, [
        _Step.creditSale(grandTotal),
        if (pointsRedeemed > 0) _Step.redeem(pointsRedeemed),
      ]);

  /// Every step has been applied.
  bool get isComplete => _state.every((s) => s['s'] == _done);

  /// Nothing left to apply: each step is applied or waiting for a person.
  bool get isSettled =>
      _state.every((s) => s['s'] == _done || s['s'] == _review);

  bool get hasReview => _state.any((s) => s['s'] == _review);

  /// Applies the steps not yet applied, in order. A step that throws stops
  /// here and stays pending; the ones before it stay done. Safe to call again.
  Future<void> apply() async {
    final repository = CustomerRepository();
    for (var i = 0; i < _steps.length; i++) {
      final state = _state[i];
      if (state['s'] == _done || state['s'] == _review) continue;
      final step = _steps[i];

      final customer = await repository.getCustomerById(customerId);
      if (customer == null) {
        // Every customer write is a no-op for a missing customer.
        state['s'] = _done;
        await persist?.call();
        continue;
      }
      final now = _fieldsOf(customer, step.fields);

      if (state['s'] == _applying) {
        final before = _numMap(state['before']);
        final after = _numMap(state['after']);
        if (_same(now, after)) {
          state['s'] = _done;
          await persist?.call();
          continue;
        }
        if (!_same(now, before)) {
          state['s'] = _review;
          await persist?.call();
          await onReview?.call(PostingConflict(
            customerId: customerId,
            step: step.name,
            before: before,
            expectedAfter: after,
            found: now,
          ));
          continue;
        }
        // Still exactly as before: the write never happened.
      }

      state
        ..['s'] = _applying
        ..['before'] = now
        ..['after'] = step.expectedAfter(customer);
      await persist?.call();
      await step.run(customerId);
      state['s'] = _done;
      await persist?.call();
    }
  }

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'customerId': customerId,
        'steps': [for (final s in _steps) s.toMap()],
        'state': [for (final s in _state) Map<String, dynamic>.from(s)],
      };

  factory CheckoutCustomerPosting.fromMap(Map<String, dynamic> m) =>
      CheckoutCustomerPosting._(
        m['kind'] as String,
        m['customerId'] as String,
        [
          for (final s in m['steps'] as List)
            _Step.fromMap(Map<String, dynamic>.from(s as Map)),
        ],
        [
          for (final s in m['state'] as List)
            Map<String, dynamic>.from(s as Map),
        ],
      );

  static Map<String, num> _numMap(Object? raw) => {
        for (final e in (raw as Map? ?? const {}).entries)
          e.key as String: e.value as num,
      };

  static bool _same(Map<String, num> a, Map<String, num> b) =>
      a.length == b.length &&
      a.entries.every((e) =>
          b.containsKey(e.key) && (e.value - b[e.key]!).abs() < _eps);

  static Map<String, num> _fieldsOf(Customer c, List<String> fields) {
    final all = <String, num>{
      'creditBalance': c.creditBalance,
      'loyaltyPoints': c.loyaltyPoints,
      'totalPointEarned': c.totalPointEarned,
      'totalPointRedeemed': c.totalPointRedeemed,
      'totalPurchaseAmount': c.totalPurchaseAmount,
      'totalVisites': c.totalVisites,
    };
    return {for (final f in fields) f: all[f]!};
  }
}

/// A customer step that found the customer changed by something else.
class PostingConflict {
  final String customerId;
  final String step;
  final Map<String, num> before;
  final Map<String, num> expectedAfter;
  final Map<String, num> found;

  const PostingConflict({
    required this.customerId,
    required this.step,
    required this.before,
    required this.expectedAfter,
    required this.found,
  });
}

/// One customer write, described as data so it survives a restart.
class _Step {
  final String name;
  final double amount;
  final int points;

  const _Step._(this.name, this.amount, this.points);

  factory _Step.redeem(int points) => _Step._('redeem', 0, points);
  factory _Step.credit(double amount) => _Step._('credit', amount, 0);
  factory _Step.purchase(double amount, int points) =>
      _Step._('purchase', amount, points);
  factory _Step.creditSale(double amount) => _Step._('creditSale', amount, 0);

  factory _Step.fromMap(Map<String, dynamic> m) => _Step._(
      m['name'] as String,
      (m['amount'] as num).toDouble(),
      (m['points'] as num).toInt());

  Map<String, dynamic> toMap() =>
      {'name': name, 'amount': amount, 'points': points};

  /// The customer fields this step moves — the only ones it is judged by.
  List<String> get fields => switch (name) {
        'redeem' => const ['loyaltyPoints', 'totalPointRedeemed'],
        'credit' => const ['creditBalance'],
        'purchase' => const [
            'totalPurchaseAmount',
            'loyaltyPoints',
            'totalPointEarned',
            'totalVisites',
          ],
        'creditSale' => const [
            'creditBalance',
            'totalPurchaseAmount',
            'totalVisites',
          ],
        _ => throw StateError('Unknown customer step $name'),
      };

  /// [fields] as this step will leave [c] — the same arithmetic as the write.
  Map<String, num> expectedAfter(Customer c) => switch (name) {
        // `redeemPoints` changes nothing when the balance is short.
        'redeem' => c.loyaltyPoints >= points
            ? {
                'loyaltyPoints': c.loyaltyPoints - points,
                'totalPointRedeemed': c.totalPointRedeemed + points,
              }
            : {
                'loyaltyPoints': c.loyaltyPoints,
                'totalPointRedeemed': c.totalPointRedeemed,
              },
        'credit' => {'creditBalance': c.creditBalance + amount},
        'purchase' => {
            'totalPurchaseAmount': c.totalPurchaseAmount + amount,
            'loyaltyPoints': c.loyaltyPoints + points,
            'totalPointEarned': c.totalPointEarned + points,
            'totalVisites': c.totalVisites + 1,
          },
        'creditSale' => {
            'creditBalance': c.creditBalance + amount,
            'totalPurchaseAmount': c.totalPurchaseAmount + amount,
            'totalVisites': c.totalVisites + 1,
          },
        _ => throw StateError('Unknown customer step $name'),
      };

  Future<void> run(String customerId) => switch (name) {
        'redeem' => customerStore.redeemCustomerPoints(customerId, points),
        'credit' => customerStore.addCredit(customerId, amount),
        'purchase' =>
          customerStore.updateAfterPurchase(customerId, amount, points),
        'creditSale' => customerStore.updateAfterCreditSale(customerId, amount),
        _ => throw StateError('Unknown customer step $name'),
      };
}
