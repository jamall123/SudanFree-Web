import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/job_model.dart';
import '../../models/proposal_model.dart';
import '../../models/offer_model.dart';

class JobFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create job
  Future<String> createJob(JobModel job) async {
    final docRef = await _firestore.collection('jobs').add(job.toFirestore());
    return docRef.id;
  }

  // Get job by ID
  Future<JobModel?> getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (doc.exists) {
      return JobModel.fromFirestore(doc);
    }
    return null;
  }

  // Get job stream by ID
  Stream<JobModel?> getJobStream(String jobId) {
    return _firestore.collection('jobs').doc(jobId).snapshots().map((doc) {
      if (doc.exists) {
        return JobModel.fromFirestore(doc);
      }
      return null;
    });
  }

  // Check if there is a completed job between client and freelancer
  Future<bool> hasCompletedJob(String clientId, String freelancerId) async {
    final snapshot = await _firestore
        .collection('jobs')
        .where('clientId', isEqualTo: clientId)
        .where('assignedFreelancerId', isEqualTo: freelancerId)
        .where('status', isEqualTo: JobStatus.completed.name)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // Get all jobs - Stream
  Stream<List<JobModel>> getJobs({
    String? category,
    String? state,
    String? locality,
    String? status,
    int limit = 50,
  }) {
    Query query =
        _firestore.collection('jobs').orderBy('createdAt', descending: true);

    if (category != null) query = query.where('category', isEqualTo: category);
    if (state != null) query = query.where('state', isEqualTo: state);
    if (locality != null) query = query.where('locality', isEqualTo: locality);
    if (status != null) query = query.where('status', isEqualTo: status);

    return query.limit(limit).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList());
  }

  // Get jobs with real pagination
  Future<Map<String, dynamic>> getJobsPaginated({
    DocumentSnapshot? startAfterDoc,
    String? category,
    String? state,
    int limit = 15,
  }) async {
    Query query = _firestore
        .collection('jobs')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (category != null) query = query.where('category', isEqualTo: category);
    if (state != null) query = query.where('state', isEqualTo: state);
    if (startAfterDoc != null) query = query.startAfterDocument(startAfterDoc);

    final snapshot = await query.get();
    final jobs =
        snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();

    return {
      'jobs': jobs,
      'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      'hasMore': snapshot.docs.length == limit,
    };
  }

  // Create Offer
  Future<void> createOffer(OfferModel offer) async {
    final docRef = _firestore
        .collection('requests')
        .doc(offer.requestId)
        .collection('offers')
        .doc();
    final data = offer.toMap();
    data['id'] = docRef.id;

    final batch = _firestore.batch();
    batch.set(docRef, data);
    batch.update(_firestore.collection('requests').doc(offer.requestId),
        {'offersCount': FieldValue.increment(1)});
    await batch.commit();
  }

  // Fetch Offers
  Stream<List<OfferModel>> getOffers(String requestId) {
    return _firestore
        .collection('requests')
        .doc(requestId)
        .collection('offers')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OfferModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Get user offer count
  Future<int> getUserOfferCount(String requestId, String userId) async {
    final snapshot = await _firestore
        .collection('requests')
        .doc(requestId)
        .collection('offers')
        .where('providerId', isEqualTo: userId)
        .get();
    return snapshot.docs.length;
  }

  // Update Job
  Future<void> updateJob(String jobId, Map<String, dynamic> data) async {
    await _firestore.collection('jobs').doc(jobId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept Proposal (Start Project)
  Future<void> acceptProposal(ProposalModel proposal) async {
    final batch = _firestore.batch();

    // Update proposal status
    batch.update(_firestore.collection('proposals').doc(proposal.id), {
      'status': 'accepted',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update job status and assign freelancer
    batch.update(_firestore.collection('jobs').doc(proposal.jobId), {
      'status': JobStatus.inProgress.name,
      'assignedFreelancerId': proposal.freelancerId,
      'assignedFreelancerName': proposal.freelancerName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Assign Job to Apprentice
  Future<void> assignJobToApprentice({
    required String jobId,
    required String apprenticeId,
    required String apprenticeName,
    required String masterId,
    required String masterName,
  }) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'assignedFreelancerId': apprenticeId,
      'assignedFreelancerName': apprenticeName,
      'supervisorId': masterId,
      'supervisorName': masterName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Complete Job
  Future<void> completeJob(String jobId, String freelancerId) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'status': JobStatus.completed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update Milestones
  Future<void> updateMilestones(
      String jobId, List<MilestoneModel> milestones) async {
    await _firestore.collection('jobs').doc(jobId).update({
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get Freelancer Jobs (Including supervised jobs)
  Stream<List<JobModel>> getFreelancerJobs(String freelancerId) {
    return _firestore
        .collection('jobs')
        .where(Filter.or(
          Filter('assignedFreelancerId', isEqualTo: freelancerId),
          Filter('supervisorId', isEqualTo: freelancerId),
        ))
        .snapshots()
        .map((snapshot) {
      final jobs =
          snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList();
      jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return jobs;
    });
  }

  // Get Client Jobs
  Stream<List<JobModel>> getClientJobs(String clientId) {
    return _firestore
        .collection('jobs')
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => JobModel.fromFirestore(doc)).toList());
  }

  // Delete Job
  Future<void> deleteJob(String jobId) async {
    await _firestore.collection('jobs').doc(jobId).delete();
  }

  // Get Job Proposals
  Stream<List<ProposalModel>> getJobProposals(String jobId) {
    return _firestore
        .collection('proposals')
        .where('jobId', isEqualTo: jobId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProposalModel.fromFirestore(doc))
            .toList());
  }

  // Get Freelancer Proposals
  Stream<List<ProposalModel>> getFreelancerProposals(String freelancerId) {
    return _firestore
        .collection('proposals')
        .where('freelancerId', isEqualTo: freelancerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProposalModel.fromFirestore(doc))
            .toList());
  }

  // Create Proposal
  Future<String> createProposal(ProposalModel proposal) async {
    final docRef =
        await _firestore.collection('proposals').add(proposal.toFirestore());
    await _firestore
        .collection('jobs')
        .doc(proposal.jobId)
        .update({'proposalsCount': FieldValue.increment(1)});
    return docRef.id;
  }

  // Update Proposal Status
  Future<void> updateProposalStatus(String proposalId, String status) async {
    await _firestore.collection('proposals').doc(proposalId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== AI Fair-Pricing Broker (السمسار الذكي للتسعير العادل) ====================

  /// يحسب السعر العادل (Fair Market Value) بناءً على متوسط الوظائف السابقة المكتملة
  Future<double?> calculateFairPrice(JobCategory category) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('category', isEqualTo: category.name)
          .where('status', isEqualTo: JobStatus.completed.name)
          .orderBy('createdAt', descending: true)
          .limit(20) // نأخذ آخر 20 وظيفة مكتملة كعينة لمتوسط السوق
          .get();

      if (snapshot.docs.isEmpty) return null;

      List<double> prices = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final budgetMin = (data['budgetMin'] as num?)?.toDouble() ?? 0.0;
        final budgetMax = (data['budgetMax'] as num?)?.toDouble() ?? 0.0;
        if (budgetMax > 0) {
          prices.add((budgetMin + budgetMax) / 2);
        }
      }

      if (prices.isEmpty) return null;

      // حساب الوسيط (Median) لتجنب الأسعار الشاذة (Outliers)
      prices.sort();
      double median;
      int middle = prices.length ~/ 2;
      if (prices.length % 2 == 1) {
        median = prices[middle];
      } else {
        median = (prices[middle - 1] + prices[middle]) / 2.0;
      }

      return median;
    } catch (e) {
      return null;
    }
  }

  /// حساب تكلفة المواصلات العادلة بناءً على المسافة بالكيلومتر
  double calculateDistancePremium(double distanceKm) {
    const double baseFare = 1000.0; // تسعيرة فتح العداد الأساسية (جنيه)
    const double perKmRate = 500.0; // تسعيرة الكيلومتر (جنيه)

    if (distanceKm <= 2.0) {
      return baseFare; // مسافة قريبة جداً
    }

    return baseFare + ((distanceKm - 2.0) * perKmRate);
  }
}
