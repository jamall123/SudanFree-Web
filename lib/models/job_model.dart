import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

enum JobStatus { open, inProgress, completed, cancelled }

enum JobCategory {
  // Tech & Digital
  webDevelopment,
  mobileDevelopment,
  design,
  writing,
  translation,
  marketing,
  dataEntry,
  videoEditing,
  photography,
  // Education
  tutoring,
  teaching,
  // Construction & Manual
  construction,
  electrical,
  plumbing,
  painting,
  carpentry,
  // Automotive
  carMaintenance,
  carWash,
  // Home Services
  cleaning,
  movingServices,
  airConditioning,
  applianceRepair,
  // Professional Services
  tourGuide,
  driving,
  delivery,
  cooking,
  tailoring,
  beauty,
  // Private / Specialized Services
  privateTutoring, // مدرس خصوصي
  teachingConsultant, // مستشار تدريس
  eventCatering, // تلبية طلبات مناسبات
  baker, // فران
  pastryChef, // بنكجي
  waiter, // طاولجي
  clinicReception, // استقبال عيادات
  appointmentBooking, // حجز مواعيد
  clinicInquiry, // استفسار عيادات
  lawyer, // محامي
  chef, // طباخ
  translator, // مترجم
  // Transport & Logistics
  furnitureMoving, // نقل أثاث
  goodsTransport, // نقل بضائع
  privateRides, // مشاوير خاصة / ترحيل
  vacuumTruck, // شفط بالهواء
  buildingMaterialsTransport, // نقل مواد بناء
  dumpTruckDirt, // قلابات تراب
  dumpTruckSand, // قلابات رملة
  dumpTruckConcrete, // قلابات خرسانة
  // Bartering
  bartering, // مقايضة
  // Other
  other,
}

enum MilestoneStatus {
  pending,
  paidByClient,
  confirmedByProvider,
}

class MilestoneModel {
  final String id;
  final String title;
  final double amount;
  final bool isPaid;
  final bool isCompleted;
  final bool isConfirmed; // Freelancer confirms receiving payment
  final DateTime? completedAt;

  MilestoneModel({
    required this.id,
    required this.title,
    required this.amount,
    this.isPaid = false,
    this.isCompleted = false,
    this.isConfirmed = false,
    this.completedAt,
  });

  MilestoneStatus get status {
    if (isPaid && isConfirmed) return MilestoneStatus.confirmedByProvider;
    if (isPaid && !isConfirmed) return MilestoneStatus.paidByClient;
    return MilestoneStatus.pending;
  }

  factory MilestoneModel.fromMap(Map<String, dynamic> map) {
    return MilestoneModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      isPaid: map['isPaid'] ?? false,
      isCompleted: map['isCompleted'] ?? false,
      isConfirmed: map['isConfirmed'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isPaid': isPaid,
      'isCompleted': isCompleted,
      'isConfirmed': isConfirmed,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }
}

class JobModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientImageUrl;
  final String title;
  final String description;
  final JobCategory category;
  final double budgetMin;
  final double budgetMax;
  final String currency;
  final DateTime deadline;
  final bool isUrgent; // SOS / Urgent Services Layer
  final JobStatus status;
  final String? assignedFreelancerId;
  final String? assignedFreelancerName;
  final String? supervisorId;
  final String? supervisorName;
  final int proposalsCount;
  final List<String> requiredSkills;
  final List<String> attachments;
  final List<MilestoneModel> milestones;
  final String? contractUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientImageUrl,
    required this.title,
    required this.description,
    required this.category,
    required this.budgetMin,
    required this.budgetMax,
    this.currency = 'SDG',
    required this.deadline,
    this.isUrgent = false,
    this.status = JobStatus.open,
    this.assignedFreelancerId,
    this.assignedFreelancerName,
    this.supervisorId,
    this.supervisorName,
    this.proposalsCount = 0,
    this.requiredSkills = const [],
    this.attachments = const [],
    this.milestones = const [],
    this.contractUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JobModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobModel(
      id: doc.id,
      clientId: SafeParse.string(data['clientId']),
      clientName: SafeParse.string(data['clientName']),
      clientImageUrl: SafeParse.nullableString(data['clientImageUrl']),
      title: SafeParse.string(data['title']),
      description: SafeParse.string(data['description']),
      category: SafeParse.enumValue(
          JobCategory.values, data['category'], JobCategory.other),
      budgetMin: SafeParse.decimal(data['budgetMin']),
      budgetMax: SafeParse.decimal(data['budgetMax']),
      currency: SafeParse.string(data['currency'], 'SDG'),
      deadline: SafeParse.dateTime(data['deadline']),
      isUrgent: SafeParse.boolean(data['isUrgent']),
      status:
          SafeParse.enumValue(JobStatus.values, data['status'], JobStatus.open),
      assignedFreelancerId:
          SafeParse.nullableString(data['assignedFreelancerId']),
      assignedFreelancerName:
          SafeParse.nullableString(data['assignedFreelancerName']),
      supervisorId: SafeParse.nullableString(data['supervisorId']),
      supervisorName: SafeParse.nullableString(data['supervisorName']),
      proposalsCount: SafeParse.integer(data['proposalsCount']),
      requiredSkills: SafeParse.stringList(data['requiredSkills']),
      attachments: SafeParse.stringList(data['attachments']),
      milestones: (() {
        try {
          final raw = data['milestones'];
          if (raw is! List) return <MilestoneModel>[];
          return raw
              .map((m) {
                try {
                  return MilestoneModel.fromMap(
                      Map<String, dynamic>.from(m as Map));
                } catch (_) {
                  return null;
                }
              })
              .whereType<MilestoneModel>()
              .toList();
        } catch (_) {
          return <MilestoneModel>[];
        }
      })(),
      contractUrl: SafeParse.nullableString(data['contractUrl']),
      createdAt: SafeParse.dateTime(data['createdAt']),
      updatedAt: SafeParse.dateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientId': clientId,
      'clientName': clientName,
      'clientImageUrl': clientImageUrl,
      'title': title,
      'description': description,
      'category': category.name,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'currency': currency,
      'deadline': Timestamp.fromDate(deadline),
      'isUrgent': isUrgent,
      'status': status.name,
      'assignedFreelancerId': assignedFreelancerId,
      'assignedFreelancerName': assignedFreelancerName,
      'supervisorId': supervisorId,
      'supervisorName': supervisorName,
      'proposalsCount': proposalsCount,
      'requiredSkills': requiredSkills,
      'attachments': attachments,
      'milestones': milestones.map((m) => m.toMap()).toList(),
      'contractUrl': contractUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  JobModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientImageUrl,
    String? title,
    String? description,
    JobCategory? category,
    double? budgetMin,
    double? budgetMax,
    String? currency,
    DateTime? deadline,
    bool? isUrgent,
    JobStatus? status,
    String? assignedFreelancerId,
    String? assignedFreelancerName,
    String? supervisorId,
    String? supervisorName,
    int? proposalsCount,
    List<String>? requiredSkills,
    List<String>? attachments,
    List<MilestoneModel>? milestones,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientImageUrl: clientImageUrl ?? this.clientImageUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      currency: currency ?? this.currency,
      deadline: deadline ?? this.deadline,
      isUrgent: isUrgent ?? this.isUrgent,
      status: status ?? this.status,
      assignedFreelancerId: assignedFreelancerId ?? this.assignedFreelancerId,
      assignedFreelancerName:
          assignedFreelancerName ?? this.assignedFreelancerName,
      supervisorId: supervisorId ?? this.supervisorId,
      supervisorName: supervisorName ?? this.supervisorName,
      proposalsCount: proposalsCount ?? this.proposalsCount,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      attachments: attachments ?? this.attachments,
      milestones: milestones ?? this.milestones,
      contractUrl: contractUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get budgetRange => '$budgetMin - $budgetMax $currency';

  bool get isOpen => status == JobStatus.open;
  bool get isInProgress => status == JobStatus.inProgress;
  bool get isCompleted => status == JobStatus.completed;

  String getCategoryDisplayName(String locale) {
    if (locale == 'en') {
      const namesEn = {
        JobCategory.webDevelopment: 'Web Development',
        JobCategory.mobileDevelopment: 'Mobile Development',
        JobCategory.design: 'Design',
        JobCategory.writing: 'Writing',
        JobCategory.translation: 'Translation',
        JobCategory.marketing: 'Marketing',
        JobCategory.dataEntry: 'Data Entry',
        JobCategory.videoEditing: 'Video Editing',
        JobCategory.photography: 'Photography',
        JobCategory.tutoring: 'Tutoring',
        JobCategory.teaching: 'Teaching',
        JobCategory.construction: 'Construction',
        JobCategory.electrical: 'Electrical',
        JobCategory.plumbing: 'Plumbing',
        JobCategory.painting: 'Painting',
        JobCategory.carpentry: 'Carpentry',
        JobCategory.carMaintenance: 'Car Maintenance',
        JobCategory.carWash: 'Car Wash',
        JobCategory.cleaning: 'Cleaning',
        JobCategory.movingServices: 'Moving Services',
        JobCategory.airConditioning: 'Air Conditioning',
        JobCategory.applianceRepair: 'Appliance Repair',
        JobCategory.tourGuide: 'Tour Guide',
        JobCategory.driving: 'Driving',
        JobCategory.delivery: 'Delivery',
        JobCategory.cooking: 'Cooking',
        JobCategory.tailoring: 'Tailoring',
        JobCategory.beauty: 'Beauty',
        JobCategory.privateTutoring: 'Private Tutor',
        JobCategory.teachingConsultant: 'Teaching Consultant',
        JobCategory.eventCatering: 'Event Catering',
        JobCategory.baker: 'Baker',
        JobCategory.pastryChef: 'Pastry Chef',
        JobCategory.waiter: 'Waiter',
        JobCategory.clinicReception: 'Clinic Reception',
        JobCategory.appointmentBooking: 'Appointment Booking',
        JobCategory.clinicInquiry: 'Clinic Inquiry',
        JobCategory.lawyer: 'Lawyer',
        JobCategory.chef: 'Chef',
        JobCategory.translator: 'Translator',
        JobCategory.furnitureMoving: 'Furniture Moving',
        JobCategory.goodsTransport: 'Goods Transport',
        JobCategory.privateRides: 'Private Rides',
        JobCategory.vacuumTruck: 'Vacuum Truck',
        JobCategory.buildingMaterialsTransport: 'Building Materials Transport',
        JobCategory.dumpTruckDirt: 'Dump Truck (Dirt)',
        JobCategory.dumpTruckSand: 'Dump Truck (Sand)',
        JobCategory.dumpTruckConcrete: 'Dump Truck (Concrete)',
        JobCategory.bartering: 'Bartering',
        JobCategory.other: 'Other',
      };
      return namesEn[category] ?? 'Other';
    }

    const namesAr = {
      JobCategory.webDevelopment: 'تطوير الويب',
      JobCategory.mobileDevelopment: 'تطوير التطبيقات',
      JobCategory.design: 'التصميم',
      JobCategory.writing: 'الكتابة',
      JobCategory.translation: 'الترجمة',
      JobCategory.marketing: 'التسويق',
      JobCategory.dataEntry: 'إدخال البيانات',
      JobCategory.videoEditing: 'مونتاج الفيديو',
      JobCategory.photography: 'التصوير',
      JobCategory.tutoring: 'دروس خصوصية',
      JobCategory.teaching: 'التدريس',
      JobCategory.construction: 'البناء',
      JobCategory.electrical: 'الكهرباء',
      JobCategory.plumbing: 'السباكة',
      JobCategory.painting: 'الدهان',
      JobCategory.carpentry: 'النجارة',
      JobCategory.carMaintenance: 'صيانة السيارات',
      JobCategory.carWash: 'غسيل السيارات',
      JobCategory.cleaning: 'التنظيف',
      JobCategory.movingServices: 'نقل الأثاث',
      JobCategory.airConditioning: 'التكييف',
      JobCategory.applianceRepair: 'صيانة الأجهزة',
      JobCategory.tourGuide: 'مرشد سياحي',
      JobCategory.driving: 'السياقة',
      JobCategory.delivery: 'التوصيل',
      JobCategory.cooking: 'الطبخ',
      JobCategory.tailoring: 'الخياطة',
      JobCategory.beauty: 'التجميل',
      JobCategory.privateTutoring: 'مدرس خصوصي',
      JobCategory.teachingConsultant: 'مستشار تدريس',
      JobCategory.eventCatering: 'تلبية طلبات مناسبات',
      JobCategory.baker: 'فران',
      JobCategory.pastryChef: 'بنكجي',
      JobCategory.waiter: 'طاولجي',
      JobCategory.clinicReception: 'استقبال عيادات',
      JobCategory.appointmentBooking: 'حجز مواعيد',
      JobCategory.clinicInquiry: 'استفسار عيادات',
      JobCategory.lawyer: 'محامي',
      JobCategory.chef: 'طباخ',
      JobCategory.translator: 'مترجم',
      JobCategory.furnitureMoving: 'نقل أثاث',
      JobCategory.goodsTransport: 'نقل بضائع',
      JobCategory.privateRides: 'مشاوير خاصة / ترحيل',
      JobCategory.vacuumTruck: 'شفط بالهواء',
      JobCategory.buildingMaterialsTransport: 'نقل مواد بناء',
      JobCategory.dumpTruckDirt: 'قلابات تراب',
      JobCategory.dumpTruckSand: 'قلابات رملة',
      JobCategory.dumpTruckConcrete: 'قلابات خرسانة',
      JobCategory.bartering: 'سوق المقايضة (بدون أموال)',
      JobCategory.other: 'أخرى',
    };
    return namesAr[category] ?? 'أخرى';
  }
}
