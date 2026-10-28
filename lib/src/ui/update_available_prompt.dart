import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../models/version_check_result.dart';
import 'upgrader_content.dart';
import 'upgrader_style.dart';
import 'upgrader_texts.dart';

/// The soft "update available" prompt, drawn as an overlay above the host
/// app (no Navigator required, so it works from `MaterialApp.builder`).
///
/// Presented as a bottom sheet, a dialog or a full screen according to
/// [UpgraderStyle.presentation].
class UpdateAvailablePrompt extends StatefulWidget {
  /// Creates the prompt.
  const UpdateAvailablePrompt({
    super.key,
    required this.result,
    required this.onUpdate,
    required this.onLater,
    this.onSkip,
    this.style = const UpgraderStyle(),
    this.texts = const UpgraderTexts(),
  });

  /// The decision.
  final VersionCheckResult result;

  /// Opens the store.
  final VoidCallback onUpdate;

  /// Dismisses until the next reminder. Also used for the barrier tap.
  final VoidCallback onLater;

  /// Skips this version; hidden when `null`.
  final VoidCallback? onSkip;

  /// Visual style.
  final UpgraderStyle style;

  /// Texts.
  final UpgraderTexts texts;

  @override
  State<UpdateAvailablePrompt> createState() => _UpdateAvailablePromptState();
}

class _UpdateAvailablePromptState extends State<UpdateAvailablePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.style.animationDuration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.style.resolve(context);
    final content = UpgraderContent(
      result: widget.result,
      style: s,
      texts: widget.texts,
      title: widget.texts.availableTitle,
      message: widget.texts.resolveAvailableMessage(widget.result),
      onUpdate: widget.onUpdate,
      onLater: widget.onLater,
      onSkip: widget.onSkip,
      centered: true,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    switch (s.presentation) {
      case UpgraderPresentation.fullScreen:
        return FadeTransition(
          opacity: curve,
          child: Scaffold(
            backgroundColor: s.background,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: s.padding,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );
      case UpgraderPresentation.dialog:
        return Stack(
          children: [
            _Barrier(
              color: s.barrier,
              animation: curve,
              onTap: widget.onLater,
              blur: s.blurBackdrop,
            ),
            Center(
              child: FadeTransition(
                opacity: curve,
                child: ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.0).animate(curve),
                  child: _GlowSurface(
                    style: s,
                    borderRadius: s.borderRadius,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SingleChildScrollView(
                        padding: s.padding.copyWith(top: 28),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case UpgraderPresentation.bottomSheet:
        return Stack(
          children: [
            _Barrier(
              color: s.barrier,
              animation: curve,
              onTap: widget.onLater,
              blur: s.blurBackdrop,
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(curve),
                child: _GlowSurface(
                  style: s,
                  borderRadius: BorderRadius.vertical(
                    top: s.borderRadius.topLeft,
                  ),
                  child: SafeArea(
                    top: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SingleChildScrollView(
                        padding: s.padding,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (s.showDragHandle)
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: s.muted.withAlpha(
                                        (((0.4) * 255).round()).clamp(0, 255)),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            content,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

class _Barrier extends StatelessWidget {
  const _Barrier({
    required this.color,
    required this.animation,
    required this.onTap,
    this.blur = true,
  });

  final Color color;
  final Animation<double> animation;
  final VoidCallback onTap;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColoredBox(color: color, child: const SizedBox.expand()),
              )
            : ColoredBox(color: color, child: const SizedBox.expand()),
      ),
    );
  }
}

/// Surface with a soft accent glow bleeding in from the top edge.
class _GlowSurface extends StatelessWidget {
  const _GlowSurface({
    required this.style,
    required this.borderRadius,
    required this.child,
  });

  final ResolvedUpgraderStyle style;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.background,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.1),
            radius: 1.1,
            colors: [
              style.accent.withAlpha(
                  (((style.isDark ? 0.22 : 0.13) * 255).round()).clamp(0, 255)),
              style.background.withAlpha((((0) * 255).round()).clamp(0, 255)),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}
