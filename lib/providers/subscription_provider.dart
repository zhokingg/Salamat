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

  @override
  SubscriptionState build() {
    // Live entitlement updates (purchase, restore, renewal, expiry) flow in
    // through the SDK listener; the initial fetch covers app start.
    if (PurchasesService.isReady) {
      _listener = _onCustomerInfo;
      Purchases.addCustomerInfoUpdateListener(_listener!);
      ref.onDispose(() {
        if (_listener != null) {
          Purchases.removeCustomerInfoUpdateListener(_listener!);
        }
      });
      Purchases.getCustomerInfo().then(_onCustomerInfo).catchError((e) {
        if (kDebugMode) debugPrint('getCustomerInfo error: $e');
      });
    }
    return const SubscriptionState();
  }

  void _onCustomerInfo(CustomerInfo info) {
    final pro = PurchasesService.hasPro(info);
    if (pro != state.isPro) {
      state = state.copyWith(isPro: pro);
    }
  }

  void usePhoto() {
    final now = DateTime.now();
    state = state.copyWith(
      photosUsed: state.photosUsedToday + 1,
      usageDay: DateTime(now.year, now.month, now.day),
    );
  }

  /// Explicit counter reset (the local-date check in [SubscriptionState]
  /// already makes stale counters read as 0).
  void resetDaily() {
    state = state.copyWith(photosUsed: 0);
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);
