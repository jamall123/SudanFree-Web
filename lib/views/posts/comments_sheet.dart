import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/comment_model.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/firestore_service.dart';
import '../../providers/posts_provider.dart';
import '../../widgets/comments/comment_tile.dart';
import '../profile/profile_screen.dart';
import '../../widgets/mentions/mention_overlay.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  late final Stream<List<CommentModel>> _commentsStream;

  bool _isSending = false;

  // Reply State
  String? _parentId;
  String? _replyingToName;
  String? _parentUserId;
  final Map<String, int> _visibleRepliesCount =
      {}; // Track how many replies are visible

  // Mentions State
  bool _showMentions = false;
  List<UserModel> _allPartners = [];
  List<UserModel> _filteredPartners = [];
  final Map<String, String> _mentionedUsers = {}; // Name -> ID

  // Rate Limiting: track mention notifications sent in this session
  // Prevents sending duplicate mention notifs to same user in same comment session
  final Set<String> _sentMentionNotifs = {}; // userId set

  @override
  void initState() {
    super.initState();
    _commentsStream = _firestoreService.getPostComments(widget.postId);
    _fetchPartners();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchPartners() {
    final authProvider = context.read<AuthProvider>();
    // Ensure partners are loaded
    authProvider.fetchPartners().then((_) {
      if (mounted) {
        setState(() {
          _allPartners = authProvider.partners;
          _filteredPartners = _allPartners;
        });
      }
    });
  }

  void _onTextChanged(String text) {
    final selection = _commentController.selection;
    if (selection.baseOffset < 0) return;

    final textBeforeCursor =
        text.isEmpty ? '' : text.substring(0, selection.baseOffset);
    final lastAtSymbol = textBeforeCursor.lastIndexOf('@');

    if (lastAtSymbol != -1) {
      final query = textBeforeCursor.substring(lastAtSymbol + 1).toLowerCase();
      // Close if newline encountered after @
      if (query.contains('\n')) {
        if (_showMentions) setState(() => _showMentions = false);
        return;
      }

      final newFiltered = _allPartners.where((user) {
        return user.name.toLowerCase().contains(query);
      }).toList();

      // Only update state if necessary
      if (!_showMentions || _filteredPartners.length != newFiltered.length) {
        setState(() {
          _showMentions = true;
          _filteredPartners = newFiltered;
        });
      }
    } else {
      if (_showMentions) setState(() => _showMentions = false);
    }
  }

  void _selectMention(UserModel user) {
    final text = _commentController.text;
    final selection = _commentController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSymbol = textBeforeCursor.lastIndexOf('@');

    if (lastAtSymbol != -1) {
      final newText = text.replaceRange(
        lastAtSymbol,
        selection.baseOffset,
        '@${user.name} ',
      );

      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: lastAtSymbol + user.name.length + 2),
      );

      _mentionedUsers['@${user.name}'] = user.id;
      setState(() => _showMentions = false);
    }
  }

  void _selectAllPartners() {
    // Logic to mention everyone
    // For simplicity, we just add a special tag or just treat it as a broadcast
    // Here we'll just add text @الجميع and maybe handle it server side or explicitly here
    final text = _commentController.text;
    final selection = _commentController.selection;
    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAtSymbol = textBeforeCursor.lastIndexOf('@');

    if (lastAtSymbol != -1) {
      final newText = text.replaceRange(
        lastAtSymbol,
        selection.baseOffset,
        '@الجميع ',
      );

      _commentController.text = newText;
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: lastAtSymbol + 8), // length of @الجميع + space
      );

      // Add all partners to mentioned list
      for (var p in _allPartners) {
        _mentionedUsers['@${p.name}'] = p.id;
      }
      setState(() => _showMentions = false);
    }
  }

  void _startReply(
      String parentId, String replyingToName, String parentUserId) {
    setState(() {
      _parentId = parentId;
      _replyingToName = replyingToName;
      _parentUserId = parentUserId;
    });
    // Add focus to text field
    FocusScope.of(context).requestFocus(_commentFocusNode);
  }

  void _cancelReply() {
    setState(() {
      _parentId = null;
      _replyingToName = null;
      _parentUserId = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() => _isSending = true);

    try {
      // Extract full mentioned names (without @) for storage
      final mentionedNames =
          _mentionedUsers.keys.map((k) => k.replaceFirst('@', '')).toList();

      await context.read<PostsProvider>().addComment(
            postId: widget.postId,
            postOwnerId: widget.postOwnerId,
            userId: user.id,
            userName: user.name,
            userImageUrl: user.profileImageUrl,
            content: text,
            parentId: _parentId,
            parentUserName: _replyingToName,
            parentUserId: _parentUserId,
            mentionedNames: mentionedNames,
          );

      // Handle Notifications for Mentions
      String cleanTextForNotification(String raw) {
        return raw.replaceAllMapped(RegExp(r'@[\u0600-\u06FF\w]+'), (match) {
          return match.group(0)!.substring(1);
        });
      }

      final cleanedText = cleanTextForNotification(text);
      final truncatedText = cleanedText.length > 30
          ? '${cleanedText.substring(0, 30)}...'
          : cleanedText;

      // Check if @الجميع was used — send to ALL partners (capped at 20 to avoid write flood)
      if (text.contains('@الجميع')) {
        final recipients = _allPartners
            .where((p) => p.id != user.id && !_sentMentionNotifs.contains(p.id))
            .take(20) // Cap to 20 recipients
            .toList();
        for (var partner in recipients) {
          _sentMentionNotifs.add(partner.id);
          final notif = NotificationModel(
            id: '',
            userId: partner.id,
            type: NotificationType.mention,
            title: 'منشن جديد',
            message: 'ذكرك ${user.name} في تعليق: "$truncatedText"',
            createdAt: Timestamp.now(),
            relatedId: widget.postId,
          );
          await _firestoreService.sendNotification(notif);
        }
      } else {
        // Send individual mention notifications (skip already-notified users this session)
        for (var entry in _mentionedUsers.entries) {
          if (text.contains(entry.key.trim()) &&
              !_sentMentionNotifs.contains(entry.value)) {
            _sentMentionNotifs.add(entry.value);
            final notif = NotificationModel(
              id: '',
              userId: entry.value,
              type: NotificationType.mention,
              title: 'منشن جديد',
              message: 'ذكرك ${user.name} في تعليق: "$truncatedText"',
              createdAt: Timestamp.now(),
              relatedId: widget.postId,
            );
            await _firestoreService.sendNotification(notif);
          }
        }
      }

      if (mounted) {
        _commentController.clear();
        _mentionedUsers.clear();
        _cancelReply();
        setState(() => _isSending = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        final errorLocale = context.read<LocaleProvider>().locale.languageCode;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(errorLocale == 'ar'
                ? 'حدث خطأ أثناء إضافة التعليق'
                : 'Error adding comment'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    // Check if it's the current user's comment to hide Action button if needed?
    // CommentTile uses 'isMe' to hide reply button.
    final currentUser = context.read<AuthProvider>().user;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Header — drag handle + title + count
              Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<CommentModel>>(
                    stream: _commentsStream,
                    builder: (context, snap) {
                      final count = snap.data?.length ?? 0;
                      return Text(
                        locale == 'ar'
                            ? 'التعليقات ($count)'
                            : 'Comments ($count)',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Divider(
                      height: 1,
                      color: Theme.of(context)
                          .dividerColor
                          .withValues(alpha: 0.3)),
                ],
              ),

              // Comments List
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: _commentsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(
                        itemCount: 4,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) =>
                            _buildCommentSkeleton(context),
                      );
                    }

                    final allComments = snapshot.data ?? [];

                    if (allComments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              locale == 'ar'
                                  ? 'لا توجد تعليقات بعد'
                                  : 'No comments yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              locale == 'ar'
                                  ? 'كن أول من يعلق! 💬'
                                  : 'Be the first to comment! 💬',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[400],
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Build a map of all replies grouped by their parentId
                    final repliesMap = <String, List<CommentModel>>{};
                    for (var c in allComments) {
                      if (c.parentId != null) {
                        repliesMap.putIfAbsent(c.parentId!, () => []).add(c);
                      }
                    }

                    final topComments =
                        allComments.where((c) => c.parentId == null).toList();

                    // Depth colors for the connecting line
                    Color depthColor(int d) {
                      if (d == 1)
                        return AppColors.primary.withValues(alpha: 0.5);
                      if (d == 2)
                        return AppColors.sudanGold.withValues(alpha: 0.7);
                      if (d == 3) return Colors.purple.withValues(alpha: 0.5);
                      if (d >= 4) return Colors.teal.withValues(alpha: 0.5);
                      return Colors.transparent;
                    }

                    Widget buildCommentWidget(CommentModel comment, int depth) {
                      final isLiked = currentUser != null &&
                          comment.likedBy.contains(currentUser.id);
                      return CommentTile(
                        comment: comment,
                        isMe: currentUser?.id == comment.userId,
                        depth: depth,
                        isLiked: isLiked,
                        onReply: () => _startReply(
                            comment.id, comment.userName, comment.userId),
                        onProfileTap: () {
                          if (context.mounted) Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProfileScreen(userId: comment.userId)));
                        },
                        onLike: currentUser != null
                            ? () {
                                _firestoreService.toggleCommentLike(
                                    widget.postId,
                                    comment.id,
                                    currentUser.id,
                                    !isLiked);
                              }
                            : null,
                        onDelete: (currentUser?.id == comment.userId)
                            ? () async {
                                try {
                                  final postsProvider =
                                      context.read<PostsProvider>();
                                  await _firestoreService.deleteComment(
                                      widget.postId, comment.id);
                                  if (context.mounted) {
                                    postsProvider
                                        .decrementCommentCount(widget.postId);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    final localeStr = context
                                        .read<LocaleProvider>()
                                        .locale
                                        .languageCode;
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                          content: Text(localeStr == 'ar'
                                              ? 'حدث خطأ أثناء حذف التعليق'
                                              : 'Error deleting comment')),
                                    );
                                  }
                                }
                              }
                            : null,
                      );
                    }

                    List<Widget> buildCommentTree(
                        CommentModel parent, int currentDepth) {
                      final replies = repliesMap[parent.id] ?? [];
                      replies
                          .sort((a, b) => a.createdAt.compareTo(b.createdAt));

                      final widgets = <Widget>[
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: currentDepth * 24.0,
                          ),
                          child: currentDepth > 0
                              ? IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        width: 3,
                                        decoration: BoxDecoration(
                                          color: depthColor(currentDepth),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: buildCommentWidget(
                                              parent, currentDepth)),
                                    ],
                                  ),
                                )
                              : buildCommentWidget(parent, currentDepth),
                        ),
                      ];

                      if (replies.isEmpty) return widgets;

                      // Collapsible: show 0 replies initially, then 4 by 4
                      final visibleCount = _visibleRepliesCount[parent.id] ?? 0;
                      final visibleReplies =
                          replies.take(visibleCount).toList();
                      final hiddenCount =
                          replies.length - visibleReplies.length;
                      final nextDepth = currentDepth < 3 ? currentDepth + 1 : 3;

                      for (var reply in visibleReplies) {
                        widgets.addAll(buildCommentTree(reply, nextDepth));
                      }

                      // Show more button
                      if (hiddenCount > 0) {
                        widgets.add(
                          Padding(
                            padding: EdgeInsetsDirectional.only(
                                start: nextDepth * 24.0 + 12),
                            child: GestureDetector(
                              onTap: () => setState(() =>
                                  _visibleRepliesCount[parent.id] =
                                      visibleCount + 4),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.subdirectory_arrow_right,
                                        size: 14, color: depthColor(nextDepth)),
                                    const SizedBox(width: 4),
                                    Text(
                                      locale == 'ar'
                                          ? (visibleCount == 0
                                              ? 'عرض الردود ($hiddenCount)'
                                              : 'عرض ردود أخرى ($hiddenCount)')
                                          : (visibleCount == 0
                                              ? 'Show replies ($hiddenCount)'
                                              : 'Show more replies ($hiddenCount)'),
                                      style: TextStyle(
                                        color: depthColor(nextDepth),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return widgets;
                    }

                    return ListView.builder(
                      key: const PageStorageKey('comments_list'),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: topComments.length,
                      itemBuilder: (context, index) {
                        final comment = topComments[index];
                        return Column(
                          key: ValueKey('comment_tree_${comment.id}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: buildCommentTree(comment, 0),
                        );
                      },
                    );
                  },
                ),
              ),

              // Input Area
              SafeArea(
                child: Container(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.border.withValues(alpha: 0.3))),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply Indicator
                      if (_replyingToName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.reply,
                                  size: 16,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  locale == 'ar'
                                      ? 'الرد على $_replyingToName'
                                      : 'Replying to $_replyingToName',
                                  style: TextStyle(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: _cancelReply,
                                child: Icon(Icons.close,
                                    size: 16,
                                    color: AppColors.primary
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),

                      // Input Row
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              focusNode: _commentFocusNode,
                              onChanged: _onTextChanged,
                              decoration: InputDecoration(
                                hintText: _parentId == null
                                    ? (locale == 'ar'
                                        ? 'اكتب تعليقاً... (@لذكر زميل)'
                                        : 'Write a comment... (@ to mention)')
                                    : (locale == 'ar'
                                        ? 'اكتب رداً...'
                                        : 'Write a reply...'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor:
                                    AppColors.border.withValues(alpha: 0.1),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  onPressed: _submitComment,
                                  icon: const Icon(Icons.send,
                                      color: AppColors.primary),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mentions Overlay
          if (_showMentions)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 10
                  : 80,
              left: 16,
              right: 16,
              child: MentionOverlay(
                partners: _filteredPartners,
                locale: locale,
                onSelectAll:
                    _filteredPartners.length > 1 ? _selectAllPartners : null,
                onSelectUser: _selectMention,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: baseColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 14,
                    width: 100,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Shimmer.fromColors(
                  baseColor: baseColor,
                  highlightColor: highlightColor,
                  child: Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
