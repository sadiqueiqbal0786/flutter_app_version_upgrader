import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/version_check_result.dart';
import 'upgrader_style.dart';
import 'upgrader_texts.dart';

/// The shared body of the blocking screen and the soft prompt: animated
/// hero, title, message, version chips, optional release notes and the
/// actions. Children enter with a staggered fade-and-rise.
class UpgraderContent extends StatefulWidget {
  /// Creates the content.
  const UpgraderContent({
    super.key,
    required this.result,
    required this.style,
    required this.texts,
    required this.title,
    required this.message,
    required this.onUpdate,
    this.onLater,
    this.onSkip,
    this.centered = true,
    this.heroScale = 1.0,
    this.releaseNotesMaxLines = 8,
  });

  /// The decision being shown.
  final VersionCheckResult result;

  /// Resolved style.
  final ResolvedUpgraderStyle style;

  /// Texts.
  final UpgraderTexts texts;

  /// Title.
  final String title;

  /// Body text.
  final String message;

  /// Primary action.
  final VoidCallback onUpdate;

  /// "Later" action; hidden when `null`.
  final VoidCallback? onLater;

  /// "Skip this version" action; hidden when `null`.
  final VoidCallback? onSkip;

  /// Centre the text block (true for the full screen, false in a sheet).
  final bool centered;

  /// Multiplier for the hero size (the full screen uses a larger one).
  final double heroScale;

  /// Max lines of release notes before they scroll.
  final int releaseNotesMaxLines;

  @override
  State<UpgraderContent> createState() => _UpgraderContentState();
}

class _UpgraderContentState extends State<UpgraderContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.08).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final t = widget.texts;
    final r = widget.result;
    final align = widget.centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = widget.centered ? TextAlign.center : TextAlign.start;
    final notes = r.releaseNotes;
    final versionLine = t.versionLine.isEmpty ? null : UpgraderTexts.fill(t.versionLine, r);
    var i = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        _staggered(i++, Align(
          alignment: widget.centered ? Alignment.center : Alignment.centerLeft,
          child: s.illustration ?? UpgraderHero(style: s, scale: widget.heroScale),
        )),
        SizedBox(height: 22 * widget.heroScale),
        _staggered(i++, Text(widget.title, style: s.title, textAlign: textAlign)),
        const SizedBox(height: 10),
        _staggered(i++, Text(widget.message, style: s.message, textAlign: textAlign)),
        if (s.showVersionChips && r.latest != null) ...[
          const SizedBox(height: 18),
          _staggered(i++, Align(
            alignment: widget.centered ? Alignment.center : Alignment.centerLeft,
            // Long version strings or large fonts shrink instead of overflowing.
            child: FittedBox(fit: BoxFit.scaleDown, child: VersionChips(result: r, style: s)),
          )),
        ],
        if (versionLine != null) ...[
          const SizedBox(height: 10),
          _staggered(i++, Text(versionLine, style: s.caption, textAlign: textAlign)),
        ],
        if (notes != null && notes.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          _staggered(i++, ReleaseNotesCard(
            title: t.releaseNotesTitle,
            notes: notes.trim(),
            style: s,
            maxLines: widget.releaseNotesMaxLines,
          )),
        ],
        const SizedBox(height: 28),
        _staggered(i++, UpgraderPrimaryButton(
          label: t.updateButton,
          style: s,
          onPressed: widget.onUpdate,
        )),
        if (widget.onLater != null || widget.onSkip != null) ...[
          const SizedBox(height: 8),
          _staggered(i++, Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (widget.onLater != null && t.laterButton.isNotEmpty)
                _SecondaryButton(label: t.laterButton, style: s, onPressed: widget.onLater!),
              if (widget.onLater != null && t.laterButton.isNotEmpty && widget.onSkip != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('·', style: s.caption),
                ),
              if (widget.onSkip != null)
                _SecondaryButton(label: t.skipButton, style: s, onPressed: widget.onSkip!),
            ],
          )),
        ],
      ],
    );
  }
}

/// Gradient disc with the icon and two softly pulsing rings.
class UpgraderHero extends StatefulWidget {
  /// Creates the hero.
  const UpgraderHero({super.key, required this.style, this.scale = 1.0});

  /// Resolved style.
  final ResolvedUpgraderStyle style;

  /// Size multiplier.
  final double scale;

  @override
  State<UpgraderHero> createState() => _UpgraderHeroState();
}

class _UpgraderHeroState extends State<UpgraderHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void initState() {
    super.initState();
    if (widget.style.animateHero) {
      // Three breaths, then rest: alive on entry, quiet afterwards (and
      // finite, so tests and battery are both happy).
      _pulse.repeat(count: 3);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    final disc = 84.0 * widget.scale;
    final accent = s.accent;
    return SizedBox(
      width: disc * 1.9,
      height: disc * 1.9,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final v = _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _ring(disc * (1.35 + 0.5 * v), accent.withValues(alpha: 0.10 * (1 - v))),
              _ring(disc * (1.2 + 0.25 * v), accent.withValues(alpha: 0.14 * (1 - v * 0.6))),
              _ring(disc * 1.22, accent.withValues(alpha: 0.10)),
              child!,
            ],
          );
        },
        child: Container(
          width: disc,
          height: disc,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: s.heroGradient,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: s.isDark ? 0.45 : 0.32),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(s.icon, size: disc * 0.46, color: s.onAccent),
        ),
      ),
    );
  }

  Widget _ring(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// "installed → latest" chips.
class VersionChips extends StatelessWidget {
  /// Creates the chips.
  const VersionChips({super.key, required this.result, required this.style});

  /// The decision.
  final VersionCheckResult result;

  /// Resolved style.
  final ResolvedUpgraderStyle style;

  @override
  Widget build(BuildContext context) {
    final s = style;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(result.current.toString(), bg: s.muted.withValues(alpha: 0.12), fg: s.muted),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            s.cupertino ? CupertinoIcons.arrow_right : Icons.arrow_forward_rounded,
            size: 16,
            color: s.muted,
          ),
        ),
        _chip(result.latest.toString(), bg: s.accent.withValues(alpha: s.isDark ? 0.22 : 0.12), fg: s.accent, bold: true),
      ],
    );
  }

  Widget _chip(String text, {required Color bg, required Color fg, bool bold = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}

/// Release notes in a soft card.
class ReleaseNotesCard extends StatelessWidget {
  /// Creates the card.
  const ReleaseNotesCard({
    super.key,
    required this.title,
    required this.notes,
    required this.style,
    this.maxLines = 8,
  });

  /// Heading.
  final String title;

  /// Body.
  final String notes;

  /// Resolved style.
  final ResolvedUpgraderStyle style;

  /// Max lines before scrolling.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final body = s.message?.copyWith(fontSize: (s.message?.fontSize ?? 16) - 1);
    final lineHeight = (body?.fontSize ?? 15) * (body?.height ?? 1.4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: s.muted.withValues(alpha: s.isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.muted.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(s.cupertino ? CupertinoIcons.sparkles : Icons.auto_awesome_rounded, size: 16, color: s.accent),
              const SizedBox(width: 8),
              Text(title, style: s.caption?.copyWith(fontWeight: FontWeight.w700, color: s.foreground)),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: lineHeight * maxLines),
            child: SingleChildScrollView(child: Text(notes, style: body)),
          ),
        ],
      ),
    );
  }
}

/// Gradient primary button with a coloured shadow.
class UpgraderPrimaryButton extends StatefulWidget {
  /// Creates the button.
  const UpgraderPrimaryButton({
    super.key,
    required this.label,
    required this.style,
    required this.onPressed,
  });

  /// Label.
  final String label;

  /// Resolved style.
  final ResolvedUpgraderStyle style;

  /// Tap handler.
  final VoidCallback onPressed;

  @override
  State<UpgraderPrimaryButton> createState() => _UpgraderPrimaryButtonState();
}

class _UpgraderPrimaryButtonState extends State<UpgraderPrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.style;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: double.infinity,
            height: s.buttonHeight,
            decoration: BoxDecoration(
              borderRadius: s.buttonBorderRadius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: s.heroGradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: s.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(color: s.onAccent, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                ),
                const SizedBox(width: 8),
                Icon(
                  s.cupertino ? CupertinoIcons.arrow_right : Icons.arrow_forward_rounded,
                  size: 18,
                  color: s.onAccent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.style, required this.onPressed});

  final String label;
  final ResolvedUpgraderStyle style;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, style: TextStyle(color: style.muted, fontWeight: FontWeight.w600, fontSize: 14));
    if (style.cupertino) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onPressed,
        child: text,
      );
    }
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: style.muted),
      onPressed: onPressed,
      child: text,
    );
  }
}
