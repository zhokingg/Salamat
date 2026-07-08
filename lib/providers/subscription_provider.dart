import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Free tier: 1 photo scan PER DAY, reset at local midnight. Manual logging
/// is free and unlimited. The server-side `photo_usage` table (per-day rows)
/// backs this up in [PhotoRecognitionService.canUsePhoto].
const int kFreeDailyPhotoLimit = 1;

/// Pro tier: 10 photo scans per day.
const int kProDailyPhotoLimit = 10;

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.photosUsed = 0,
    this.usageDay,
  });

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
  @override
  SubscriptionState build() => const SubscriptionState();

  void usePhoto() {
    final now = DateTime.now();
    state = state.copyWith(
      photosUsed: state.photosUsedToday + 1,
      usageDay: DateTime(now.year, now.month, now.day),
    );
  }

  void activatePro() {
    state = state.copyWith(isPro: true);
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
