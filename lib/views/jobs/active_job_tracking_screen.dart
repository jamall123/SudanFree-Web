import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../core/constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/notification_model.dart';
import '../../services/smart_guide_service.dart';
import '../../widgets/reviews/review_widgets.dart';
import '../../models/review_model.dart';
import '../../services/firestore_service.dart';
import 'dart:ui';
import '../../widgets/common/glass_card.dart';

class ActiveJobTrackingScreen extends StatefulWidget {
  final String jobId;

  const ActiveJobTrackingScreen({super.key, required this.jobId});

  @override
  State<ActiveJobTrackingScreen> createState() =>
      _ActiveJobTrackingScreenState();
}

class _ActiveJobTrackingScreenState extends State<ActiveJobTrackingScreen> {
  bool _isAutoCompleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<JobProvider>().fetchJob(widget.jobId);

      SmartGuideService.showMicroTip(
        context,
        messageAr: 'يمكنك تقسيم الدفعات حسب مراحل الإنجاز 📊',
        messageEn: 'You can split payments based on milestones 📊',
        tipId: 'job_tracking_tip',
        icon: Icons.pie_chart_rounded,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final authProvider = context.watch<AuthProvider>();
    final job = jobProvider.selectedJob;
    final currentUser = authProvider.user;

    if (jobProvider.isLoading || job == null) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    final isClient = currentUser?.id == job.clientId;
    final isFreelancer = currentUser?.id == job.assignedFreelancerId;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Debug prints as requested
    debugPrint('contract.id (jobId): ${job.id}');
    debugPrint('milestones.length: ${job.milestones.length}');

    // Safety fallback: Auto-complete if stuck in progress but all milestones are confirmed
    if (job.status == JobStatus.inProgress &&
        job.milestones.isNotEmpty &&
        !_isAutoCompleting) {
      final isAllConfirmed = job.milestones
          .every((ms) => ms.status == MilestoneStatus.confirmedByProvider);
      if (isAllConfirmed) {
        _isAutoCompleting = true;
        Future.microtask(() {
          if (context.mounted) {
            context.read<JobProvider>().completeJob(
                jobId: job.id, freelancerId: job.assignedFreelancerId!);
            // Show dialog only for the client
            if (isClient && job.assignedFreelancerId != null) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AddReviewDialog(
                    freelancerId: job.assignedFreelancerId!,
                    targetName: job.assignedFreelancerName ?? 'الحرفي',
                    jobId: job.id,
                    jobTitle: job.title,
                    onSubmit: (rating, comment, isNegative, isJobCompleted,
                        wouldWorkAgain) async {
                      final review = ReviewModel(
                        id: '',
                        freelancerId: job.assignedFreelancerId!,
                        reviewerId: currentUser!.id,
                        reviewerName: currentUser.name,
                        reviewerImageUrl: currentUser.profileImageUrl,
                        rating: rating,
                        comment: comment,
                        isNegative: isNegative,
                        wouldWorkAgain: wouldWorkAgain,
                        jobId: job.id,
                        jobTitle: job.title,
                        createdAt: DateTime.now(),
                      );
                      try {
                        await FirestoreService().createReview(review,
                            isJobCompleted: isJobCompleted);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تمت إضافة التقييم بنجاح')));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('حدث خطأ أثناء إضافة التقييم')));
                      }
                    },
                  ),
                );
              });
            }
          }
        });
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF0F4F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        title: const Text('إدارة الاتفاق',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (isClient && job.status == JobStatus.inProgress)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => _showCompleteDialog(context, job),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('إكمال الاتفاق'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 400,
            left: 50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildJobHeader(job, isClient, isDark),
                  const SizedBox(height: 24),
                  _buildStatusCard(job, isDark),
                  const SizedBox(height: 24),
                  _buildStepper(job, isDark),
                  const SizedBox(height: 24),

                  if (isClient &&
                      job.status == JobStatus.completed &&
                      job.assignedFreelancerId != null)
                    StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('ratings')
                            .doc('${currentUser!.id}_${job.id}')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return const SizedBox.shrink();

                          if (snapshot.hasData && snapshot.data!.exists) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('تمت إضافة تقييمك لهذا الحرفي بنجاح',
                                      style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            );
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddReviewDialog(
                                    freelancerId: job.assignedFreelancerId!,
                                    targetName:
                                        job.assignedFreelancerName ?? 'الحرفي',
                                    jobId: job.id,
                                    jobTitle: job.title,
                                    onSubmit: (rating, comment, isNegative,
                                        isJobCompleted, wouldWorkAgain) async {
                                      final review = ReviewModel(
                                        id: '',
                                        freelancerId: job.assignedFreelancerId!,
                                        reviewerId: currentUser.id,
                                        reviewerName: currentUser.name,
                                        reviewerImageUrl:
                                            currentUser.profileImageUrl,
                                        rating: rating,
                                        comment: comment,
                                        isNegative: isNegative,
                                        wouldWorkAgain: wouldWorkAgain,
                                        jobId: job.id,
                                        jobTitle: job.title,
                                        createdAt: DateTime.now(),
                                      );
                                      try {
                                        await FirestoreService().createReview(
                                            review,
                                            isJobCompleted: isJobCompleted);
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'تمت إضافة التقييم بنجاح')));
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'حدث خطأ أثناء إضافة التقييم')));
                                      }
                                    },
                                  ),
                                );
                              },
                              icon: const Icon(Icons.star, size: 24),
                              label: const Text('تقييم تجربة العمل مع الحرفي',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          );
                        }),

                  // Progress Section
                  if (job.milestones.isNotEmpty) _buildProgressSection(job),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('دفعات الإنجاز (Milestones)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      if (isClient && job.status == JobStatus.inProgress)
                        TextButton.icon(
                          onPressed: () => _showAddMilestoneSheet(context, job),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('إضافة'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (job.milestones.isEmpty)
                    _buildEmptyMilestones(context, job, isClient, isDark)
                  else
                    ...job.milestones.map((m) => _buildMilestoneTile(
                        context, job, m, isClient, isFreelancer, isDark)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobHeader(JobModel job, bool isClient, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
        borderColor: AppColors.primary.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.handshake,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'الطرف الآخر: ${isClient ? (job.assignedFreelancerName ?? 'لم يتم التحديد بعد') : job.clientName}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                    child: _buildHeaderStat(
                        Icons.payments,
                        '${NumberFormat('#,##0').format(job.budgetMax)} SDG',
                        'الميزانية')),
                Container(
                    height: 30,
                    width: 1,
                    color: Colors.white.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                Expanded(
                    child: _buildHeaderStat(
                        Icons.calendar_today,
                        DateFormat('dd MMM yyyy').format(job.createdAt),
                        'تاريخ البدء')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(JobModel job, bool isDark) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (job.status) {
      case JobStatus.inProgress:
        statusColor = Colors.blue;
        statusText = 'قيد التنفيذ';
        statusIcon = Icons.autorenew;
        break;
      case JobStatus.completed:
        statusColor = Colors.green;
        statusText = 'مكتمل';
        statusIcon = Icons.check_circle;
        break;
      case JobStatus.cancelled:
        statusColor = Colors.red;
        statusText = 'ملغي';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'مفتوح';
        statusIcon = Icons.lock_open;
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: statusColor.withValues(alpha: 0.1),
      borderColor: statusColor.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حالة الاتفاق',
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12)),
                Text(statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(JobModel job, bool isDark) {
    if (job.status == JobStatus.cancelled) return const SizedBox.shrink();

    int currentStep = 0;
    if (job.status == JobStatus.inProgress) {
      currentStep = 1;
    } else if (job.status == JobStatus.completed) {
      currentStep = 2;
    }

    final steps = [
      {'title': 'مفتوح', 'icon': Icons.assignment},
      {'title': 'قيد التنفيذ', 'icon': Icons.play_circle_fill},
      {'title': 'مكتمل', 'icon': Icons.check_circle},
    ];

    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.4),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مسار الاتفاق',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length * 2 - 1, (index) {
              if (index % 2 != 0) {
                // Line
                final stepIndex = index ~/ 2;
                final isPassed = stepIndex < currentStep;
                return Expanded(
                  child: Container(
                    height: 3,
                    color: isPassed
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                  ),
                );
              }
              // Circle
              final stepIndex = index ~/ 2;
              final isActive = stepIndex == currentStep;
              final isPassed = stepIndex < currentStep;
              final color = isPassed || isActive
                  ? AppColors.primary
                  : Colors.grey.withValues(alpha: 0.3);

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive ? color.withValues(alpha: 0.2) : color,
                      shape: BoxShape.circle,
                      border:
                          isActive ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Icon(steps[stepIndex]['icon'] as IconData,
                        size: 16, color: isActive ? color : Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[stepIndex]['title'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive || isPassed
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive || isPassed
                          ? AppColors.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(JobModel job) {
    final totalMilestones = job.milestones.length;
    final completedMilestones =
        job.milestones.where((m) => m.isCompleted).length;
    final progress =
        totalMilestones == 0 ? 0.0 : completedMilestones / totalMilestones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('نسبة الإنجاز',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${(progress * 100).toInt()}%',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text('$completedMilestones من أصل $totalMilestones مراحل مكتملة',
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEmptyMilestones(
      BuildContext context, JobModel job, bool isClient, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Text('لا توجد دفعات محددة بعد',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'قم بتحديد دفعات الإنجاز لتسهيل عملية الدفع وتقسيم العمل على مراحل مريحة للطرفين.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          if (isClient && job.status == JobStatus.inProgress) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddMilestoneSheet(context, job),
              icon: const Icon(Icons.add),
              label: const Text('تحديد دفعة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMilestoneTile(BuildContext context, JobModel job,
      MilestoneModel m, bool isClient, bool isFreelancer, bool isDark) {
    Widget actionWidget = const SizedBox();

    if (m.status == MilestoneStatus.pending && isClient) {
      actionWidget = ElevatedButton.icon(
        onPressed: () => _markMilestoneAsPaid(job, m),
        icon: const Icon(Icons.payment, size: 14),
        label: const Text('لقد دفعت',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else if (m.status == MilestoneStatus.paidByClient && isFreelancer) {
      actionWidget = ElevatedButton.icon(
        onPressed: () => _confirmPaymentReceived(context, job, m),
        icon: const Icon(Icons.thumb_up, size: 14),
        label: const Text('تأكيد الاستلام',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    // Status label (optional display if not actionable)
    Widget statusLabel = const SizedBox();
    if (m.status == MilestoneStatus.confirmedByProvider) {
      statusLabel = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle, color: Colors.green, size: 14),
            SizedBox(width: 4),
            Text('تم الاستلام',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ],
        ),
      );
    } else if (m.status == MilestoneStatus.pending && isFreelancer) {
      statusLabel = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 14),
            SizedBox(width: 4),
            Text('بانتظار الدفع',
                style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ],
        ),
      );
    } else if (m.status == MilestoneStatus.paidByClient && isClient) {
      statusLabel = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.pending, color: Colors.blue, size: 14),
            SizedBox(width: 4),
            Text('بانتظار التأكيد',
                style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ],
        ),
      );
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: m.status == MilestoneStatus.confirmedByProvider
          ? Colors.green.withValues(alpha: 0.5)
          : null,
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    decoration: m.status == MilestoneStatus.confirmedByProvider
                        ? TextDecoration.lineThrough
                        : null,
                    color: m.status == MilestoneStatus.confirmedByProvider
                        ? Colors.grey
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${NumberFormat('#,##0').format(m.amount)} ${job.currency}',
                    style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          if (actionWidget is! SizedBox || statusLabel is! SizedBox) ...[
            const SizedBox(width: 12),
            actionWidget is! SizedBox ? actionWidget : statusLabel,
          ],
        ],
      ),
    );
  }

  void _showAddMilestoneSheet(BuildContext context, JobModel job) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double currentTotal =
        job.milestones.fold(0.0, (acc, m) => acc + m.amount);
    final double remainingAmount = job.budgetMax - currentTotal;

    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم تقسيم كامل المبلغ المتفق عليه بالفعل.'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_task, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Text('إضافة دفعة إنجاز جديدة',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'المبلغ المتبقي للتقسيم: ${NumberFormat('#,##0').format(remainingAmount)} ${job.currency}',
                        style: const TextStyle(
                            color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المرحلة (مثال: الدفعة الأولى)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.05),
                )),
            const SizedBox(height: 16),
            TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'المبلغ (SDG)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.05),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty ||
                      amountController.text.trim().isEmpty) return;

                  final newAmount = double.tryParse(amountController.text) ?? 0;
                  if (newAmount <= 0) return;

                  if (newAmount > remainingAmount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'عذراً، المبلغ يتجاوز المتبقي من الميزانية (${NumberFormat('#,##0').format(remainingAmount)} ${job.currency})'),
                          backgroundColor: Colors.red),
                    );
                    return;
                  }

                  final milestones = List<MilestoneModel>.from(job.milestones);
                  milestones.add(MilestoneModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    amount: newAmount,
                  ));
                  context
                      .read<JobProvider>()
                      .updateMilestones(job.id, milestones);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('إضافة الدفعة',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _markMilestoneAsPaid(JobModel job, MilestoneModel m) {
    final milestones = job.milestones.map((item) {
      if (item.id == m.id) {
        return MilestoneModel(
          id: item.id,
          title: item.title,
          amount: item.amount,
          isCompleted: item.isCompleted,
          isPaid: true,
          isConfirmed: false,
          completedAt: null,
        );
      }
      return item;
    }).toList();
    context.read<JobProvider>().updateMilestones(job.id, milestones);

    _sendNotification(
      targetUserId: job.assignedFreelancerId!,
      title: 'تحويل دفعة',
      message:
          'قام العميل بتأكيد تحويل الدفعة: ${m.title}. يرجى تأكيد الاستلام.',
      jobId: job.id,
    );
  }

  void _confirmPaymentReceived(
      BuildContext context, JobModel job, MilestoneModel m) {
    final milestones = job.milestones.map((item) {
      if (item.id == m.id) {
        return MilestoneModel(
          id: item.id,
          title: item.title,
          amount: item.amount,
          isCompleted: true, // Mark as completed when received
          isPaid: true,
          isConfirmed: true,
          completedAt: DateTime.now(),
        );
      }
      return item;
    }).toList();
    context.read<JobProvider>().updateMilestones(job.id, milestones);

    _sendNotification(
      targetUserId: job.clientId,
      title: 'تم استلام الدفعة',
      message: 'قام مقدم الخدمة بتأكيد استلام الدفعة: ${m.title}.',
      jobId: job.id,
    );

    // Check if job should be auto-completed based STRICTLY on milestone status
    final bool isAllConfirmed = milestones.isNotEmpty &&
        milestones
            .every((ms) => ms.status == MilestoneStatus.confirmedByProvider);

    debugPrint("--- Debug Auto Complete ---");
    debugPrint("Milestones count: ${milestones.length}");
    for (var ms in milestones) {
      debugPrint("Milestone ${ms.id} status: ${ms.status}");
    }
    debugPrint("Contract status before: ${job.status}");

    if (isAllConfirmed && job.status != JobStatus.completed) {
      debugPrint("Contract status after: ${JobStatus.completed}");
      // Auto-complete the job
      context
          .read<JobProvider>()
          .completeJob(jobId: job.id, freelancerId: job.assignedFreelancerId!);
      _sendNotification(
        targetUserId: job.clientId,
        title: 'اكتمل الاتفاق تلقائياً',
        message:
            'تم سداد جميع الدفعات بنجاح واكتمل الاتفاق! يمكنك الآن ترك تقييم.',
        jobId: job.id,
      );
      _sendNotification(
        targetUserId: job.assignedFreelancerId!,
        title: 'اكتمل الاتفاق تلقائياً',
        message:
            'تم استلام جميع الدفعات بنجاح واكتمل الاتفاق! يمكنك الآن ترك تقييم.',
        jobId: job.id,
      );

      // Automatically show review dialog if current user is the client
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.user;
      if (currentUser?.id == job.clientId && job.assignedFreelancerId != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (_) => AddReviewDialog(
              freelancerId: job.assignedFreelancerId!,
              targetName: job.assignedFreelancerName ?? 'الحرفي',
              jobId: job.id,
              jobTitle: job.title,
              onSubmit: (rating, comment, isNegative, isJobCompleted,
                  wouldWorkAgain) async {
                final review = ReviewModel(
                  id: '',
                  freelancerId: job.assignedFreelancerId!,
                  reviewerId: currentUser!.id,
                  reviewerName: currentUser.name,
                  reviewerImageUrl: currentUser.profileImageUrl,
                  rating: rating,
                  comment: comment,
                  isNegative: isNegative,
                  wouldWorkAgain: wouldWorkAgain,
                  jobId: job.id,
                  jobTitle: job.title,
                  createdAt: DateTime.now(),
                );
                try {
                  await FirestoreService()
                      .createReview(review, isJobCompleted: isJobCompleted);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت إضافة التقييم بنجاح')));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('حدث خطأ أثناء إضافة التقييم')));
                }
              },
            ),
          );
        });
      }
    }
  }

  void _showCompleteDialog(BuildContext context, JobModel job) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('إكمال الاتفاق'),
          ],
        ),
        content: const Text(
            'هل أنت متأكد أنك تريد تمييز هذا الاتفاق كمكتمل؟ سيؤدي ذلك إلى إنهاء العمل والسماح لكلا الطرفين بإضافة التقييمات.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              context.read<JobProvider>().completeJob(
                  jobId: job.id, freelancerId: job.assignedFreelancerId!);

              if (job.assignedFreelancerId != null) {
                _sendNotification(
                  targetUserId: job.assignedFreelancerId!,
                  title: 'اكتمل الاتفاق',
                  message: 'تم إنهاء الاتفاق بنجاح! يمكنك الآن ترك تقييم.',
                  jobId: job.id,
                );
              }

              Navigator.pop(ctx);

              final authProvider = context.read<AuthProvider>();
              final currentUser = authProvider.user;
              if (currentUser?.id == job.clientId &&
                  job.assignedFreelancerId != null) {
                showDialog(
                  context: context,
                  builder: (_) => AddReviewDialog(
                    freelancerId: job.assignedFreelancerId!,
                    targetName: job.assignedFreelancerName ?? 'الحرفي',
                    jobId: job.id,
                    jobTitle: job.title,
                    onSubmit: (rating, comment, isNegative, isJobCompleted,
                        wouldWorkAgain) async {
                      final review = ReviewModel(
                        id: '',
                        freelancerId: job.assignedFreelancerId!,
                        reviewerId: currentUser!.id,
                        reviewerName: currentUser.name,
                        reviewerImageUrl: currentUser.profileImageUrl,
                        rating: rating,
                        comment: comment,
                        isNegative: isNegative,
                        wouldWorkAgain: wouldWorkAgain,
                        jobId: job.id,
                        jobTitle: job.title,
                        createdAt: DateTime.now(),
                      );

                      try {
                        await FirestoreService().createReview(review,
                            isJobCompleted: isJobCompleted);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('تمت إضافة التقييم بنجاح')));
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('حدث خطأ أثناء إضافة التقييم')));
                      }
                    },
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('تأكيد الإكمال'),
          ),
        ],
      ),
    );
  }

  void _sendNotification(
      {required String targetUserId,
      required String title,
      required String message,
      required String jobId}) {
    FirebaseFirestore.instance.collection('notifications').add({
      'userId': targetUserId,
      'type': NotificationType.system.name,
      'title': title,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'relatedId': jobId,
    });
  }
}
