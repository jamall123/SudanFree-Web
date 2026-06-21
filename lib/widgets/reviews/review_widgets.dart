import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/review_model.dart';
import '../../providers/locale_provider.dart';
import '../../views/profile/profile_screen.dart';
import '../common/glass_container.dart';

class AddReviewDialog extends StatefulWidget {
  final String freelancerId;
  final String targetName;
  final String? targetImageUrl;
  final String? jobId;
  final String? jobTitle;
  final bool isShop;
  final Future<void> Function(double rating, String comment, bool isNegative,
      bool isJobCompleted, bool? wouldWorkAgain) onSubmit;

  const AddReviewDialog({
    super.key,
    required this.freelancerId,
    required this.targetName,
    this.targetImageUrl,
    this.jobId,
    this.jobTitle,
    this.isShop = false,
    required this.onSubmit,
  });

  @override
  State<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends State<AddReviewDialog> {
  double _rating = 0;
  final bool _isNegative = false;
  bool _isJobCompleted = false;
  bool? _wouldWorkAgain; // سؤال الضمان الاجتماعي
  final _commentController = TextEditingController();
  bool _isSubmitting = false; // Prevent double-submit and rapid taps

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: widget.targetImageUrl != null
                ? CachedNetworkImageProvider(widget.targetImageUrl!)
                : null,
            child: widget.targetImageUrl == null
                ? Text(
                    widget.targetName.isNotEmpty
                        ? widget.targetName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              locale == 'ar'
                  ? 'تقييم ${widget.targetName}'
                  : 'Rate ${widget.targetName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.jobTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  widget.jobTitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),

            // Star Rating
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return GestureDetector(
                    onTap: () => setState(() => _rating = index + 1.0),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          index < _rating ? Icons.star : Icons.star_border,
                          color: index < _rating
                              ? _getStarColor(_rating)
                              : Colors.grey.withValues(alpha: 0.3),
                          size: 36,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _getRatingText(_rating, locale),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            const SizedBox(height: 16),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: locale == 'ar'
                    ? 'اكتب تعليقك (اختياري)'
                    : 'Write a comment (optional)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Job Completion Check
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: CheckboxListTile(
                value: _isJobCompleted,
                onChanged: (v) => setState(() => _isJobCompleted = v ?? false),
                title: Text(
                  widget.isShop
                      ? (locale == 'ar'
                          ? 'هل تمت عملية الشراء بنجاح؟'
                          : 'Was the purchase completed successfully?')
                      : (locale == 'ar'
                          ? 'هل أكمل الحرفي العمل بنجاح؟'
                          : 'Did the freelancer complete the work?'),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                activeColor: AppColors.primary,
                dense: true,
              ),
            ),

            const SizedBox(height: 12),

            // Social Proof
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.sudanGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.sudanGold.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isShop
                        ? (locale == 'ar'
                            ? 'هل تنصح بالشراء منه؟'
                            : 'Would you recommend them?')
                        : (locale == 'ar'
                            ? 'هل ستتعامل معه مرة أخرى؟'
                            : 'Would you work with them again?'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _wouldWorkAgain = true),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _wouldWorkAgain == true
                                ? Colors.green.withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                                color: _wouldWorkAgain == true
                                    ? Colors.green
                                    : Colors.grey[300]!),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            locale == 'ar' ? 'نعم' : 'Yes',
                            style: TextStyle(
                                color: _wouldWorkAgain == true
                                    ? Colors.green
                                    : Colors.grey[700],
                                fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _wouldWorkAgain = false),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: _wouldWorkAgain == false
                                ? Colors.red.withValues(alpha: 0.1)
                                : null,
                            side: BorderSide(
                                color: _wouldWorkAgain == false
                                    ? Colors.red
                                    : Colors.grey[300]!),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            locale == 'ar' ? 'لا' : 'No',
                            style: TextStyle(
                                color: _wouldWorkAgain == false
                                    ? Colors.red
                                    : Colors.grey[700],
                                fontSize: 12),
                          ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(locale == 'ar' ? 'إلغاء' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: (_rating > 0 && !_isSubmitting)
              ? () async {
                  final navigator = Navigator.of(context);
                  setState(() => _isSubmitting = true);
                  try {
                    await widget.onSubmit(
                        _rating,
                        _commentController.text.trim(),
                        _isNegative,
                        _isJobCompleted,
                        _wouldWorkAgain);
                    if (!mounted) return;
                    navigator.pop();
                  } catch (e) {
                    // Fall through — we'll re-enable the button after a short cooldown below
                  } finally {
                    // Keep button disabled briefly to prevent rapid double-taps
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _isSubmitting = false);
                    });
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(locale == 'ar' ? 'إرسال' : 'Submit'),
        ),
      ],
    );
  }

  String _getRatingText(double rating, String locale) {
    if (rating == 0) return locale == 'ar' ? 'اضغط لتقييم' : 'Tap to rate';
    if (rating <= 1) return locale == 'ar' ? 'سيء' : 'Poor';
    if (rating <= 2) return locale == 'ar' ? 'مقبول' : 'Fair';
    if (rating <= 3) return locale == 'ar' ? 'جيد' : 'Good';
    if (rating <= 4) return locale == 'ar' ? 'جيد جداً' : 'Very Good';
    return locale == 'ar' ? 'ممتاز' : 'Excellent';
  }

  Color _getStarColor(double rating) {
    if (rating == 0) return Colors.grey;
    if (rating <= 1) return Colors.black87; // نجمة واحدة: أسود
    if (rating <= 2) return Colors.red; // نجمتان: أحمر
    if (rating <= 3) return Colors.amber; // ٣ نجوم: أصفر
    return Colors.green; // ٤ إلى ٥ نجوم: أخضر
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

// Review Card Widget
class ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final String locale;

  const ReviewCard({super.key, required this.review, required this.locale});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      blur: 15,
      opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(userId: review.reviewerId),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: review.reviewerImageUrl != null
                      ? CachedNetworkImageProvider(review.reviewerImageUrl!)
                      : null,
                  child: review.reviewerImageUrl == null
                      ? Text(review.reviewerName[0].toUpperCase())
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName,
                        style: Theme.of(context).textTheme.titleSmall),
                    Row(
                      children: [
                        ...List.generate(
                            5,
                            (i) => Icon(
                                  i < review.rating.round()
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: i < review.rating.round()
                                      ? _getCardStarColor(review.rating.round())
                                      : Colors.grey.withValues(alpha: 0.3),
                                  size: 14,
                                )),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(review.comment!,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (review.jobTitle != null && review.jobTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${locale == 'ar' ? 'المشروع' : 'Project'}: ${review.jobTitle}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],

          // === مؤشر الضمان الاجتماعي ===
          if (review.wouldWorkAgain != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: review.wouldWorkAgain!
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: review.wouldWorkAgain!
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.red.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    review.wouldWorkAgain! ? Icons.thumb_up : Icons.thumb_down,
                    size: 14,
                    color: review.wouldWorkAgain! ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    review.wouldWorkAgain!
                        ? (locale == 'ar'
                            ? 'سأتعامل معه مرة أخرى'
                            : 'Would work again')
                        : (locale == 'ar'
                            ? 'لا أنصح بالتعامل'
                            : 'Would not recommend'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: review.wouldWorkAgain!
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getCardStarColor(int stars) {
    if (stars <= 1) return Colors.black87;
    if (stars <= 2) return Colors.red;
    if (stars <= 3) return Colors.amber;
    return Colors.green;
  }
}

class ReviewStatsWidget extends StatelessWidget {
  final List<ReviewModel> reviews;
  final String locale;

  const ReviewStatsWidget(
      {super.key, required this.reviews, required this.locale});

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    final totalReviews = reviews.length;
    double averageRating =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / totalReviews;
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

    for (var r in reviews) {
      final rInt = r.rating.round();
      if (counts.containsKey(rInt)) {
        counts[rInt] = counts[rInt]! + 1;
      }
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      blur: 15,
      opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).cardColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Average Rating Circle
          Column(
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style:
                    const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    5,
                    (index) => Icon(
                          index < averageRating.round()
                              ? Icons.star
                              : Icons.star_border,
                          color: index < averageRating.round()
                              ? _getBarColor(averageRating.round())
                              : Colors.grey.withValues(alpha: 0.3),
                          size: 16,
                        )),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalReviews ${locale == 'ar' ? 'تقييم' : 'Reviews'}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Progress Bars
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((stars) {
                final count = counts[stars]!;
                final double percent =
                    totalReviews > 0 ? count / totalReviews : 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text('$stars',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      const Icon(Icons.star, color: Colors.amber, size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _getBarColor(stars)),
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(int stars) {
    if (stars <= 1) return Colors.black87;
    if (stars <= 2) return Colors.red;
    if (stars <= 3) return Colors.amber;
    return Colors.green;
  }
}
