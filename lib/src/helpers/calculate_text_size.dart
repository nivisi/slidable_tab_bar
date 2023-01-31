import 'package:flutter/widgets.dart';

Size calculateTextSize(String text, TextStyle style) {
  final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr)
    ..layout(
      minWidth: 0,
      maxWidth: double.infinity,
    );

  return textPainter.size;
}
