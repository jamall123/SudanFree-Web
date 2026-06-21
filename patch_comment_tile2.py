with open('lib/widgets/comments/comment_tile.dart', 'r') as f:
    content = f.read()

# Add import
if "import 'internal_link_preview.dart';" not in content:
    content = content.replace("import 'package:any_link_preview/any_link_preview.dart';", "import 'package:any_link_preview/any_link_preview.dart';\nimport 'internal_link_preview.dart';")

# replace AnyLinkPreview logic
old_logic = """if (firstUrl != null)
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
            ),"""

new_logic = """if (firstUrl != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InternalLinkPreviewWidget.isInternalLink(firstUrl)
                  ? InternalLinkPreviewWidget(url: firstUrl)
                  : ClipRRect(
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
            ),"""

content = content.replace(old_logic, new_logic)

with open('lib/widgets/comments/comment_tile.dart', 'w') as f:
    f.write(content)
