import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/locale_provider.dart';
import 'chat_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/common/empty_state_widget.dart';
import '../../models/message_model.dart';
import '../../widgets/common/glass_container.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<ChatProvider>().fetchChats(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'ar' ? 'المحادثات' : 'Chats'),
        centerTitle: true,
      ),
      body: Selector<ChatProvider, _ChatListState>(
        selector: (_, provider) =>
            _ChatListState(provider.chats, provider.isLoading),
        builder: (context, state, _) {
          final chats = state.chats;

          if (state.isLoading && chats.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chats.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.chat_bubble_outline_rounded,
              title: locale == 'ar'
                  ? 'لا توجد محادثات سابقة'
                  : 'No previous chats',
              subtitle: locale == 'ar'
                  ? 'تواصل مع الحرفيين أو المتاجر للاتفاق على الخدمات.'
                  : 'Contact freelancers or shops to agree on services.',
              actionLabel: locale == 'ar' ? 'ابحث الآن' : 'Search Now',
              actionIcon: Icons.search_rounded,
              onAction: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await context.read<ChatProvider>().fetchChats(user.id);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final otherName = chat.getOtherParticipantName(user.id);
                final otherImage = chat.getOtherParticipantImage(user.id);
                final unreadCount = chat.getUnreadCount(user.id);
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return GlassContainer(
                  key: ValueKey('chat_${chat.id}'),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  blur: 15,
                  opacity: isDark ? 0.3 : 0.6,
                  color: unreadCount > 0
                      ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(chat: chat),
                        ),
                      ).then((_) {
                        // تحديث القائمة عند الرجوع من المحادثة (قد يكون تم قراءة رسائل)
                        if (context.mounted) {
                          context.read<ChatProvider>().fetchChats(user.id);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            backgroundImage:
                                otherImage != null && otherImage.isNotEmpty
                                    ? CachedNetworkImageProvider(otherImage,
                                        maxWidth: 150, maxHeight: 150)
                                    : null,
                            child: otherImage == null || otherImage.isEmpty
                                ? Text(
                                    otherName.isNotEmpty
                                        ? otherName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Name + Last message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  otherName,
                                  style: TextStyle(
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w800
                                        : FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  chat.lastMessage ??
                                      (locale == 'ar'
                                          ? 'بدأت المحادثة'
                                          : 'Chat started'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? (isDark
                                            ? Colors.white70
                                            : Colors.black87)
                                        : Colors.grey[500],
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Time + Unread badge
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (chat.lastMessageTime != null)
                                Text(
                                  timeago.format(chat.lastMessageTime!,
                                      locale: locale),
                                  style: TextStyle(
                                    color: unreadCount > 0
                                        ? AppColors.primary
                                        : Colors.grey[500],
                                    fontSize: 11,
                                    fontWeight: unreadCount > 0
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              if (unreadCount > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ChatListState {
  final List<ChatModel> chats;
  final bool isLoading;

  _ChatListState(this.chats, this.isLoading);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ChatListState &&
          runtimeType == other.runtimeType &&
          chats == other.chats &&
          isLoading == other.isLoading;

  @override
  int get hashCode => chats.hashCode ^ isLoading.hashCode;
}
