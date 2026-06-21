import 'package:cloud_firestore/cloud_firestore.dart';

class PortfolioProjectModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final String? category;
  final String? status;
  final String? projectType;
  final String? purpose;
  final String? externalLink;
  final List<dynamic>? collaborators;
  final DateTime createdAt;

  PortfolioProjectModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.imageUrls = const [],
    this.videoUrls = const [],
    this.category,
    this.status,
    this.projectType,
    this.purpose,
    this.externalLink,
    this.collaborators,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'imageUrls': imageUrls,
      'videoUrls': videoUrls,
      'category': category,
      'status': status,
      'projectType': projectType,
      'purpose': purpose,
      'externalLink': externalLink,
      'collaborators': collaborators,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PortfolioProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PortfolioProjectModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      videoUrls: List<String>.from(data['videoUrls'] ?? []),
      category: data['category'],
      status: data['status'],
      projectType: data['projectType'],
      purpose: data['purpose'],
      externalLink: data['externalLink'],
      collaborators: data['collaborators'] != null
          ? List<dynamic>.from(data['collaborators'])
          : null,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
