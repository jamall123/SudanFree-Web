import 'package:cloud_firestore/cloud_firestore.dart';

enum ProposalStatus { pending, accepted, rejected, withdrawn }

class ProposalModel {
  final String id;
  final String jobId;
  final String jobTitle;
  final String freelancerId;
  final String freelancerName;
  final String? freelancerImageUrl;
  final String? squadId; // Squad submitting the proposal (if applicable)
  final String? squadName;
  final String clientId;
  final double proposedPrice;
  final String currency;
  final String coverLetter;
  final String? voiceUrl; // Voice-First Interactions
  final ProposalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int deliveryDays;

  ProposalModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.freelancerId,
    required this.freelancerName,
    this.freelancerImageUrl,
    this.squadId,
    this.squadName,
    required this.clientId,
    required this.proposedPrice,
    this.currency = 'SDG',
    required this.deliveryDays,
    required this.coverLetter,
    this.voiceUrl,
    this.status = ProposalStatus.pending,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProposalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProposalModel(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      freelancerId: data['freelancerId'] ?? '',
      freelancerName: data['freelancerName'] ?? '',
      freelancerImageUrl: data['freelancerImageUrl'],
      squadId: data['squadId'],
      squadName: data['squadName'],
      clientId: data['clientId'] ?? '',
      proposedPrice: (data['proposedPrice'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] ?? 'SDG',
      deliveryDays: data['deliveryDays'] ?? 0,
      coverLetter: data['coverLetter'] ?? '',
      voiceUrl: data['voiceUrl'],
      status: ProposalStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ProposalStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'jobTitle': jobTitle,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'freelancerImageUrl': freelancerImageUrl,
      if (squadId != null) 'squadId': squadId,
      if (squadName != null) 'squadName': squadName,
      'clientId': clientId,
      'proposedPrice': proposedPrice,
      'currency': currency,
      'deliveryDays': deliveryDays,
      'coverLetter': coverLetter,
      if (voiceUrl != null) 'voiceUrl': voiceUrl,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ProposalModel copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? freelancerId,
    String? freelancerName,
    String? freelancerImageUrl,
    String? squadId,
    String? squadName,
    String? clientId,
    double? proposedPrice,
    String? currency,
    int? deliveryDays,
    String? coverLetter,
    String? voiceUrl,
    ProposalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProposalModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      freelancerImageUrl: freelancerImageUrl ?? this.freelancerImageUrl,
      squadId: squadId ?? this.squadId,
      squadName: squadName ?? this.squadName,
      clientId: clientId ?? this.clientId,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      currency: currency ?? this.currency,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      coverLetter: coverLetter ?? this.coverLetter,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == ProposalStatus.pending;
  bool get isAccepted => status == ProposalStatus.accepted;
  bool get isRejected => status == ProposalStatus.rejected;
}
