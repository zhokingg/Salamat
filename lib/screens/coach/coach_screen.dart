import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/weight_provider.dart';
import '../../services/coach_service.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show OnboardingPrimaryButton;

/// Nutrition chat.
///
/// Pro-only and capped per month; both gates are enforced server-side, and this
/// screen only decides which of the three "you cannot send" screens to show.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final List<CoachMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  CoachStatus? _status;
  bool _loadingStatus = true;
  bool _sending = false;

  /// Set when the last attempt failed for a reason that blocks the whole
  /// screen rather than one message.
  CoachFailure? _blocked;

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatus());
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadStatus() async {
    final s = await CoachService.status();
    if (!mounted) return;
    setState(() {
      _status = s;
      _loadingStatus = false;
      if (s == null) {
        // No answer from the gate at all — the feature is not switched on.
        _blocked = CoachFailure.unavailable;
      } else if (!s.isPro) {
        _blocked = CoachFailure.notSubscribed;
      } else if (s.remaining <= 0) {
        _blocked = CoachFailure.monthlyLimit;
      } else {
        _blocked = null;
      }
    });
  }

  /// What the model is told about this user. Assembled here because the app
  /// already has it; the function does not need a second round of reads.
  Map<String, dynamic> _buildContext() {
    final user = ref.read(userProvider);
    final meals = ref.read(mealsProvider).valueOrNull ?? const MealsState();
    final logs = ref.read(weightLogsProvider).valueOrNull ?? const <WeightLog>[];

    final dishes = MealType.values
        .expand(meals.forType)
        .map((e) => e.name)
        .take(12)
        .toList();

    // Signed change over the tracked period; the list is oldest → newest.
    double? change;
    if (logs.length >= 2) {
      change = double.parse(
        (logs.last.kg - logs.first.kg).toStringAsFixed(1),
      );
    }

    return {
      if (user.goal != null) 'goal': user.goal!.name,
      if (user.calorieNorm != null) 'calorie_norm': user.calorieNorm,
      'eaten_today': {
        'kcal': meals.totalKcalAll,
        'protein_g': meals.totalProtein,
        'fat_g': meals.totalFat,
        'carbs_g': meals.totalCarbs,
        if (dishes.isNotEmpty) 'dishes': dishes,
      },
      if (user.weight != null) 'weight_kg': user.weight,
      if (user.targetWeight != null) 'target_weight_kg': user.targetWeight,
      if (change != null) 'weight_change_kg': change,
    };
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final lang = Localizations.localeOf(context).languageCode;

    setState(() {
      _messages.add(CoachMessage(fromUser: true, text: text));
      _input.clear();
      _sending = true;
    });
    _scrollToEnd();

    final (reply, failure) = await CoachService.send(
      history: _messages,
      context: _buildContext(),
      lang: lang,
    );
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (reply != null) {
        _messages.add(CoachMessage(fromUser: false, text: reply));
        final s = _status;
        if (s != null) {
          _status = CoachStatus(
            isPro: s.isPro,
            used: s.used + 1,
            remaining: (s.remaining - 1).clamp(0, s.monthlyLimit),
            monthlyLimit: s.monthlyLimit,
          );
          if (_status!.remaining <= 0) _blocked = CoachFailure.monthlyLimit;
        }
      } else {
        // Put the question back so it is not lost to a failed send.
        _messages.removeLast();
        _input.text = text;
        if (failure == CoachFailure.notSubscribed ||
            failure == CoachFailure.monthlyLimit ||
            failure == CoachFailure.unavailable) {
          _blocked = failure;
        } else {
          _showOffline();
        }
      }
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _showOffline() {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: sc.surface2,
        behavior: SnackBarBehavior.floating,
        content: Text(
          loc.coachOfflineBody,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: sc.text,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: PhosphorIcon(PhosphorIcons.arrowLeft(), color: c.text, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          loc.coachTitle,
          style: SalamatDarkType.style(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        centerTitle: false,
      ),
      body: _loadingStatus
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _blocked != null
              ? _CoachBlocked(
                  failure: _blocked!,
                  onUpgrade: () => context.push('/paywall'),
                )
              : _buildChat(loc, c),
    );
  }

  Widget _buildChat(AppLocalizations loc, SalamatColorsDark c) {
    final s = _status;
    return SafeArea(
      child: Column(
        children: [
          if (s != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                loc.coachRemaining(s.remaining, s.monthlyLimit),
                style: SalamatDarkType.micro.copyWith(color: c.text3),
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _CoachEmpty(onPick: _send)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length + (_sending ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _messages.length) {
                        return _CoachBubble(
                          text: loc.coachThinking,
                          fromUser: false,
                          dim: true,
                        );
                      }
                      final m = _messages[i];
                      return _CoachBubble(text: m.text, fromUser: m.fromUser);
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              loc.coachDisclaimer,
              textAlign: TextAlign.center,
              style: SalamatDarkType.micro.copyWith(color: c.text3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: SalamatDarkType.bodyL.copyWith(color: c.text),
                    decoration: InputDecoration(
                      hintText: loc.coachPlaceholder,
                      hintStyle:
                          SalamatDarkType.bodyM.copyWith(color: c.text3),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(SalamatDarkDims.rTile),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: SalamatDarkDims.gap8),
                Semantics(
                  button: true,
                  label: loc.coachSendLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _send,
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _input.text.trim().isEmpty || _sending
                            ? c.surface2
                            : c.primary,
                      ),
                      child: PhosphorIcon(
                        PhosphorIcons.paperPlaneRight(PhosphorIconsStyle.fill),
                        size: 19,
                        color: _input.text.trim().isEmpty || _sending
                            ? c.text3
                            : c.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state with a few openers, so the first message is one tap.
class _CoachEmpty extends StatelessWidget {
  const _CoachEmpty({required this.onPick});

  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    final suggestions = [loc.coachSuggest1, loc.coachSuggest2, loc.coachSuggest3];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIcons.chatCircleDots(PhosphorIconsStyle.duotone),
            size: 44,
            color: c.primary,
          ),
          const SizedBox(height: SalamatDarkDims.gap16),
          Text(
            loc.coachIntro,
            textAlign: TextAlign.center,
            style: SalamatDarkType.bodyM.copyWith(color: c.text2),
          ),
          const SizedBox(height: SalamatDarkDims.gap20),
          for (final s in suggestions) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(s),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: SalamatDarkDims.gap8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
                ),
                child: Text(
                  s,
                  textAlign: TextAlign.center,
                  style: SalamatDarkType.bodyM.copyWith(color: c.text),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoachBubble extends StatelessWidget {
  const _CoachBubble({
    required this.text,
    required this.fromUser,
    this.dim = false,
  });

  final String text;
  final bool fromUser;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: SalamatDarkDims.gap8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: fromUser ? c.primarySoft : c.surface,
          borderRadius: BorderRadius.circular(SalamatDarkDims.rTile),
        ),
        child: Text(
          text,
          style: SalamatDarkType.bodyM.copyWith(
            color: dim ? c.text3 : (fromUser ? c.primary : c.text),
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

/// The three states in which nothing can be sent. Each says what to do next,
/// and only the subscription one offers to sell anything.
class _CoachBlocked extends StatelessWidget {
  const _CoachBlocked({required this.failure, required this.onUpgrade});

  final CoachFailure failure;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    final (title, body, icon, cta) = switch (failure) {
      CoachFailure.notSubscribed => (
          loc.coachNotSubscribedTitle,
          loc.coachNotSubscribedBody,
          PhosphorIcons.crown(PhosphorIconsStyle.duotone),
          loc.limitGoPro,
        ),
      CoachFailure.monthlyLimit => (
          loc.coachLimitTitle,
          loc.coachLimitBody,
          PhosphorIcons.hourglass(PhosphorIconsStyle.duotone),
          null,
        ),
      CoachFailure.unavailable => (
          loc.coachUnavailableTitle,
          loc.coachUnavailableBody,
          PhosphorIcons.wrench(PhosphorIconsStyle.duotone),
          null,
        ),
      CoachFailure.offline => (
          loc.coachOfflineTitle,
          loc.coachOfflineBody,
          PhosphorIcons.wifiSlash(PhosphorIconsStyle.duotone),
          null,
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, size: 48, color: c.primary),
            const SizedBox(height: SalamatDarkDims.gap16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: SalamatDarkType.style(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: SalamatDarkDims.gap10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: c.text2,
              ),
            ),
            if (cta != null) ...[
              const SizedBox(height: SalamatDarkDims.gap20),
              SizedBox(
                width: double.infinity,
                child: OnboardingPrimaryButton(
                  label: cta,
                  enabled: true,
                  onTap: onUpgrade,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
