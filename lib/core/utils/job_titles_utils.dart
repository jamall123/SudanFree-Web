import '../../models/job_model.dart';

class JobTitlesUtils {
  static String getLocalizedTitle(String title, String locale) {
    final Map<String, String> enToAr = {
      // Traditional
      'Carpenter': 'نجار',
      'Plumber': 'سباك',
      'Electrician': 'كهربائي',
      'Blacksmith': 'حداد',
      'Painter': 'نقاش',
      'Builder': 'بناء',
      'Mechanic': 'ميكانيكي',
      'AC Technician': 'فني تكييف',
      'Satellite Technician': 'فني دش',
      'Tailor': 'خياط',
      'Barber': 'حلاق',
      'Chef': 'طباخ',
      'Driver': 'سائق',
      'Accountant': 'محاسب',
      'Lawyer': 'محامي',
      'Engineer': 'مهندس',
      'Doctor': 'طبيب',
      'Teacher': 'معلم',
      'Developer': 'مبرمج',
      'Graphic Designer': 'مصمم جرافيك',
      'Photographer': 'مصور',
      'Freelancer': 'حرفي',
      'Client': 'عميل',

      // Added Missing Titles
      'airConditioning': 'تكييف وتبريد',
      'carWash': 'غسيل سيارات',
      'carMaintenance': 'صيانة سيارات',
      'movingServices': 'نقل عفش',
      'driving': 'قيادة',
      'tourGuide': 'مرشد سياحي',
      'beauty': 'تجميل',
      'tailoring': 'خياطة وتفصيل',
      'cooking': 'طبخ',

      // Common categories
      'other': 'أخرى',
      'Other': 'أخرى',
      'electrical': 'كهرباء',
      'Electrical': 'كهرباء',
      'plumbing': 'سباكة',
      'Plumbing': 'سباكة',
      'carpentry': 'نجارة',
      'Carpentry': 'نجارة',
      'painting': 'دهان',
      'Painting': 'دهان',
      'mechanical': 'ميكانيكا',
      'Mechanical': 'ميكانيكا',
      'construction': 'بناء',
      'Construction': 'بناء',
      'cleaning': 'تنظيف',
      'Cleaning': 'تنظيف',
      'delivery': 'توصيل',
      'Delivery': 'توصيل',
      'technology': 'تقنية',
      'Technology': 'تقنية',

      // Tech Skills
      'mobileDevelopment': 'تطوير تطبيقات',
      'webDevelopment': 'تطوير مواقع',
      'design': 'تصميم',
      'writing': 'كتابة',
      'photography': 'تصوير',
      'tutoring': 'تدريس خصوصي',
      'teaching': 'تدريس',
      'dataEntry': 'إدخال بيانات',
      'applianceRepair': 'صيانة أجهزة منزلية',
      'graphicDesign': 'تصميم جرافيك',
      'videoEditing': 'مونتاج فيديو',
      'digitalMarketing': 'تسويق رقمي',
      'translation': 'ترجمة',
      'contentWriting': 'كتابة محتوى',
      'virtualAssistant': 'مساعد افتراضي',
      'projectManagement': 'إدارة مشاريع',
      'businessAnalysis': 'تحليل أعمال',
      'marketing': 'تسويق',
      'consulting': 'استشارات',
      'socialMedia': 'إدارة تواصل اجتماعي',
      'uiUxDesign': 'تصميم واجهات',
      'seo': 'تحسين محركات البحث',

      // Private / Specialized Services
      'privateTutoring': 'مدرس خصوصي',
      'teachingConsultant': 'مستشار تدريس',
      'eventCatering': 'تلبية طلبات مناسبات',
      'baker': 'فران',
      'pastryChef': 'بنكجي',
      'waiter': 'طاولجي',
      'clinicReception': 'استقبال عيادات',
      'appointmentBooking': 'حجز مواعيد',
      'clinicInquiry': 'استفسار عيادات',
      'lawyer': 'محامي',
      'chef': 'طباخ',
      'translator': 'مترجم',

      // Transport & Logistics
      'furnitureMoving': 'نقل أثاث',
      'goodsTransport': 'نقل بضائع',
      'privateRides': 'مشاوير خاصة / ترحيل',
      'vacuumTruck': 'شفط بالهواء',
      'buildingMaterialsTransport': 'نقل مواد بناء',
      'dumpTruckDirt': 'قلابات تراب',
      'dumpTruckSand': 'قلابات رملة',
      'dumpTruckConcrete': 'قلابات خرسانة',
    };

    try {
      final category = JobCategory.values.firstWhere((c) {
        if (c.name.toLowerCase() == title.toLowerCase()) return true;
        // Check if the title matches the English display name
        final dummyJob = JobModel(
          id: '',
          clientId: '',
          clientName: '',
          title: '',
          description: '',
          category: c,
          budgetMin: 0,
          budgetMax: 0,
          deadline: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        return dummyJob.getCategoryDisplayName('en').toLowerCase() ==
            title.toLowerCase();
      });
      final dummyJob = JobModel(
        id: '',
        clientId: '',
        clientName: '',
        title: '',
        description: '',
        category: category,
        budgetMin: 0,
        budgetMax: 0,
        deadline: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return dummyJob.getCategoryDisplayName(locale);
    } catch (_) {
      // Fallback to static map
      final searchTitle = title.trim().toLowerCase();
      // Handle camel case keys to match space-separated user input
      final String noSpaceSearch = searchTitle
          .replaceAll(' ', '')
          .replaceAll('-', '')
          .replaceAll('/', '');
      if (locale == 'ar') {
        final Map<String, String> lowerEnToAr = {};
        enToAr.forEach((k, v) {
          lowerEnToAr[k.toLowerCase()] = v;
          lowerEnToAr[k
              .toLowerCase()
              .replaceAll(' ', '')
              .replaceAll('-', '')
              .replaceAll('/', '')] = v;
        });
        return lowerEnToAr[searchTitle] ?? title;
      } else {
        // Reverse mapping: Arabic to English
        final Map<String, String> arToEn = {};
        enToAr.forEach((k, v) {
          arToEn[v.trim().toLowerCase()] = k;
        });
        enToAr.forEach((k, v) => arToEn[v.trim().toLowerCase()] = k);
        return arToEn[searchTitle] ?? title;
      }
    }
  }
}
