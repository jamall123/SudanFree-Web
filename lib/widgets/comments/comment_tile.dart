import '../../l10n/generated/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/comment_model.dart';
import '../../core/constants/app_colors.dart';
import 'package:any_link_preview/any_link_preview.dart';
import '../common/internal_link_preview.dart';

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final bool isMe;
  final int depth;
  final VoidCallback onReply;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLike;
  final VoidCallback? onDelete;
  final bool isLiked;

  const CommentTile({
    super.key,
    required this.comment,
    this.isMe = false,
    this.depth = 0,
    required this.onReply,
    this.onProfileTap,
    this.onLike,
    this.onDelete,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isReply = depth > 0;

    return Padding(
      padding: EdgeInsets.only(
        left: 4,
        right: 4,
        top: isReply ? 3 : 6,
        bottom: isReply ? 3 : 6,
      ),
      child: GestureDetector(
        onLongPress: () => _showCommentOptions(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: isReply ? 14 : 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: comment.userImageUrl != null
                      ? CachedNetworkImageProvider(comment.userImageUrl!)
                      : null,
                  child: comment.userImageUrl == null
                      ? Icon(Icons.person,
                          size: isReply ? 14 : 18, color: AppColors.primary)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reply indicator moved to the TOP
                    if (comment.isReply && comment.parentUserName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.subdirectory_arrow_right,
                                size: 14,
                                color:
                                    AppColors.primary.withValues(alpha: 0.8)),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)!.localeName == 'ar'
                                  ? 'رداً على ${comment.parentUserName}'
                                  : 'Replying to ${comment.parentUserName}',
                              style: TextStyle(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                fontSize: 12, // Increased font size
                                fontWeight: FontWeight.w600, // Made it bold
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Name + Time
                    Row(
                      children: [
                        GestureDetector(
                          onTap: onProfileTap,
                          child: Text(
                            comment.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isReply ? 13 : 14, // Slightly larger
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(comment.createdAt, context),
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    // Comment text with styled @mentions
                    _buildStyledContent(context, comment.content, isReply,
                        comment.mentionedNames),
                    const SizedBox(height: 6),
                    // Actions: Like + Reply aligned on the right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Like button (heart)
                        if (onLike != null)
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onLike!();
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 16,
                                  color: isLiked
                                      ? Colors.red
                                      : (isDark
                                          ? Colors.white38
                                          : Colors.grey[400]),
                                ),
                                if (comment.likesCount > 0) ...[
                                  const SizedBox(width: 3),
                                  Text(
                                    '${comment.likesCount}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isLiked
                                          ? Colors.red
                                          : (isDark
                                              ? Colors.white38
                                              : Colors.grey[400]),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(
                            width: 16), // Spacing between Like and Reply

                        // Reply button
                        if (!isMe)
                          GestureDetector(
                            onTap: onReply,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.reply,
                                    size: 16,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 2),
                                Text(
                                    AppLocalizations.of(context)!.localeName ==
                                            'ar'
                                        ? 'رد'
                                        : 'Reply',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary
                                            .withValues(alpha: 0.7))),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentOptions(BuildContext context) {
    final locale = AppLocalizations.of(context)!.localeName;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(locale == 'ar' ? 'نسخ التعليق' : 'Copy comment'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: comment.content));
                if (context.mounted) Navigator.pop(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(locale == 'ar' ? 'تم النسخ' : 'Copied'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (isMe && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  locale == 'ar' ? 'حذف التعليق' : 'Delete comment',
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  if (context.mounted) Navigator.pop(context);
                  onDelete!();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Builds comment text with @mentions styled in a distinct color
  Widget _buildStyledContent(BuildContext context, String content, bool isReply,
      List<String> mentionedNames) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mentionStyle = TextStyle(
      color: isDark ? const Color(0xFF64B5F6) : AppColors.primary,
      fontWeight: FontWeight.w600,
    );

    final linkStyle = TextStyle(
      color: isDark ? const Color(0xFF64B5F6) : AppColors.primary,
      decoration: TextDecoration.underline,
      decorationColor: (isDark ? const Color(0xFF64B5F6) : AppColors.primary)
          .withValues(alpha: 0.4),
    );

    final normalStyle = TextStyle(
      fontSize: isReply ? 13 : 14,
      height: 1.4,
      color: isDark ? Colors.white : Colors.black87,
    );

    // 1. Prepare Mention Regex
    String mentionPattern = r'@[\u0600-\u06FF\w]+'; // Fallback
    if (mentionedNames.isNotEmpty) {
      final escapedNames = mentionedNames.map((n) => RegExp.escape(n)).toList();
      escapedNames.add(RegExp.escape('الجميع'));
      mentionPattern = escapedNames.map((n) => '@$n').join('|');
    }

    // 2. Prepare URL Regex
    const String urlPattern =
        r'(?:https?://|www\.)[^\s<>\[\]{}|\\^`\u0600-\u06FF]+';

    // 3. Combined Regex with Groups
    final combinedRegex =
        RegExp('($mentionPattern)|($urlPattern)', caseSensitive: false);
    final matches = combinedRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(content, style: normalStyle),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Normal text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }

      final text = match.group(0)!;
      final bool isMention = RegExp(mentionPattern).hasMatch(text);

      if (isMention) {
        spans.add(TextSpan(text: text, style: mentionStyle));
      } else {
        // It's a URL
        spans.add(TextSpan(
          text: text,
          style: linkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              String finalUrl = text;
              if (!text.startsWith('http://') && !text.startsWith('https://')) {
                finalUrl = 'https://$text';
              }
              final uri = Uri.parse(finalUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    String? firstUrl;
    for (final match in matches) {
      final text = match.group(0)!;
      final bool isMention = RegExp(mentionPattern).hasMatch(text);
      if (!isMention && firstUrl == null) {
        firstUrl = text;
        if (!firstUrl.startsWith('http')) {
          firstUrl = 'https://$firstUrl';
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(style: normalStyle, children: spans),
          ),
          if (firstUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InternalLinkPreviewWidget.isInternalLink(firstUrl)
                  ? InternalLinkPreviewWidget(url: firstUrl)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AnyLinkPreview(
                        link: firstUrl,
                        displayDirection: UIDirection.uiDirectionHorizontal,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                        errorWidget: const SizedBox.shrink(),
                        errorImage: '',
                        cache: const Duration(days: 7),
                        placeholderWidget: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey[100],
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.link,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.5)),
                              const SizedBox(width: 8),
                              Text(
                                Theme.of(context).brightness == Brightness.dark
                                    ? 'Loading link...'
                                    : 'جاري قراءة الرابط...',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime, BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final locale = AppLocalizations.of(context)!.localeName;
    if (diff.inDays > 0)
      return locale == 'ar' ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    if (diff.inHours > 0)
      return locale == 'ar'
          ? 'منذ ${diff.inHours} ساعة'
          : '${diff.inHours}h ago';
    if (diff.inMinutes > 0)
      return locale == 'ar'
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    return locale == 'ar' ? 'الآن' : 'now';
  }
}
