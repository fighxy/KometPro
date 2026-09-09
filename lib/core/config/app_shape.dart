import 'package:flutter/material.dart';

import '../design/komet_tokens.dart';

class AppShape {
  static const double card = KometTokens.card;
  static const double button = KometTokens.control;
  static const double sheet = KometTokens.mobileSheet;
  static const double dialog = KometTokens.dialog;
  static const double pill = 100;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );

  static const RoundedRectangleBorder buttonBorder = RoundedRectangleBorder(
    borderRadius: buttonRadius,
  );
  static const RoundedRectangleBorder dialogBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(dialog)),
  );
  static const RoundedRectangleBorder sheetBorder = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(sheet)),
  );
}
