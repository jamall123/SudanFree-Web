import re

with open('lib/views/posts/post_details_screen.dart', 'r') as f:
    content = f.read()

# Add imports
imports = """import '../../providers/posts_provider.dart';
import '../../views/posts/comments_sheet.dart';
import '../profile/profile_screen.dart';
import '../../services/cloudinary_service.dart';
"""
if "import '../../providers/posts_provider.dart';" not in content:
    content = content.replace("import '../../services/firestore_service.dart';", "import '../../services/firestore_service.dart';\n" + imports)

# Replace Stats Row with interactive Actions Bar + Owner Header
stats_pattern = r'// Stats Row.*?padding: const EdgeInsets\.symmetric\(horizontal: 16\),.*?child: Row\(.*?children: \[.*?\],.*?\),.*?\),'
stats_match = re.search(stats_pattern, content, re.DOTALL)

owner_header_and_actions = """
                      // --- Owner Header ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.post.userId)));
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                backgroundImage: widget.post.userImageUrl != null
                                    ? CachedNetworkImageProvider(CloudinaryService.getOptimizedUrl(widget.post.userImageUrl!, width: 100, quality: 'auto'))
                                    : null,
                                child: widget.post.userImageUrl == null
                                    ? Text(
                                        widget.post.userName.isNotEmpty ? widget.post.userName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.post.userName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (widget.post.userJobTitle != null && widget.post.userJobTitle!.isNotEmpty)
                                      Text(
                                        widget.post.userJobTitle!,
                                        style: const TextStyle(color: AppColors.primary, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // --- Interactive Actions Bar ---
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          final currentUserId = auth.user?.id ?? '';
                          return Consumer<PostsProvider>(
                            builder: (context, postsProvider, _) {
                              // Get latest post data if available in provider, else use widget.post
                              final latestPost = postsProvider.posts.firstWhere((p) => p.id == widget.post.id, orElse: () => widget.post);
                              final isLiked = latestPost.reactions.containsKey(currentUserId);
                              final totalReactions = latestPost.totalReactions;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    // Like Button
                                    InkWell(
                                      onTap: () {
                                        if (currentUserId.isEmpty) return;
                                        final type = isLiked ? 'unlike' : 'like';
                                        postsProvider.reactToPost(
                                          latestPost.id,
                                          currentUserId,
                                          auth.user?.name ?? '',
                                          latestPost.userId,
                                          type,
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                              color: isLiked ? Colors.red : Colors.grey[600],
                                              size: 22,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              totalReactions > 0 ? '$totalReactions' : '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: isLiked ? Colors.red : Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Comment Button
                                    InkWell(
                                      onTap: () {
                                        showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => CommentsSheet(postId: latestPost.id, postOwnerId: latestPost.userId),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey[600], size: 22),
                                            const SizedBox(width: 6),
                                            Text(
                                              latestPost.commentsCount > 0 ? '${latestPost.commentsCount}' : '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
"""

if stats_match:
    content = content.replace(stats_match.group(0), owner_header_and_actions)

with open('lib/views/posts/post_details_screen.dart', 'w') as f:
    f.write(content)
