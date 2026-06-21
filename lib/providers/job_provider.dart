import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/proposal_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/cache_service.dart';
import 'package:universal_io/io.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class JobProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final CacheService _cacheService = CacheService();

  List<JobModel> _jobs = [];
  List<JobModel> _clientJobs = [];
  List<JobModel> _freelancerJobs = [];
  List<ProposalModel> _jobProposals = [];
  List<ProposalModel> _myProposals = [];
  JobModel? _selectedJob;

  bool _isLoading = false;
  String? _errorMessage;

  JobCategory? _filterCategory;

  StreamSubscription? _jobsSubscription;
  StreamSubscription? _clientJobsSubscription;
  StreamSubscription? _freelancerJobsSubscription;
  StreamSubscription? _proposalsSubscription;

  List<JobModel> get jobs => _jobs;
  List<JobModel> get clientJobs => _clientJobs;
  List<JobModel> get freelancerJobs => _freelancerJobs;
  List<ProposalModel> get jobProposals => _jobProposals;
  List<ProposalModel> get myProposals => _myProposals;
  JobModel? get selectedJob => _selectedJob;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  JobCategory? get filterCategory => _filterCategory;

  // Fetch all open jobs (for freelancers)
  void fetchJobs() {
    _isLoading = true;
    notifyListeners();

    _jobsSubscription?.cancel();
    _jobsSubscription = _firestoreService
        .getJobs(
      category: _filterCategory?.name,
    )
        .listen((jobs) {
      _jobs = jobs;
      _isLoading = false;
      notifyListeners();

      // Cache jobs for offline access
      _cacheJobs(jobs);
    }, onError: (e) {
      _isLoading = false;
      _errorMessage = e.toString();

      // Try to load from cache
      _loadCachedJobs();
      notifyListeners();
    });
  }

  // Fetch client's jobs
  void fetchClientJobs(String clientId) {
    _clientJobsSubscription?.cancel();
    _clientJobsSubscription =
        _firestoreService.getClientJobs(clientId).listen((jobs) {
      _clientJobs = jobs;
      notifyListeners();
    }, onError: (error) {
      debugPrint('JobProvider clientJobs error: $error');
    });
  }

  // Fetch freelancer's assigned jobs
  void fetchFreelancerJobs(String freelancerId) {
    _freelancerJobsSubscription?.cancel();
    _freelancerJobsSubscription =
        _firestoreService.getFreelancerJobs(freelancerId).listen((jobs) {
      _freelancerJobs = jobs;
      notifyListeners();
    }, onError: (error) {
      debugPrint('JobProvider freelancerJobs error: $error');
    });
  }

  StreamSubscription? _selectedJobSubscription;

  // Fetch and listen to job by ID
  void fetchJob(String jobId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _selectedJobSubscription?.cancel();
    _selectedJobSubscription =
        _firestoreService.getJobStream(jobId).listen((job) {
      _selectedJob = job;
      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    });
  }

  // Start project from request/offer
  Future<String?> startProject({
    required String clientId,
    required String clientName,
    String? clientImageUrl,
    required String title,
    required String description,
    required double price,
    required String freelancerId,
    required String freelancerName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final job = JobModel(
        id: '',
        clientId: clientId,
        clientName: clientName,
        clientImageUrl: clientImageUrl,
        title: title,
        description: description,
        category: JobCategory.other,
        budgetMin: price,
        budgetMax: price,
        deadline: now.add(const Duration(days: 7)),
        status: JobStatus.inProgress,
        assignedFreelancerId: freelancerId,
        assignedFreelancerName: freelancerName,
        milestones: [
          MilestoneModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'الدفعة الأولى (مقدم الاتفاق)',
            amount: price,
            isPaid: false,
            isCompleted: false,
            isConfirmed: false,
          )
        ],
        createdAt: now,
        updatedAt: now,
      );

      final jobId = await _firestoreService.createJob(job);
      _isLoading = false;
      notifyListeners();
      return jobId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Create job
  Future<String?> createJob({
    required String clientId,
    required String clientName,
    String? clientImageUrl,
    required String title,
    required String description,
    required JobCategory category,
    required double budgetMin,
    required double budgetMax,
    required DateTime deadline,
    List<String>? requiredSkills,
    List<File>? attachments,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final job = JobModel(
        id: '',
        clientId: clientId,
        clientName: clientName,
        clientImageUrl: clientImageUrl,
        title: title,
        description: description,
        category: category,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        deadline: deadline,
        requiredSkills: requiredSkills ?? [],
        createdAt: now,
        updatedAt: now,
      );

      final jobId = await _firestoreService.createJob(job);

      // Upload attachments if any
      if (attachments != null && attachments.isNotEmpty) {
        final attachmentUrls = <String>[];
        for (final file in attachments) {
          final url = await _storageService.uploadJobAttachment(jobId, file);
          attachmentUrls.add(url);
        }
        await _firestoreService
            .updateJob(jobId, {'attachments': attachmentUrls});
      }

      // Find matching freelancers for this category and notify them with a 5-minute delay
      try {
        final freelancersSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('role',
                whereIn: ['freelancer', 'techService', 'privateService'])
            .where('skills', arrayContains: category.name)
            .get();

        if (freelancersSnap.docs.isNotEmpty) {
          final delayedTime =
              Timestamp.fromDate(now.add(const Duration(minutes: 5)));
          final batch = FirebaseFirestore.instance.batch();

          for (var doc in freelancersSnap.docs) {
            if (doc.id == clientId) continue; // Don't notify the creator

            final notifRef =
                FirebaseFirestore.instance.collection('notifications').doc();
            final notif = NotificationModel(
              id: notifRef.id,
              userId: doc.id,
              type: NotificationType.system,
              title: 'مشروع جديد: $title',
              message: 'تم إضافة مشروع جديد يطابق مهاراتك. قدم عرضك الآن!',
              createdAt: Timestamp.now(),
              sendAfter:
                  delayedTime, // 5 minute delay for professional services
              relatedId: jobId,
            );

            batch.set(notifRef, notif.toFirestore());
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Error sending delayed notifications: $e');
      }

      _isLoading = false;
      notifyListeners();
      return jobId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Update job
  Future<bool> updateJob(String jobId, Map<String, dynamic> data) async {
    try {
      await _firestoreService.updateJob(jobId, data);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Delete job
  Future<bool> deleteJob(String jobId) async {
    try {
      await _firestoreService.deleteJob(jobId);
      await _storageService.deleteFolder('jobs/$jobId');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Apply filter
  void setFilter({
    JobCategory? category,
  }) {
    _filterCategory = category;
    fetchJobs();
  }

  // Clear filter
  void clearFilter() {
    _filterCategory = null;
    fetchJobs();
  }

  // ==================== PROPOSALS ====================

  // Fetch proposals for a job
  void fetchJobProposals(String jobId) {
    _proposalsSubscription?.cancel();
    _proposalsSubscription =
        _firestoreService.getJobProposals(jobId).listen((proposals) {
      _jobProposals = proposals;
      notifyListeners();
    }, onError: (error) {
      debugPrint('JobProvider jobProposals error: $error');
    });
  }

  // Fetch freelancer's proposals
  void fetchMyProposals(String freelancerId) {
    _firestoreService.getFreelancerProposals(freelancerId).listen((proposals) {
      _myProposals = proposals;
      notifyListeners();
    }, onError: (error) {
      debugPrint('JobProvider myProposals error: $error');
    });
  }

  // Complete Job
  Future<void> completeJob(
      {required String jobId, required String freelancerId}) async {
    await _firestoreService.completeJob(jobId, freelancerId);
    // Refresh current job details
    if (_selectedJob != null && _selectedJob!.id == jobId) {
      fetchJob(jobId);
    }
    notifyListeners();
  }

  // Update Milestones
  Future<void> updateMilestones(
      String jobId, List<MilestoneModel> milestones) async {
    await _firestoreService.updateMilestones(jobId, milestones);
    if (_selectedJob != null && _selectedJob!.id == jobId) {
      _selectedJob = _selectedJob!.copyWith(milestones: milestones);
    }
    notifyListeners();
  }

  // Submit proposal
  Future<bool> submitProposal({
    required String jobId,
    required String jobTitle,
    required String freelancerId,
    required String freelancerName,
    String? freelancerImageUrl,
    required String clientId,
    required double proposedPrice,
    required int deliveryDays,
    required String coverLetter,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final proposal = ProposalModel(
        id: '',
        jobId: jobId,
        jobTitle: jobTitle,
        freelancerId: freelancerId,
        freelancerName: freelancerName,
        freelancerImageUrl: freelancerImageUrl,
        clientId: clientId,
        proposedPrice: proposedPrice,
        deliveryDays: deliveryDays,
        coverLetter: coverLetter,
        createdAt: now,
        updatedAt: now,
      );

      await _firestoreService.createProposal(proposal);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Accept proposal
  Future<bool> acceptProposal(ProposalModel proposal) async {
    try {
      await _firestoreService.acceptProposal(proposal);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Assign job to an apprentice
  Future<bool> assignJobToApprentice({
    required String jobId,
    required String apprenticeId,
    required String apprenticeName,
    required String masterId,
    required String masterName,
    required String clientId,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firestoreService.updateJob(jobId, {
        'assignedFreelancerId': apprenticeId,
        'assignedFreelancerName': apprenticeName,
        'supervisorId': masterId,
        'supervisorName': masterName,
      });

      // Update local state if needed
      if (_selectedJob != null && _selectedJob!.id == jobId) {
        _selectedJob = _selectedJob!.copyWith(
          assignedFreelancerId: apprenticeId,
          assignedFreelancerName: apprenticeName,
          supervisorId: masterId,
          supervisorName: masterName,
        );
      }

      // Send Notification to Apprentice
      final apprenticeNotification = NotificationModel(
        id: '',
        userId: apprenticeId,
        type: NotificationType.assignment,
        title: 'مهمة جديدة! 🛠️',
        message: 'لقد كلفك المعلم $masterName بمهمة جديدة، قم بمراجعتها الآن.',
        createdAt: Timestamp.now(),
        relatedId: jobId,
      );
      _firestoreService.sendNotification(apprenticeNotification);

      // Send Notification to Client
      final clientNotification = NotificationModel(
        id: '',
        userId: clientId,
        type: NotificationType.assignment,
        title: 'تحديث في المهمة 🔄',
        message:
            'قام المعلم $masterName بتكليف الفني $apprenticeName لتنفيذ مهمتك تحت إشرافه.',
        createdAt: Timestamp.now(),
        relatedId: jobId,
      );
      _firestoreService.sendNotification(clientNotification);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Reject proposal
  Future<bool> rejectProposal(String proposalId) async {
    try {
      await _firestoreService.updateProposalStatus(
          proposalId, ProposalStatus.rejected.name);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== CACHE ====================

  void _cacheJobs(List<JobModel> jobs) {
    final jobsData = jobs.map((job) => job.toFirestore()).toList();
    _cacheService.cacheJobs(jobsData);
  }

  void _loadCachedJobs() {
    if (_cacheService.isJobsCacheValid()) {
      final cachedData = _cacheService.getCachedJobs();
      if (cachedData != null) {
        // Note: We can't fully reconstruct from cache without document ID
        // This is simplified - in production, store IDs too
      }
    }
  }

  // ==================== CLEANUP ====================

  void clearSelectedJob() {
    _selectedJobSubscription?.cancel();
    _selectedJob = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all data (on logout)
  void clear() {
    _jobs = [];
    _clientJobs = [];
    _freelancerJobs = [];
    _jobProposals = [];
    _myProposals = [];
    _selectedJob = null;
    _isLoading = false;
    _errorMessage = null;
    _filterCategory = null;
    _jobsSubscription?.cancel();
    _clientJobsSubscription?.cancel();
    _freelancerJobsSubscription?.cancel();
    _proposalsSubscription?.cancel();
    _selectedJobSubscription?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    _clientJobsSubscription?.cancel();
    _freelancerJobsSubscription?.cancel();
    _proposalsSubscription?.cancel();
    _selectedJobSubscription?.cancel();
    super.dispose();
  }
}
