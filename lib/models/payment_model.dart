import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, verified, rejected, released, refunded }

enum PaymentMethod { bankak, fawry, bankTransfer, other }

class PaymentModel {
  final String id;
  final String jobId;
  final String jobTitle;
  final String clientId;
  final String clientName;
  final String freelancerId;
  final String freelancerName;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? receiptImageUrl;
  final String? transactionReference;
  final String? adminNote;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentModel({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.clientId,
    required this.clientName,
    required this.freelancerId,
    required this.freelancerName,
    required this.amount,
    this.currency = 'SDG',
    required this.method,
    this.status = PaymentStatus.pending,
    this.receiptImageUrl,
    this.transactionReference,
    this.adminNote,
    this.verifiedBy,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentModel(
      id: doc.id,
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      freelancerId: data['freelancerId'] ?? '',
      freelancerName: data['freelancerName'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] ?? 'SDG',
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == data['method'],
        orElse: () => PaymentMethod.other,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PaymentStatus.pending,
      ),
      receiptImageUrl: data['receiptImageUrl'],
      transactionReference: data['transactionReference'],
      adminNote: data['adminNote'],
      verifiedBy: data['verifiedBy'],
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'jobTitle': jobTitle,
      'clientId': clientId,
      'clientName': clientName,
      'freelancerId': freelancerId,
      'freelancerName': freelancerName,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'status': status.name,
      'receiptImageUrl': receiptImageUrl,
      'transactionReference': transactionReference,
      'adminNote': adminNote,
      'verifiedBy': verifiedBy,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PaymentModel copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? clientId,
    String? clientName,
    String? freelancerId,
    String? freelancerName,
    double? amount,
    String? currency,
    PaymentMethod? method,
    PaymentStatus? status,
    String? receiptImageUrl,
    String? transactionReference,
    String? adminNote,
    String? verifiedBy,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      freelancerId: freelancerId ?? this.freelancerId,
      freelancerName: freelancerName ?? this.freelancerName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      method: method ?? this.method,
      status: status ?? this.status,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      transactionReference: transactionReference ?? this.transactionReference,
      adminNote: adminNote ?? this.adminNote,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == PaymentStatus.pending;
  bool get isVerified => status == PaymentStatus.verified;
  bool get isReleased => status == PaymentStatus.released;
  bool get isRefunded => status == PaymentStatus.refunded;

  String getMethodDisplayName(String locale) {
    final names = {
      'ar': {
        PaymentMethod.bankak: 'بنكك',
        PaymentMethod.fawry: 'فوري',
        PaymentMethod.bankTransfer: 'تحويل بنكي',
        PaymentMethod.other: 'أخرى',
      },
      'en': {
        PaymentMethod.bankak: 'Bankak',
        PaymentMethod.fawry: 'Fawry',
        PaymentMethod.bankTransfer: 'Bank Transfer',
        PaymentMethod.other: 'Other',
      },
    };
    return names[locale]?[method] ?? method.name;
  }

  String getStatusDisplayName(String locale) {
    final names = {
      'ar': {
        PaymentStatus.pending: 'قيد المراجعة',
        PaymentStatus.verified: 'تم التحقق',
        PaymentStatus.rejected: 'مرفوض',
        PaymentStatus.released: 'تم الإفراج',
        PaymentStatus.refunded: 'مسترجع',
      },
      'en': {
        PaymentStatus.pending: 'Pending',
        PaymentStatus.verified: 'Verified',
        PaymentStatus.rejected: 'Rejected',
        PaymentStatus.released: 'Released',
        PaymentStatus.refunded: 'Refunded',
      },
    };
    return names[locale]?[status] ?? status.name;
  }
}
