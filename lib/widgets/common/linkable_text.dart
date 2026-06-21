import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

/// A text widget that auto-detects URLs and makes them tappable.
/// Use this anywhere you want links to be clickable in user-generated content.
class LinkableText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final Function(String)? onMentionTap;
  final Function(String)? onHashtagTap;

  /// Optional: additional styled spans (e.g. @mentions).
  /// If provided, URLs within those spans are also handled.
  final List<InlineSpan>? extraSpans;

  const LinkableText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.onMentionTap,
    this.onHashtagTap,
    this.extraSpans,
  });

  static final RegExp _entityRegex = RegExp(
    r'((?:https?:\/\/|www\.)[^\s\u0600-\u06FF()<>]+|\b[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(?:\/[^\s\u0600-\u06FF()<>]*)?)|(#[\w\u0600-\u06FF]+)|(@[\w\u0600-\u06FF]+)',
    caseSensitive: false,
  );

  static Future<void> _launchURL(String url) async {
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      finalUrl = 'https://$url';
    }
    final uri = Uri.parse(finalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultStyle = style ??
        TextStyle(
          fontSize: 14,
          height: 1.4,
          color: isDark ? Colors.white : Colors.black87,
        );

    final linkStyle = defaultStyle.copyWith(
      color: isDark ? const Color(0xFF64B5F6) : AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: (isDark ? const Color(0xFF64B5F6) : AppColors.primary)
          .withValues(alpha: 0.4),
    );

    final hashtagStyle = defaultStyle.copyWith(
      color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
      fontWeight: FontWeight.w600,
    );

    final mentionStyle = defaultStyle.copyWith(
      color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00),
      fontWeight: FontWeight.bold,
    );

    final matches = _entityRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: defaultStyle,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Add normal text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final urlMatch = match.group(1);
      final hashtagMatch = match.group(2);
      final mentionMatch = match.group(3);

      if (urlMatch != null) {
        spans.add(TextSpan(
          text: urlMatch,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () => _launchURL(urlMatch),
        ));
      } else if (hashtagMatch != null) {
        spans.add(TextSpan(
          text: hashtagMatch,
          style: hashtagStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onHashtagTap != null) onHashtagTap!(hashtagMatch);
            },
        ));
      } else if (mentionMatch != null) {
        spans.add(TextSpan(
          text: mentionMatch,
          style: mentionStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              if (onMentionTap != null)
                onMentionTap!(mentionMatch.substring(1)); // Remove '@'
            },
        ));
      }

      lastEnd = match.end;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: defaultStyle,
        children: spans,
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign ?? TextAlign.start,
    );
  }
}
