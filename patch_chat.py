import re

with open('lib/views/chat/chat_screen.dart', 'r') as f:
    content = f.read()

# Add import if not exists
if 'package:any_link_preview/any_link_preview.dart' not in content:
    content = content.replace("import '../../widgets/common/linkable_text.dart';", "import '../../widgets/common/linkable_text.dart';\nimport 'package:any_link_preview/any_link_preview.dart';")

# Add helper method
helper_method = """  String? _extractFirstUrl(String text) {
    final RegExp urlRegex = RegExp(
      r'((?:https?:\/\/|www\.)[^\s\u0600-\u06FF()<>]+|\\b[a-zA-Z0-9-]+\\.[a-zA-Z]{2,}(?:\/[^\s\u0600-\u06FF()<>]*)?)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      String url = match.group(0)!;
      if (!url.startsWith('http')) {
        url = 'https://' + url;
      }
      return url;
    }
    return null;
  }"""

if '_extractFirstUrl' not in content:
    # insert before _buildMessageContent
    content = content.replace("  Widget _buildMessageContent(", helper_method + "\n\n  Widget _buildMessageContent(")

# Replace the text message rendering logic to include preview
old_text_render = """            if (message.content.isNotEmpty && message.content != '📷 صورة')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinkableText(text: message.content, style: TextStyle(color: textColor)),
              ),"""

new_text_render = """            if (message.content.isNotEmpty && message.content != '📷 صورة') ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinkableText(text: message.content, style: TextStyle(color: textColor)),
              ),
              if (_extractFirstUrl(message.content) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AnyLinkPreview(
                      link: _extractFirstUrl(message.content)!,
                      displayDirection: UIDirection.uiDirectionVertical,
                      showImage: true,
                      backgroundColor: Colors.grey[200],
                      errorWidget: const SizedBox.shrink(),
                      errorImage: '',
                      cache: const Duration(days: 7),
                    ),
                  ),
                ),
            ],"""

content = content.replace(old_text_render, new_text_render)

old_default_render = """      default:
        return LinkableText(
          text: message.content,
          style: TextStyle(color: textColor, fontSize: 15),
        );"""

new_default_render = """      default:
        return Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            LinkableText(
              text: message.content,
              style: TextStyle(color: textColor, fontSize: 15),
            ),
            if (_extractFirstUrl(message.content) != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AnyLinkPreview(
                    link: _extractFirstUrl(message.content)!,
                    displayDirection: UIDirection.uiDirectionVertical,
                    showImage: true,
                    backgroundColor: Colors.grey[200],
                    errorWidget: const SizedBox.shrink(),
                    errorImage: '',
                    cache: const Duration(days: 7),
                  ),
                ),
              ),
          ],
        );"""

content = content.replace(old_default_render, new_default_render)

with open('lib/views/chat/chat_screen.dart', 'w') as f:
    f.write(content)
print("Updated chat_screen.dart")
