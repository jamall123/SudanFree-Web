with open('lib/views/chat/chat_screen.dart', 'r') as f:
    content = f.read()

# Add import
if "import '../../widgets/common/internal_link_preview.dart';" not in content:
    content = content.replace("import 'package:any_link_preview/any_link_preview.dart';", "import 'package:any_link_preview/any_link_preview.dart';\nimport '../../widgets/common/internal_link_preview.dart';")

# Replace AnyLinkPreview logic block 1
old_block = """                    child: AnyLinkPreview(
                      link: _extractFirstUrl(message.content)!,
                      displayDirection: UIDirection.uiDirectionVertical,
                      backgroundColor: Colors.grey[200],
                      errorWidget: const SizedBox.shrink(),
                      errorImage: '',
                      cache: const Duration(days: 7),
                      placeholderWidget: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[200]),
                        child: Row(
                          children: [
                            const Icon(Icons.link, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text(
                              'جاري تحميل الرابط...',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),"""

new_block = """                    child: InternalLinkPreviewWidget.isInternalLink(_extractFirstUrl(message.content)!)
                        ? InternalLinkPreviewWidget(url: _extractFirstUrl(message.content)!)
                        : AnyLinkPreview(
                            link: _extractFirstUrl(message.content)!,
                            displayDirection: UIDirection.uiDirectionVertical,
                            backgroundColor: Colors.grey[200],
                            errorWidget: const SizedBox.shrink(),
                            errorImage: '',
                            cache: const Duration(days: 7),
                            placeholderWidget: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.grey[200]),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'جاري تحميل الرابط...',
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),"""

content = content.replace(old_block, new_block)

# Replace AnyLinkPreview logic block 2 (for normal message)
old_block_2 = """                  child: AnyLinkPreview(
                    link: _extractFirstUrl(message.content)!,
                    displayDirection: UIDirection.uiDirectionVertical,
                    backgroundColor: Colors.grey[200],
                    errorWidget: const SizedBox.shrink(),
                    errorImage: '',
                    cache: const Duration(days: 7),
                    placeholderWidget: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.grey[200]),
                      child: Row(
                        children: [
                          const Icon(Icons.link, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text(
                            'جاري تحميل الرابط...',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),"""

new_block_2 = """                  child: InternalLinkPreviewWidget.isInternalLink(_extractFirstUrl(message.content)!)
                      ? InternalLinkPreviewWidget(url: _extractFirstUrl(message.content)!)
                      : AnyLinkPreview(
                          link: _extractFirstUrl(message.content)!,
                          displayDirection: UIDirection.uiDirectionVertical,
                          backgroundColor: Colors.grey[200],
                          errorWidget: const SizedBox.shrink(),
                          errorImage: '',
                          cache: const Duration(days: 7),
                          placeholderWidget: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey[200]),
                            child: Row(
                              children: [
                                const Icon(Icons.link, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text(
                                  'جاري تحميل الرابط...',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),"""

content = content.replace(old_block_2, new_block_2)

with open('lib/views/chat/chat_screen.dart', 'w') as f:
    f.write(content)

