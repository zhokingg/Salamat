import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Free tier: 3 photos TOTAL (lifetime), enforced server-side via
/// `photo_usage` in [PhotoRecognitionService.canUsePhoto]. This constant is
/// the single source of truth for the free quota — the service imports it so
/// the gate and the UI counter never drift apart.
const int kFreeLifetimePhotoLimit = 3;

/// Pro tier: 10 photos per day.
const int kProDailyPhotoLimit = 10;

class SubscriptionState {
  const SubscriptionState({
    this.isPro = false,
    this.photosUsed = 0,
  });

  final bool isPro;

  /// Photos consumed in the active window: lifetime total for free users,
  /// today's count for Pro users.
  final int photosUsed;

  /// Active quota: 3 lifetime for free, 10/day for Pro.
  int get photoLimit => isPro ? kProDailyPhotoLimit : kFreeLifetimePhotoLimit;

  bool get canTakePhoto => photosUsed < photoLimit;

  SubscriptionState copyWith({bool? isPro, int? photosUsed}) {
    return SubscriptionState(
      isPro: isPro ?? this.isPro,
      photosUsed: photosUsed ?? this.photosUsed,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => const SubscriptionState();

  void usePhoto() {
    state = state.copyWith(photosUsed: state.photosUsed + 1);
  }

  void activatePro() {
    state = state.copyWith(isPro: true);
  }

  /// Resets the Pro per-day counter. No-op for the free lifetime quota,
  /// which is tracked server-side.
  void resetDaily() {
    state = state.copyWith(photosUsed: 0);
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
  SubscriptionNotifier.new,
);
