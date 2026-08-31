import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../theme/salamat_dark.dart';

/// Which part of a scan is running.
///
/// Three stages, three real boundaries: the photo is compressed, the response
/// comes back, the sheet opens. There is deliberately no split between
/// "uploading" and "recognising" — `functions.invoke` gives no signal when the
/// request body has finished going out, so a boundary drawn there would be a
/// timer wearing a progress bar's clothes.
enum ScanStage {
  idle,

  /// Capturing and shrinking the frame. Ends when compression returns.
  preparing,

  /// Uploaded and waiting on the model. Ends when the response arrives.
  recognising,

  /// Response in hand, assembling the entry. Ends when the sheet opens.
  calculating;

  String label(AppLocalizations loc) => switch (this) {
        ScanStage.idle || ScanStage.preparing => loc.scanStagePrepare,
        ScanStage.recognising => loc.scanStageRecognise,
        ScanStage.calculating => loc.scanStageCalculate,
      };
}

/// The three stages, stacked, with the current one lit.
///
/// No percentage and no bar that fills: the model reports no progress, so any
/// number here would be fiction. What it does show is which of three real
/// steps is running and which are done, which is the honest version of the
/// same reassurance.
class ScanProgress extends StatelessWidget {
  const ScanProgress({super.key, required this.stage});

  final ScanStage stage;

  static const List<ScanStage> _order = [
    ScanStage.preparing,
    ScanStage.recognising,
    ScanStage.calculating,
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final current = _order.indexOf(stage);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xE6000000),
          borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _order.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ScanStageRow(
                text: _order[i].label(loc),
                done: i < current,
                active: i == current,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanStageRow extends StatelessWidget {
  const _ScanStageRow({
    required this.text,
    required this.done,
    required this.active,
  });

  final String text;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done
        ? sc.primary
        : active
            ? Colors.white
            : Colors.white38;
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: done
              ? PhosphorIcon(
                  PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  size: 18,
                  color: sc.primary,
                )
              : active
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: sc.primary,
                      ),
                    )
                  : PhosphorIcon(
                      PhosphorIcons.circle(),
                      size: 16,
                      color: Colors.white24,
                    ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: SalamatDarkType.style(
              fontSize: 15,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
