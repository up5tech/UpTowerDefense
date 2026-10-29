import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Responsive frame shared by the menu, level select, settings and credits.
///
/// Content stays in a readable column, is centred on tablets and wide phones,
/// respects safe areas, and scrolls rather than overflowing on the short
/// landscape screens phones produce.
class MenuLayout extends StatelessWidget {
  const MenuLayout({required this.children, super.key, this.title});

  /// Widest the content column is allowed to get.
  static const double maxContentWidth = 560;

  /// Padding around the content column.
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 16,
  );

  /// Screens scroll when the content is taller than the viewport.
  final List<Widget> children;

  /// Optional app bar title; screens without one render their own header.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final title = this.title;

    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = math.max(
              0.0,
              constraints.maxHeight - contentPadding.vertical,
            );

            return SingleChildScrollView(
              padding: contentPadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxContentWidth,
                    minHeight: minHeight,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
