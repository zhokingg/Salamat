import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../services/photo_recognition_service.dart';
import '../services/purchases_service.dart';

import 'session_provider.dart';

/// Free tier: THREE photo scans for the LIFETIME of the account; Pro is
/// unlimited. Manual logging is free and unlimited and never touches this.
///
/// The count is owned by the server (`scan_events`, migration 0006) and spent
/// inside the `recognize-food` Edge Function. Everything in this file is a
/// render cache: it makes "2 of 3 left" paint instantly, and it is corrected
/// by the server on every read and after every scan. A reinstall clears the
/// cache but not the count.

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.scansUsed = 0,
    this.allowance = kFreeScanAllowance,
    this.loaded = false,
  });

  /// Driven exclusively by the RevenueCat customer info — there is no
  /// client-side switch to flip this.
  final bool isPro;

  /// Scans consumed over the account's lifetime, as last reported by the
  /// server.
  final int scansUsed;

  /// Free allowance, mirrored from the server so a policy change needs no
  /// client release.
  final int allowance;

  /// Whether the server has answered at least once. Until it has, the UI
  /// shows no counter rather than a number that might be wrong.
  final bool loaded;

  int get scansLeft =>
      isPro ? 1 << 30 : (allowance - scansUsed).clamp(0, allowance);

  bool get canTakePhoto => isPro || scansLeft > 0;

  /// True once the free allowance is spent — the point at which the app
  /// offers a subscription (after showing the result, never before it).
  bool get exhausted => loaded && !isPro && scansLeft == 0;

  SubscriptionState copyWith({
    bool? isPro,
    int? scansUsed,
    int? allowance,
    bool? loaded,
  }) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      scansUsed: scansUsed ?? this.scansUsed,
      allowance: allowance ?? this.allowance,
      loaded: loaded ?? this.loaded,
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
    // Entitlements belong to an account, so rebuild when the account changes.
    // `_disposed` is per-instance and a rebuild makes a new one, so the reset
    // below is the whole reset: a new empty state, a fresh listener, a fresh
    // fetch against whoever RevenueCat is now logged in as.
    ref.watch(currentUidProvider);
    _disposed = false;
    _ready = false;
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
      // the server refresh behaves identically either way.
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

  /// Pulls the authoritative counts from the server.
  ///
  /// Safe to call on every app start and whenever the camera surface appears.
  /// A null answer (offline, or migration 0006 not applied) leaves the cache
  /// untouched rather than inventing a number.
  Future<void> refreshFromServer() async {
    final status = await PhotoRecognitionService.scanStatus();
    if (!_ready || _disposed || status == null) return;
    state = state.copyWith(
      isPro: status.isPro || state.isPro,
      scansUsed: status.used,
      allowance: status.allowance,
      loaded: true,
    );
  }

  /// Applies the counts the Edge Function returned alongside a scan result,
  /// so the button updates without a second round trip.
  void applyServerCounts({required int used, int? allowance}) {
    if (!_ready || _disposed) return;
    state = state.copyWith(
      scansUsed: used,
      allowance: allowance ?? state.allowance,
      loaded: true,
    );
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);
