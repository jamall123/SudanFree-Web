import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../models/post_model.dart';
import 'package:provider/provider.dart';
import '../../providers/posts_provider.dart';

class PollWidget extends StatelessWidget {
  final PostModel post;
  final String currentUserId;

  const PollWidget({
    super.key,
    required this.post,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    if (post.poll == null) return const SizedBox.shrink();

    final poll = post.poll!;
    final totalVotes = poll.totalVotes;
    final hasVoted = poll.hasVoted(currentUserId);
    final isExpired = poll.isExpired;
    final isOwner = post.userId == currentUserId;
    final showResults = hasVoted || isExpired || isOwner;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded,
                  color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(poll.options.length, (index) {
            final option = poll.options[index];
            final optionVotes = option.voterIds.length;
            final percentage =
                totalVotes > 0 ? (optionVotes / totalVotes) : 0.0;
            final isMyVote = option.voterIds.contains(currentUserId);

            final Color barColor = isMyVote
                ? AppColors.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMyVote ? AppColors.primary : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (isExpired ||
                          (isOwner &&
                              !hasVoted &&
                              !poll.options.any(
                                  (o) => o.voterIds.contains(currentUserId)))) {
                        // Owners can still vote if they want, but usually polls allow it.
                      }
                      context
                          .read<PostsProvider>()
                          .voteInPoll(post.id, index, currentUserId);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (showResults)
                          Positioned.fill(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    width: constraints.maxWidth * percentage,
                                    height: constraints.maxHeight,
                                    decoration: BoxDecoration(
                                      color: barColor.withValues(
                                          alpha: isMyVote ? 0.2 : 0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: showResults
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (isMyVote) ...[
                                      const Icon(Icons.check_circle_rounded,
                                          color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                    ],
                                    Flexible(
                                      child: Text(
                                        option.text,
                                        textAlign: showResults
                                            ? TextAlign.start
                                            : TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isMyVote
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isMyVote
                                              ? AppColors.primary
                                              : (isDark
                                                  ? Colors.white
                                                  : Colors.black87),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showResults)
                                Text(
                                  '${(percentage * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: barColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes ${totalVotes == 1 ? 'صوت' : 'أصوات'}',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isExpired)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'انتهى التصويت',
                    style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
