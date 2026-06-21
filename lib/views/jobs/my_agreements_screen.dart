import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_provider.dart';
import '../../models/job_model.dart';
import '../../core/constants/app_colors.dart';
import 'active_job_tracking_screen.dart';
import '../../services/smart_guide_service.dart';
import 'package:shimmer/shimmer.dart';
import '../../widgets/common/glass_card.dart';

class MyAgreementsScreen extends StatefulWidget {
  const MyAgreementsScreen({super.key});

  @override
  State<MyAgreementsScreen> createState() => _MyAgreementsScreenState();
}

class _MyAgreementsScreenState extends State<MyAgreementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final jobProvider = context.read<JobProvider>();
        jobProvider.fetchClientJobs(user.id);
        if (user.role.name.toLowerCase().contains('freelancer') ||
            user.role.name.toLowerCase().contains('shop') ||
            user.role.name.toLowerCase().contains('service')) {
          jobProvider.fetchFreelancerJobs(user.id);
        }
      }

      SmartGuideService.showMicroTip(
        context,
        messageAr: 'هنا يمكنك متابعة وإدارة جميع عقودك واتفاقياتك 📝',
        messageEn: 'Here you can track and manage all your agreements 📝',
        tipId: 'agreements_list_tip',
        icon: Icons.assignment_rounded,
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.localeName == 'ar' ? 'اتفاقاتي' : 'My Agreements',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.9),
                AppColors.primary.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
          tabs: [
            Tab(text: l10n.localeName == 'ar' ? 'قيد التنفيذ' : 'In Progress'),
            Tab(text: l10n.localeName == 'ar' ? 'مكتملة' : 'Completed'),
            Tab(text: l10n.localeName == 'ar' ? 'أخرى' : 'Other'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    AppColors.primary.withValues(alpha: 0.15)
                  ]
                : [
                    const Color(0xFFF8FAFC),
                    const Color(0xFFE2E8F0),
                    AppColors.primary.withValues(alpha: 0.1)
                  ],
          ),
        ),
        child: SafeArea(
          child: Consumer<JobProvider>(
            builder: (context, jobProvider, child) {
          if (jobProvider.isLoading &&
              jobProvider.clientJobs.isEmpty &&
              jobProvider.freelancerJobs.isEmpty) {
            return _buildShimmerList(isDark);
          }
          final allJobs = [
            ...jobProvider.clientJobs,
            ...jobProvider.freelancerJobs
          ];

          // Remove duplicates if user is both client and freelancer on same job (rare)
          final uniqueJobs = <String, JobModel>{};
          for (var job in allJobs) {
            uniqueJobs[job.id] = job;
          }
          final jobs = uniqueJobs.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          final inProgressJobs =
              jobs.where((j) => j.status == JobStatus.inProgress).toList();
          final completedJobs =
              jobs.where((j) => j.status == JobStatus.completed).toList();
          final otherJobs = jobs
              .where((j) =>
                  j.status != JobStatus.inProgress &&
                  j.status != JobStatus.completed)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildJobList(inProgressJobs, l10n, isDark),
              _buildJobList(completedJobs, l10n, isDark),
              _buildJobList(otherJobs, l10n, isDark),
            ],
          );
        },
      ),
     ),
    );
  }

  Widget _buildJobList(
      List<JobModel> jobs, AppLocalizations l10n, bool isDark) {
    if (jobs.isEmpty) {
      return Center(
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                l10n.localeName == 'ar'
                    ? 'لا توجد اتفاقات حالياً'
                    : 'No agreements found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: jobs.length,
      itemBuilder: (context, index) {
        final job = jobs[index];
        final isClient = job.clientId == context.read<AuthProvider>().user?.id;

        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          borderRadius: 16.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ActiveJobTrackingScreen(jobId: job.id)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(job.status, l10n),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(isClient ? Icons.person_outline : Icons.work_outline,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        isClient
                            ? (job.assignedFreelancerName ?? 'متعاقد')
                            : job.clientName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      Text(
                        '${job.budgetMax} SDG',
                        style: const TextStyle(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(JobStatus status, AppLocalizations l10n) {
    Color color;
    String text;

    switch (status) {
      case JobStatus.inProgress:
        color = Colors.blue;
        text = l10n.localeName == 'ar' ? 'قيد التنفيذ' : 'In Progress';
        break;
      case JobStatus.completed:
        color = Colors.green;
        text = l10n.localeName == 'ar' ? 'مكتملة' : 'Completed';
        break;
      case JobStatus.cancelled:
        color = Colors.red;
        text = l10n.localeName == 'ar' ? 'ملغاة' : 'Cancelled';
        break;
      default:
        color = Colors.grey;
        text = status.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          borderRadius: 16.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Shimmer.fromColors(
              baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 150, height: 20, color: Colors.white),
                      Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                      width: double.infinity, height: 14, color: Colors.white),
                  const SizedBox(height: 4),
                  Container(width: 200, height: 14, color: Colors.white),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 100, height: 14, color: Colors.white),
                      Container(width: 80, height: 16, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
