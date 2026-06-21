import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

enum SquadCategory {
  construction,
  software,
  events,
  media,
  maintenance,
  education,
  logistics,
  other,
}

extension SquadCategoryExt on SquadCategory {
  String getName(String locale) {
    if (locale == 'ar') {
      switch (this) {
        case SquadCategory.construction:
          return 'مقاولات وبناء';
        case SquadCategory.software:
          return 'تقنية وبرمجيات';
        case SquadCategory.events:
          return 'تنظيم مناسبات';
        case SquadCategory.media:
          return 'تصوير وإعلام';
        case SquadCategory.maintenance:
          return 'صيانة عامة';
        case SquadCategory.education:
          return 'تعليم وتدريب';
        case SquadCategory.logistics:
          return 'نقل ولوجستيات';
        case SquadCategory.other:
          return 'أخرى';
      }
    }
    switch (this) {
      case SquadCategory.construction:
        return 'Construction & Building';
      case SquadCategory.software:
        return 'Tech & Software';
      case SquadCategory.events:
        return 'Events Planning';
      case SquadCategory.media:
        return 'Media & Photography';
      case SquadCategory.maintenance:
        return 'General Maintenance';
      case SquadCategory.education:
        return 'Education & Training';
      case SquadCategory.logistics:
        return 'Logistics & Transport';
      case SquadCategory.other:
        return 'Other';
    }
  }
}

class SquadModel {
  final String id;
  final String name;
  final String description;
  final String leaderId;
  final List<String> memberIds;
  final String? squadImageUrl;
  final List<String> combinedSkills;
  final int completedJobs;
  final double rating;
  final DateTime createdAt;
  final SquadCategory category;
  final String? state;
  final String? locality;
  final bool isAvailable;
  final List<String> portfolioUrls;

  SquadModel({
    required this.id,
    required this.name,
    required this.description,
    required this.leaderId,
    this.memberIds = const [],
    this.squadImageUrl,
    this.combinedSkills = const [],
    this.completedJobs = 0,
    this.rating = 0.0,
    required this.createdAt,
    this.category = SquadCategory.other,
    this.state,
    this.locality,
    this.isAvailable = true,
    this.portfolioUrls = const [],
  });

  factory SquadModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SquadModel(
      id: doc.id,
      name: SafeParse.string(data['name']),
      description: SafeParse.string(data['description']),
      leaderId: SafeParse.string(data['leaderId']),
      memberIds: SafeParse.stringList(data['memberIds']),
      squadImageUrl: SafeParse.nullableString(data['squadImageUrl']),
      combinedSkills: SafeParse.stringList(data['combinedSkills']),
      completedJobs: SafeParse.integer(data['completedJobs']),
      rating: SafeParse.decimal(data['rating']),
      createdAt: SafeParse.dateTime(data['createdAt']),
      category: SafeParse.enumValue(
          SquadCategory.values, data['category'], SquadCategory.other),
      state: SafeParse.nullableString(data['state']),
      locality: SafeParse.nullableString(data['locality']),
      isAvailable: SafeParse.boolean(data['isAvailable'], true),
      portfolioUrls: SafeParse.stringList(data['portfolioUrls']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'leaderId': leaderId,
      'memberIds': memberIds,
      'squadImageUrl': squadImageUrl,
      'combinedSkills': combinedSkills,
      'completedJobs': completedJobs,
      'rating': rating,
      'createdAt': Timestamp.fromDate(createdAt),
      'category': category.name,
      'state': state,
      'locality': locality,
      'isAvailable': isAvailable,
      'portfolioUrls': portfolioUrls,
    };
  }

  SquadModel copyWith({
    String? id,
    String? name,
    String? description,
    String? leaderId,
    List<String>? memberIds,
    String? squadImageUrl,
    List<String>? combinedSkills,
    int? completedJobs,
    double? rating,
    DateTime? createdAt,
    SquadCategory? category,
    String? state,
    String? locality,
    bool? isAvailable,
    List<String>? portfolioUrls,
  }) {
    return SquadModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      leaderId: leaderId ?? this.leaderId,
      memberIds: memberIds ?? this.memberIds,
      squadImageUrl: squadImageUrl ?? this.squadImageUrl,
      combinedSkills: combinedSkills ?? this.combinedSkills,
      completedJobs: completedJobs ?? this.completedJobs,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
      state: state ?? this.state,
      locality: locality ?? this.locality,
      isAvailable: isAvailable ?? this.isAvailable,
      portfolioUrls: portfolioUrls ?? this.portfolioUrls,
    );
  }
}
