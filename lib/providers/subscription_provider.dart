import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/purchases_service.dart';

/// Free tier: 1 photo scan PER DAY, reset at local midnight. Manual logging
/// is free and unlimited. The server-side `photo_usage` table (per-day rows)
/// backs this up in [PhotoRecognitionService.canUsePhoto].
const int kFreeDailyPhotoLimit = 1;

/// Pro tier: 10 photo scans per day. The limit itself stays client-side;
/// the isPro GATE comes from the RevenueCat "pro" entitlement.
const int kProDailyPhotoLimit = 10;

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.photosUsed = 0,
    this.usageDay,
  });

  /// Driven exclusively by the RevenueCat customer info — there is no
  /// client-side switch to flip this.
  final bool isPro;

  /// Photo scans consumed on [usageDay].
  final int photosUsed;

  /// Local calendar day the counter belongs to. A new local date means the
  /// counter is stale and the quota is fresh again.
  final DateTime? usageDay;

  int get photoLimit => isPro ? kProDailyPhotoLimit : kFreeDailyPhotoLimit;

  /// Photos used TODAY (local date) — 0 if the stored counter is from a
  /// previous day.
  int get photosUsedToday {
    final day = usageDay;
    if (day == null) return 0;
    final now = DateTime.now();
    final sameDay =
        day.year == now.year && day.month == now.month && day.day == now.day;
    return sameDay ? photosUsed : 0;
  }

  bool get canTakePhoto => photosUsedToday < photoLimit;

  SubscriptionState copyWith({
    bool? isPro,
    int? photosUsed,
    DateTime? usageDay,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      photosUsed: photosUsed ?? this.photosUsed,
      usageDay: usageDay ?? this.usageDay,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  void Function(CustomerInfo)? _listener;

  /// False until [build] has returned, so nothing may touch `state` yet.
  ///
  /// `Purchases.addCustomerInfoUpdateListener` can invoke the callback
  /// *synchronously* while it is being registered (it replays cached customer
  /// info). Doing that from inside [build] meant reading `state` before the
  /// notifier was initialised, which throws
  /// `Bad state: Tried to read the state of an uninitialized provider` — and
  /// whether it threw depended on how fast RevenueCat answered. Any screen
  /// that watched this provider (profile, camera, paywall) died with it.
  bool _ready = false;

  /// Entitlement seen before [build] finished, applied once it has.
  bool? _pendingPro;

  /// Set by `ref.onDispose`; blocks late SDK callbacks from touching a
  /// notifier that Riverpod has already torn down.
  bool _disposed = false;

  @override
  SubscriptionState build() {
    // Live entitlement updates (purchase, restore, renewal, expiry) flow in
    // through the SDK listener; the initial fetch covers app start.
    if (PurchasesService.isReady) {
      ref.onDispose(() {
        _disposed = true;
        _ready = false;
        if (_listener != null) {
          Purchases.removeCustomerInfoUpdateListener(_listener!);
          _listener = null;
        }
      });
      // Both steps run after this build has returned, in this order, so
      // neither can re-enter the notifier mid-initialisation.
      Future.microtask(() {
        _markReady();
        if (_disposed) return;
        _listener = _onCustomerInfo;
        Purchases.addCustomerInfoUpdateListener(_listener!);
        Purchases.getCustomerInfo().then(_onCustomerInfo).catchError((e) {
          if (kDebugMode) debugPrint('getCustomerInfo error: $e');
        });
      });
    } else {
      // No store SDK: nothing will ever call in, but keep the flag honest so
      // `usePhoto`/`resetDaily` behave identically either way.
      Future.microtask(_markReady);
    }
    return const SubscriptionState();
  }

  void _markReady() {
    if (_disposed) return;
    _ready = true;
    final pending = _pendingPro;
    _pendingPro = null;
    if (pending != null) _applyPro(pending);
  }

  void _onCustomerInfo(CustomerInfo info) {
    _applyPro(PurchasesService.hasPro(info));
  }

  void _applyPro(bool pro) {
    // Before initialisation, or after dispose, stash instead of writing.
    if (!_ready) {
      _pendingPro = pro;
      return;
    }
    if (pro != state.isPro) {
      state = state.copyWith(isPro: pro);
    }
  }

  void usePhoto() {
    // Only reachable from a user-driven scan, i.e. long after [_markReady];
    // the guard exists so a pre-init call can never throw.
    if (!_ready) return;
    final now = DateTime.now();
    state = state.copyWith(
      photosUsed: state.photosUsedToday + 1,
      usageDay: DateTime(now.year, now.month, now.day),
    );
  }

  /// Explicit counter reset (the local-date check in [SubscriptionState]
  /// already makes stale counters read as 0).
  void resetDaily() {
    if (!_ready) return;
    state = state.copyWith(photosUsed: 0);
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);
