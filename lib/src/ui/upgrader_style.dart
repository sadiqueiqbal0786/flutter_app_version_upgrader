import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// How the soft "update available" prompt is presented.
enum UpgraderPresentation {
  /// A sheet sliding up from the bottom (default).
  bottomSheet,

  /// A centred card.
  dialog,

  /// Replaces the whole screen, like the blocking page but dismissible.
  fullScreen,
}

/// Visual customisation for the built-in UI.
///
/// Every field is optional. Unset fields are resolved from the ambient
/// [Theme] (and from Cupertino conventions on iOS when [platformAdaptive]
/// is on), so the default look already matches the host app's palette.
@immutable
class UpgraderStyle {
  /// Creates a style; see the field docs for what each one affects.
  const UpgraderStyle({
    this.platformAdaptive = true,
    this.accentColor,
    this.backgroundColor,
    this.foregroundColor,
    this.mutedColor,
    this.barrierColor,
    this.borderRadius,
    this.buttonBorderRadius,
    this.buttonHeight = 52,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
    this.titleStyle,
    this.messageStyle,
    this.captionStyle,
    this.icon,
    this.iconSize = 64,
    this.illustration,
    this.showDragHandle = true,
    this.presentation = UpgraderPresentation.bottomSheet,
    this.animationDuration = const Duration(milliseconds: 320),
    this.heroGradient,
    this.animateHero = true,
    this.blurBackdrop = true,
    this.showVersionChips = true,
  });

  /// Use Cupertino widgets and metrics on iOS and macOS.
  final bool platformAdaptive;

  /// Primary buttons and the icon. Defaults to the theme's primary colour.
  final Color? accentColor;

  /// Sheet, dialog and screen background.
  final Color? backgroundColor;

  /// Title and body text colour.
  final Color? foregroundColor;

  /// Caption and secondary text colour.
  final Color? mutedColor;

  /// Scrim behind the sheet or dialog.
  final Color? barrierColor;

  /// Corner radius of the sheet or dialog.
  final BorderRadius? borderRadius;

  /// Corner radius of the buttons.
  final BorderRadius? buttonBorderRadius;

  /// Height of the primary button.
  final double buttonHeight;

  /// Inner padding of the sheet, dialog or screen content.
  final EdgeInsets padding;

  /// Overrides for the title text style.
  final TextStyle? titleStyle;

  /// Overrides for the body text style.
  final TextStyle? messageStyle;

  /// Overrides for the version line and release-notes heading.
  final TextStyle? captionStyle;

  /// Icon shown above the title. Ignored when [illustration] is set.
  final IconData? icon;

  /// Size of [icon].
  final double iconSize;

  /// Any widget (image, Lottie, SVG) shown instead of the icon.
  final Widget? illustration;

  /// Whether the bottom sheet shows a drag handle.
  final bool showDragHandle;

  /// How the soft prompt is presented.
  final UpgraderPresentation presentation;

  /// Entry animation length for the sheet or dialog.
  final Duration animationDuration;

  /// Colours of the hero disc and primary button. Defaults to a gradient
  /// derived from [accentColor].
  final List<Color>? heroGradient;

  /// Pulse the rings around the hero icon on entry.
  final bool animateHero;

  /// Blur the app behind the sheet or dialog.
  final bool blurBackdrop;

  /// Show "installed → latest" version chips under the message.
  final bool showVersionChips;

  /// Returns a copy with the given fields replaced.
  UpgraderStyle copyWith({
    bool? platformAdaptive,
    Color? accentColor,
    Color? backgroundColor,
    Color? foregroundColor,
    Color? mutedColor,
    Color? barrierColor,
    BorderRadius? borderRadius,
    BorderRadius? buttonBorderRadius,
    double? buttonHeight,
    EdgeInsets? padding,
    TextStyle? titleStyle,
    TextStyle? messageStyle,
    TextStyle? captionStyle,
    IconData? icon,
    double? iconSize,
    Widget? illustration,
    bool? showDragHandle,
    UpgraderPresentation? presentation,
    Duration? animationDuration,
    List<Color>? heroGradient,
    bool? animateHero,
    bool? blurBackdrop,
    bool? showVersionChips,
  }) =>
      UpgraderStyle(
        platformAdaptive: platformAdaptive ?? this.platformAdaptive,
        accentColor: accentColor ?? this.accentColor,
        backgroundColor: backgroundColor ?? this.backgroundColor,
        foregroundColor: foregroundColor ?? this.foregroundColor,
        mutedColor: mutedColor ?? this.mutedColor,
        barrierColor: barrierColor ?? this.barrierColor,
        borderRadius: borderRadius ?? this.borderRadius,
        buttonBorderRadius: buttonBorderRadius ?? this.buttonBorderRadius,
        buttonHeight: buttonHeight ?? this.buttonHeight,
        padding: padding ?? this.padding,
        titleStyle: titleStyle ?? this.titleStyle,
        messageStyle: messageStyle ?? this.messageStyle,
        captionStyle: captionStyle ?? this.captionStyle,
        icon: icon ?? this.icon,
        iconSize: iconSize ?? this.iconSize,
        illustration: illustration ?? this.illustration,
        showDragHandle: showDragHandle ?? this.showDragHandle,
        presentation: presentation ?? this.presentation,
        animationDuration: animationDuration ?? this.animationDuration,
        heroGradient: heroGradient ?? this.heroGradient,
        animateHero: animateHero ?? this.animateHero,
        blurBackdrop: blurBackdrop ?? this.blurBackdrop,
        showVersionChips: showVersionChips ?? this.showVersionChips,
      );

  /// Resolves every unset field against [context]'s theme and platform.
  ResolvedUpgraderStyle resolve(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cupertino = platformAdaptive &&
        (theme.platform == TargetPlatform.iOS ||
            theme.platform == TargetPlatform.macOS);
    final accent = accentColor ?? scheme.primary;
    final fg = foregroundColor ?? scheme.onSurface;
    final muted = mutedColor ?? scheme.onSurfaceVariant;
    final radius = borderRadius ?? BorderRadius.circular(cupertino ? 20 : 28);
    return ResolvedUpgraderStyle(
      cupertino: cupertino,
      accent: accent,
      onAccent: accentColor == null ? scheme.onPrimary : _contrast(accent),
      background: backgroundColor ?? scheme.surface,
      foreground: fg,
      muted: muted,
      barrier: barrierColor ??
          Colors.black.withAlpha((((0.45) * 255).round()).clamp(0, 255)),
      borderRadius: radius,
      buttonBorderRadius:
          buttonBorderRadius ?? BorderRadius.circular(cupertino ? 14 : 100),
      buttonHeight: buttonHeight,
      padding: padding,
      title: (cupertino
              ? theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                )
              : theme.textTheme.headlineSmall)
          ?.copyWith(color: fg)
          .merge(titleStyle),
      message: theme.textTheme.bodyLarge
          ?.copyWith(color: fg, height: 1.4)
          .merge(messageStyle),
      caption:
          theme.textTheme.bodySmall?.copyWith(color: muted).merge(captionStyle),
      icon: icon ??
          (cupertino
              ? CupertinoIcons.arrow_down_to_line
              : Icons.download_rounded),
      iconSize: iconSize,
      illustration: illustration,
      showDragHandle: showDragHandle,
      presentation: presentation,
      animationDuration: animationDuration,
      // Light themes get a lift towards white; dark themes (whose primary is
      // already pale) get depth towards black so the gradient stays visible.
      heroGradient: heroGradient ??
          (theme.brightness == Brightness.dark
              ? [Color.lerp(accent, Colors.black, 0.22) ?? accent, accent]
              : [accent, Color.lerp(accent, Colors.white, 0.28) ?? accent]),
      animateHero: animateHero,
      blurBackdrop: blurBackdrop,
      showVersionChips: showVersionChips,
      isDark: theme.brightness == Brightness.dark,
    );
  }

  static Color _contrast(Color c) =>
      ThemeData.estimateBrightnessForColor(c) == Brightness.dark
          ? Colors.white
          : Colors.black;
}

/// An [UpgraderStyle] with every value filled in.
@immutable
class ResolvedUpgraderStyle {
  /// Creates a resolved style.
  const ResolvedUpgraderStyle({
    required this.cupertino,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.foreground,
    required this.muted,
    required this.barrier,
    required this.borderRadius,
    required this.buttonBorderRadius,
    required this.buttonHeight,
    required this.padding,
    required this.title,
    required this.message,
    required this.caption,
    required this.icon,
    required this.iconSize,
    required this.illustration,
    required this.showDragHandle,
    required this.presentation,
    required this.animationDuration,
    required this.heroGradient,
    required this.animateHero,
    required this.blurBackdrop,
    required this.showVersionChips,
    required this.isDark,
  });

  /// Whether Cupertino widgets are used.
  final bool cupertino;

  /// Accent colour.
  final Color accent;

  /// Text colour on the accent.
  final Color onAccent;

  /// Surface colour.
  final Color background;

  /// Primary text colour.
  final Color foreground;

  /// Secondary text colour.
  final Color muted;

  /// Scrim colour.
  final Color barrier;

  /// Surface corner radius.
  final BorderRadius borderRadius;

  /// Button corner radius.
  final BorderRadius buttonBorderRadius;

  /// Primary button height.
  final double buttonHeight;

  /// Content padding.
  final EdgeInsets padding;

  /// Title style.
  final TextStyle? title;

  /// Body style.
  final TextStyle? message;

  /// Caption style.
  final TextStyle? caption;

  /// Icon glyph.
  final IconData icon;

  /// Icon size.
  final double iconSize;

  /// Illustration replacing the icon, if any.
  final Widget? illustration;

  /// Drag handle on the sheet.
  final bool showDragHandle;

  /// Soft prompt presentation.
  final UpgraderPresentation presentation;

  /// Animation duration.
  final Duration animationDuration;

  /// Hero and primary button gradient.
  final List<Color> heroGradient;

  /// Pulse the hero rings.
  final bool animateHero;

  /// Blur behind the overlay.
  final bool blurBackdrop;

  /// Show version chips.
  final bool showVersionChips;

  /// Dark theme in effect.
  final bool isDark;
}
