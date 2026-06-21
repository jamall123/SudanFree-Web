import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/user_model.dart';
import '../../../models/review_model.dart';
import '../../../services/firestore_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../widgets/reviews/review_widgets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_error_handler.dart';

class ShopReviewsTab extends StatelessWidget {
  final UserModel user;
  final bool isMe;
  final Stream<List<ReviewModel>> reviewsStream;

  const ShopReviewsTab({
    super.key,
    required this.user,
    required this.isMe,
    required this.reviewsStream,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.reviews,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (!isMe)
              TextButton.icon(
                onPressed: () => showAddReviewDialog(context, user),
                icon: const Icon(Icons.rate_review, size: 18),
                label: Text(l10n.addReview),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildReviewsList(context),
      ],
    );
  }

  Widget _buildReviewsList(BuildContext context) {
    return StreamBuilder<List<ReviewModel>>(
      stream: reviewsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
              child: Text(AppLocalizations.of(context)!.noReviews,
                  style: const TextStyle(color: Colors.grey)));
        }

        return Column(
          children: [
            ReviewStatsWidget(
              reviews: snapshot.data!,
              locale: context.read<LocaleProvider>().locale.languageCode,
            ),
            ...snapshot.data!.map((review) => ReviewCard(
                review: review,
                locale: context.read<LocaleProvider>().locale.languageCode)),
          ],
        );
      },
    );
  }

  static void showAddReviewDialog(BuildContext context, UserModel user) async {
    final l10n = AppLocalizations.of(context)!;
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.loginToReview)));
      return;
    }

    final hasCompletedJob = await FirestoreService().hasCompletedJob(
      currentUser.id,
      user.id,
    );

    if (!context.mounted) return;

    if (!hasCompletedJob) {
      final isArabic = context.read<LocaleProvider>().isArabic;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(isArabic
                      ? 'يجب إكمال اتفاق أولاً'
                      : 'Complete an Agreement First')),
            ],
          ),
          content: Text(
            isArabic
                ? 'يجب أن يكون هناك اتفاق مكتمل بينك وبين المتجر قبل إضافة تقييم. هذا يضمن مصداقية التقييمات.'
                : 'You must have a completed agreement with this shop before leaving a review. This ensures review credibility.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isArabic ? 'حسناً' : 'OK'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AddReviewDialog(
        freelancerId: user.id,
        targetName: user.name,
        targetImageUrl: user.profileImageUrl,
        isShop: true,
        onSubmit: (rating, comment, isNegative, isJobCompleted,
            wouldWorkAgain) async {
          final messenger = ScaffoldMessenger.of(context);

          final review = ReviewModel(
            id: '',
            freelancerId: user.id,
            reviewerId: currentUser.id,
            reviewerName: currentUser.name,
            reviewerImageUrl: currentUser.profileImageUrl,
            rating: rating,
            comment: comment,
            isNegative: isNegative,
            wouldWorkAgain: wouldWorkAgain,
            createdAt: DateTime.now(),
          );

          try {
            await FirestoreService().createReview(review, isJobCompleted: false);
            debugPrint('Review added successfully for job completion check');

            messenger.showSnackBar(SnackBar(
                content: Text(l10n.reviewAddedSuccessfully),
                backgroundColor: AppColors.success));
          } catch (e, stack) {
            if (context.mounted) {
              AppErrorHandler.show(context, e, stack,
                  logContext: 'ShopProfile.addReview');
            }
          }
        },
      ),
    );
  }
}
