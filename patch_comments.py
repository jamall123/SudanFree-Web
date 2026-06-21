import re

with open('lib/widgets/comments/comment_tile.dart', 'r') as f:
    content = f.read()

# Add import
if 'package:any_link_preview/any_link_preview.dart' not in content:
    content = content.replace("import '../../core/constants/app_colors.dart';", "import '../../core/constants/app_colors.dart';\nimport 'package:any_link_preview/any_link_preview.dart';")

# Update URL regex pattern
old_regex = "const String urlPattern = r'(?:https?://|www\.)[^\s<>\[\]{}|\\^`\u0600-\u06FF]+';"
new_regex = "const String urlPattern = r'(?:https?:\/\/|www\.)[^\s\u0600-\u06FF()<>]+|\\b[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}(?:\/[^\s\u0600-\u06FF()<>]*)?';"
content = content.replace(old_regex, new_regex)

# Add preview rendering logic to _buildStyledContent
old_return = """    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: RichText(
        text: TextSpan(style: normalStyle, children: spans),
      ),
    );"""

new_return = """    String? firstUrl;
    for (final match in matches) {
      final text = match.group(0)!;
      final bool isMention = RegExp(mentionPattern).hasMatch(text);
      if (!isMention && firstUrl == null) {
        firstUrl = text;
        if (!firstUrl.startsWith('http')) {
          firstUrl = 'https://' + firstUrl;
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AnyLinkPreview(
                  link: firstUrl,
                  displayDirection: UIDirection.uiDirectionHorizontal,
                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                  errorWidget: const SizedBox.shrink(),
                  errorImage: '',
                  cache: const Duration(days: 7),
                  placeholderWidget: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link, color: AppColors.primary.withValues(alpha: 0.5)),
                        const SizedBox(width: 8),
                        Text(
                          Theme.of(context).brightness == Brightness.dark ? 'Loading link...' : 'جاري قراءة الرابط...',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );"""

content = content.replace(old_return, new_return)

with open('lib/widgets/comments/comment_tile.dart', 'w') as f:
    f.write(content)

print("Updated comment_tile.dart")
