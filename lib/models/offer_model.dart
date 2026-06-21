import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String requestId;
  final String providerId;
  final String providerName;
  final String? providerRole;
  final String? providerImageUrl;
  final String? providerJobTitle;
  final String title;
  final String text;
  final double? price; // Optional price input
  final String? estimatedTime; // e.g. "3 days", "1 week"
  final DateTime createdAt;

  OfferModel({
    required this.id,
    required this.requestId,
    required this.providerId,
    required this.providerName,
    this.providerRole,
    this.providerImageUrl,
    this.providerJobTitle,
    required this.title,
    required this.text,
    this.price,
    this.estimatedTime,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requestId': requestId,
      'providerId': providerId,
      'providerName': providerName,
      'providerRole': providerRole,
      'providerImageUrl': providerImageUrl,
      'providerJobTitle': providerJobTitle,
      'title': title,
      'text': text,
      'price': price,
      'estimatedTime': estimatedTime,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory OfferModel.fromMap(Map<String, dynamic> map, String id) {
    return OfferModel(
      id: id,
      requestId: map['requestId'] ?? '',
      providerId: map['providerId'] ?? '',
      providerName: map['providerName'] ?? '',
      providerRole: map['providerRole'],
      providerImageUrl: map['providerImageUrl'],
      providerJobTitle: map['providerJobTitle'],
      title: map['title'] ?? '',
      text: map['text'] ?? '',
      price: map['price']?.toDouble(),
      estimatedTime: map['estimatedTime'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
