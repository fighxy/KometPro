import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komet/core/design/ios_chrome.dart';
import 'package:komet/core/design/komet_tokens.dart';

void main() {
  test('navigation retains a 44 point target throughout collapse', () {
    for (final collapse in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      expect(
        IosChrome.heightAt(collapse) - 2 * IosChrome.navPaddingAt(collapse),
        greaterThanOrEqualTo(IosChrome.minimumTarget),
      );
    }
  });

  test('collapse tracks scroll offset', () {
    expect(IosChrome.collapseFromOffset(0), 0);
    expect(IosChrome.collapseFromOffset(28), 0.5);
    expect(IosChrome.collapseFromOffset(56), 1);
    expect(IosChrome.collapseFromOffset(120), 1);
    expect(IosChrome.collapseFromOffset(-10), 0);
  });

  test('scroll delta expands faster than it collapses', () {
    expect(IosChrome.applyScrollDelta(0, 56), 1);
    expect(IosChrome.applyScrollDelta(1, -56), closeTo(0, 0.001));
    final down = IosChrome.applyScrollDelta(0, 20);
    final up = IosChrome.applyScrollDelta(1, -20);
    expect(1 - up, greaterThan(down));
  });

  test('height interpolates between expanded and compact', () {
    expect(IosChrome.heightAt(0), IosChrome.expandedHeight);
    expect(IosChrome.heightAt(1), IosChrome.compactHeight);
    expect(
      IosChrome.heightAt(0.5),
      (IosChrome.expandedHeight + IosChrome.compactHeight) / 2,
    );
    expect(IosChrome.iconsOnly(0.54), isFalse);
    expect(IosChrome.iconsOnly(0.55), isTrue);
  });

  test('content clearance keeps the floating pill above the list', () {
    const safe = 34.0;
    expect(
      IosChrome.contentClearance(safe),
      IosChrome.navBottom(safe) + IosChrome.expandedHeight + 10,
    );
    expect(
      IosChrome.contentClearance(safe, collapse: 1),
      lessThan(IosChrome.contentClearance(safe)),
    );
    expect(IosChrome.navBottom(safe), safe + IosChrome.navLift);
  });

  test('sheet radius follows the iOS 26 token', () {
    expect(IosChrome.sheetRadius, 28);
    expect(KometTokens.mobileSheet, IosChrome.sheetRadius);
  });

  test('edge tint stays readable in both schemes', () {
    final light = ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    expect(IosChrome.edgeTint(light).a, greaterThan(0));
    expect(IosChrome.edgeTint(dark).a, greaterThan(IosChrome.edgeTint(light).a));
  });

  test('type tokens match Telegram iOS defaults', () {
    expect(IosChrome.listTitleSize, 17);
    expect(IosChrome.listTitleWeight, FontWeight.w600);
    expect(IosChrome.listPreviewSize, 15);
    expect(IosChrome.listPreviewWeight, FontWeight.w400);
    expect(IosChrome.listTimeSize, 14);
    expect(IosChrome.listTimeWeight, FontWeight.w400);
    expect(IosChrome.bubbleBodySize, 17);
    expect(IosChrome.bubbleBodyWeight, FontWeight.w400);
    expect(IosChrome.bubbleMetaSize, 12);
    expect(IosChrome.bubbleMetaWeight, FontWeight.w400);
  });
}
