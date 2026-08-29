/// Which visual skin the app runs in.
///
/// This is the single rollback switch for the dark redesign. Change
/// [kAppSkin], hot-restart, done — no other file needs editing.
enum AppSkin {
  /// The prototype's dark theme: AMOLED black canvas, neon green accent.
  /// This is the new design direction and the default.
  protoDark,

  /// The prototype's light theme. It ships in the same prototype
  /// (`.salamat` vs `.salamat.dark`), so it is transcribed too.
  protoLight,

  /// Rollback: the pre-redesign palette (`SalamatTokens` / `SalamatColors`)
  /// poured into the new role names. See `docs/token-map.md`.
  ///
  /// Caveat, stated plainly: this reverts colour, type and elevation. It does
  /// NOT revert layout — the repainted screens keep the prototype's structure,
  /// because that structure is markup, not a token. For a full visual rollback
  /// use git to restore the screens together with this flag.
  legacy,
}

/// The active skin.
const AppSkin kAppSkin = AppSkin.protoDark;

/// True when the redesign is active in either of its prototype variants.
bool get kRedesignActive => kAppSkin != AppSkin.legacy;
