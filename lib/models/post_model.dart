import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/safe_parse.dart';

class PostReaction {
  static const String like = 'like';
  static const String love = 'love';
  static const String haha = 'haha';
  static const String wow = 'wow';
  static const String sad = 'sad';
  static const String angry = 'angry';

  static const List<String> values = [like, love, haha, wow, sad, angry];
}

/// Main category groups for display in UI
enum PostCategoryGroup {
  general, // عام
  clothing, // ملبوسات وأزياء
  beauty, // صحة وجمال
  electronics, // إلكترونيات وموبايلات
  building, // مواد بناء
  grocery, // مأكولات وبقالة
  homeFurniture, // أثاث ومنزليات
  automotive, // سوق العربات
  realEstate, // عقارات وسمسرة
  craftsmen, // صنايعية وحرفيين
  specialServices, // خدمات خاصة
  techCommunity, // مبرمجين ومصممين
  education, // تعليم وتدريب
  entertainment, // ترفيه وألعاب
  jobs; // وظائف وفرص عمل

  String getName(String locale) {
    if (locale == 'ar') {
      switch (this) {
        case PostCategoryGroup.general:
          return 'عام';
        case PostCategoryGroup.clothing:
          return 'ملبوسات وأزياء';
        case PostCategoryGroup.beauty:
          return 'صحة وجمال';
        case PostCategoryGroup.electronics:
          return 'إلكترونيات';
        case PostCategoryGroup.building:
          return 'مواد بناء';
        case PostCategoryGroup.grocery:
          return 'مأكولات وبقالة';
        case PostCategoryGroup.homeFurniture:
          return 'أثاث ومنزليات';
        case PostCategoryGroup.automotive:
          return 'سوق العربات';
        case PostCategoryGroup.realEstate:
          return 'عقارات وسمسرة';
        case PostCategoryGroup.craftsmen:
          return 'صنايعية وحرفيين';
        case PostCategoryGroup.specialServices:
          return 'خدمات خاصة';
        case PostCategoryGroup.techCommunity:
          return 'مبرمجين ومصممين';
        case PostCategoryGroup.education:
          return 'تعليم وتدريب';
        case PostCategoryGroup.entertainment:
          return 'ترفيه وألعاب';
        case PostCategoryGroup.jobs:
          return 'وظائف وفرص';
      }
    } else {
      switch (this) {
        case PostCategoryGroup.general:
          return 'General';
        case PostCategoryGroup.clothing:
          return 'Fashion & Clothing';
        case PostCategoryGroup.beauty:
          return 'Health & Beauty';
        case PostCategoryGroup.electronics:
          return 'Electronics';
        case PostCategoryGroup.building:
          return 'Building Materials';
        case PostCategoryGroup.grocery:
          return 'Food & Grocery';
        case PostCategoryGroup.homeFurniture:
          return 'Home & Furniture';
        case PostCategoryGroup.automotive:
          return 'Car Market';
        case PostCategoryGroup.realEstate:
          return 'Real Estate';
        case PostCategoryGroup.craftsmen:
          return 'Craftsmen';
        case PostCategoryGroup.specialServices:
          return 'Special Services';
        case PostCategoryGroup.techCommunity:
          return 'Tech Community';
        case PostCategoryGroup.education:
          return 'Education';
        case PostCategoryGroup.entertainment:
          return 'Entertainment & Games';
        case PostCategoryGroup.jobs:
          return 'Jobs & Opportunities';
      }
    }
  }

  IconData get icon {
    switch (this) {
      case PostCategoryGroup.general:
        return Icons.public;
      case PostCategoryGroup.clothing:
        return Icons.checkroom;
      case PostCategoryGroup.beauty:
        return Icons.spa;
      case PostCategoryGroup.electronics:
        return Icons.devices;
      case PostCategoryGroup.building:
        return Icons.construction;
      case PostCategoryGroup.grocery:
        return Icons.restaurant;
      case PostCategoryGroup.homeFurniture:
        return Icons.chair;
      case PostCategoryGroup.automotive:
        return Icons.directions_car;
      case PostCategoryGroup.realEstate:
        return Icons.apartment;
      case PostCategoryGroup.craftsmen:
        return Icons.build;
      case PostCategoryGroup.specialServices:
        return Icons.miscellaneous_services;
      case PostCategoryGroup.techCommunity:
        return Icons.code;
      case PostCategoryGroup.education:
        return Icons.school;
      case PostCategoryGroup.entertainment:
        return Icons.sports_esports;
      case PostCategoryGroup.jobs:
        return Icons.work;
    }
  }

  Color get color {
    switch (this) {
      case PostCategoryGroup.general:
        return const Color(0xFF6c5ce7);
      case PostCategoryGroup.clothing:
        return const Color(0xFFe84393);
      case PostCategoryGroup.beauty:
        return const Color(0xFFfd79a8);
      case PostCategoryGroup.electronics:
        return const Color(0xFF0984e3);
      case PostCategoryGroup.building:
        return const Color(0xFFe17055);
      case PostCategoryGroup.grocery:
        return const Color(0xFF00b894);
      case PostCategoryGroup.homeFurniture:
        return const Color(0xFF6c5ce7);
      case PostCategoryGroup.automotive:
        return const Color(0xFF636e72);
      case PostCategoryGroup.realEstate:
        return const Color(0xFFfdcb6e);
      case PostCategoryGroup.craftsmen:
        return const Color(0xFF00cec9);
      case PostCategoryGroup.specialServices:
        return const Color(0xFF74b9ff);
      case PostCategoryGroup.techCommunity:
        return const Color(0xFF0984e3);
      case PostCategoryGroup.education:
        return const Color(0xFF6c5ce7);
      case PostCategoryGroup.entertainment:
        return const Color(0xFFa29bfe);
      case PostCategoryGroup.jobs:
        return const Color(0xFF00b894);
    }
  }
}

enum PostCategory {
  // ── عام ──
  general,
  question,
  help,
  announcement,
  discussion,
  barter,

  // ── ملبوسات وأزياء ──
  clothingMen,
  clothingWomen,
  clothingKids,
  clothingShoes,
  clothingAccessories,
  clothingTraditional,
  clothingOther,

  // ── صحة وجمال ──
  beautyMakeup,
  beautySkinCare,
  beautyHair,
  beautyPerfume,
  beautyClinic,
  beautyOther,

  // ── إلكترونيات وموبايلات ──
  elecMobiles,
  elecLaptops,
  elecTV,
  elecAccessories,
  elecRepair,
  elecOther,

  // ── مواد بناء ──
  buildCement,
  buildIron,
  buildPlumbing,
  buildElectrical,
  buildPaint,
  buildTiles,
  buildOther,

  // ── مأكولات وبقالة ──
  foodRestaurant,
  foodCatering,
  foodHomemade,
  foodBakery,
  foodGrocery,
  foodOther,

  // ── أثاث ومنزليات ──
  homeFurniture,
  homeAppliances,
  homeDecor,
  homeKitchen,
  homeOther,

  // ── سوق العربات ──
  autoBuySell,
  autoParts,
  autoRepair,
  autoRental,
  autoAccessories,
  autoOther,

  // ── عقارات وسمسرة ──
  realEstateSale,
  realEstateRent,
  realEstateLand,
  realEstateOffice,
  realEstateOther,

  // ── صنايعية وحرفيين ──
  craftPlumbing,
  craftElectricity,
  craftCarpentry,
  craftPainting,
  craftWelding,
  craftAC,
  craftCleaning,
  craftTransport,
  craftOther,

  // ── خدمات خاصة ──
  svcLegal,
  svcAccounting,
  svcPhotography,
  svcEvents,
  svcTranslation,
  svcDelivery,
  svcOther,

  // ── مبرمجين ومصممين ──
  techWebDev,
  techMobileDev,
  techDesign,
  techUIUX,
  techMarketing,
  techVideoEditing,
  techNetworking,
  techOther,

  // ── تعليم وتدريب ──
  eduTutoring,
  eduLanguages,
  eduTraining,
  eduOnlineCourses,
  eduOther,

  // ── ترفيه وألعاب ──
  entVideoGames,
  entSeriesMovies,
  entToys,
  entOther,

  // ── وظائف وفرص ──
  jobsFullTime,
  jobsPartTime,
  jobsFreelance,
  jobsInternship,
  jobsOther,

  // Legacy / backward-compat
  buySell;

  /// Returns which group this category belongs to
  PostCategoryGroup get group {
    switch (this) {
      case PostCategory.general:
      case PostCategory.question:
      case PostCategory.help:
      case PostCategory.announcement:
      case PostCategory.discussion:
      case PostCategory.barter:
      case PostCategory.buySell:
        return PostCategoryGroup.general;

      case PostCategory.clothingMen:
      case PostCategory.clothingWomen:
      case PostCategory.clothingKids:
      case PostCategory.clothingShoes:
      case PostCategory.clothingAccessories:
      case PostCategory.clothingTraditional:
      case PostCategory.clothingOther:
        return PostCategoryGroup.clothing;

      case PostCategory.beautyMakeup:
      case PostCategory.beautySkinCare:
      case PostCategory.beautyHair:
      case PostCategory.beautyPerfume:
      case PostCategory.beautyClinic:
      case PostCategory.beautyOther:
        return PostCategoryGroup.beauty;

      case PostCategory.elecMobiles:
      case PostCategory.elecLaptops:
      case PostCategory.elecTV:
      case PostCategory.elecAccessories:
      case PostCategory.elecRepair:
      case PostCategory.elecOther:
        return PostCategoryGroup.electronics;

      case PostCategory.buildCement:
      case PostCategory.buildIron:
      case PostCategory.buildPlumbing:
      case PostCategory.buildElectrical:
      case PostCategory.buildPaint:
      case PostCategory.buildTiles:
      case PostCategory.buildOther:
        return PostCategoryGroup.building;

      case PostCategory.foodRestaurant:
      case PostCategory.foodCatering:
      case PostCategory.foodHomemade:
      case PostCategory.foodBakery:
      case PostCategory.foodGrocery:
      case PostCategory.foodOther:
        return PostCategoryGroup.grocery;

      case PostCategory.homeFurniture:
      case PostCategory.homeAppliances:
      case PostCategory.homeDecor:
      case PostCategory.homeKitchen:
      case PostCategory.homeOther:
        return PostCategoryGroup.homeFurniture;

      case PostCategory.autoBuySell:
      case PostCategory.autoParts:
      case PostCategory.autoRepair:
      case PostCategory.autoRental:
      case PostCategory.autoAccessories:
      case PostCategory.autoOther:
        return PostCategoryGroup.automotive;

      case PostCategory.realEstateSale:
      case PostCategory.realEstateRent:
      case PostCategory.realEstateLand:
      case PostCategory.realEstateOffice:
      case PostCategory.realEstateOther:
        return PostCategoryGroup.realEstate;

      case PostCategory.craftPlumbing:
      case PostCategory.craftElectricity:
      case PostCategory.craftCarpentry:
      case PostCategory.craftPainting:
      case PostCategory.craftWelding:
      case PostCategory.craftAC:
      case PostCategory.craftCleaning:
      case PostCategory.craftTransport:
      case PostCategory.craftOther:
        return PostCategoryGroup.craftsmen;

      case PostCategory.svcLegal:
      case PostCategory.svcAccounting:
      case PostCategory.svcPhotography:
      case PostCategory.svcEvents:
      case PostCategory.svcTranslation:
      case PostCategory.svcDelivery:
      case PostCategory.svcOther:
        return PostCategoryGroup.specialServices;

      case PostCategory.techWebDev:
      case PostCategory.techMobileDev:
      case PostCategory.techDesign:
      case PostCategory.techUIUX:
      case PostCategory.techMarketing:
      case PostCategory.techVideoEditing:
      case PostCategory.techNetworking:
      case PostCategory.techOther:
        return PostCategoryGroup.techCommunity;

      case PostCategory.eduTutoring:
      case PostCategory.eduLanguages:
      case PostCategory.eduTraining:
      case PostCategory.eduOnlineCourses:
      case PostCategory.eduOther:
        return PostCategoryGroup.education;

      case PostCategory.entVideoGames:
      case PostCategory.entSeriesMovies:
      case PostCategory.entToys:
      case PostCategory.entOther:
        return PostCategoryGroup.entertainment;

      case PostCategory.jobsFullTime:
      case PostCategory.jobsPartTime:
      case PostCategory.jobsFreelance:
      case PostCategory.jobsInternship:
      case PostCategory.jobsOther:
        return PostCategoryGroup.jobs;
    }
  }

  String getName(String locale) {
    if (locale == 'ar') {
      switch (this) {
        // عام
        case PostCategory.general:
          return 'عام';
        case PostCategory.question:
          return 'سؤال';
        case PostCategory.help:
          return 'مساعدة';
        case PostCategory.announcement:
          return 'إعلان';
        case PostCategory.discussion:
          return 'نقاش';
        case PostCategory.barter:
          return 'مقايضة وبدل';
        case PostCategory.buySell:
          return 'بيع/شراء';

        // ملبوسات وأزياء
        case PostCategory.clothingMen:
          return 'ملابس رجالي';
        case PostCategory.clothingWomen:
          return 'ملابس حريمي';
        case PostCategory.clothingKids:
          return 'ملابس أطفال';
        case PostCategory.clothingShoes:
          return 'أحذية وشنط';
        case PostCategory.clothingAccessories:
          return 'إكسسوارات';
        case PostCategory.clothingTraditional:
          return 'ثياب وتوب وجلابية';
        case PostCategory.clothingOther:
          return 'ملبوسات أخرى';

        // صحة وجمال
        case PostCategory.beautyMakeup:
          return 'مكياج وتجميل';
        case PostCategory.beautySkinCare:
          return 'عناية بالبشرة';
        case PostCategory.beautyHair:
          return 'شعر وكوافير';
        case PostCategory.beautyPerfume:
          return 'عطور وبخور';
        case PostCategory.beautyClinic:
          return 'عيادات تجميل';
        case PostCategory.beautyOther:
          return 'جمال وصحة أخرى';

        // إلكترونيات
        case PostCategory.elecMobiles:
          return 'موبايلات وجوالات';
        case PostCategory.elecLaptops:
          return 'لابتوبات وكمبيوتر';
        case PostCategory.elecTV:
          return 'شاشات وتلفزيونات';
        case PostCategory.elecAccessories:
          return 'إكسسوارات إلكترونية';
        case PostCategory.elecRepair:
          return 'صيانة أجهزة';
        case PostCategory.elecOther:
          return 'إلكترونيات أخرى';

        // مواد بناء
        case PostCategory.buildCement:
          return 'أسمنت وطوب';
        case PostCategory.buildIron:
          return 'حديد ومعادن';
        case PostCategory.buildPlumbing:
          return 'أدوات صحية';
        case PostCategory.buildElectrical:
          return 'أدوات كهربائية';
        case PostCategory.buildPaint:
          return 'دهانات وبوية';
        case PostCategory.buildTiles:
          return 'بلاط وسيراميك';
        case PostCategory.buildOther:
          return 'مواد بناء أخرى';

        // مأكولات وبقالة
        case PostCategory.foodRestaurant:
          return 'مطاعم';
        case PostCategory.foodCatering:
          return 'تموين وبوفيه';
        case PostCategory.foodHomemade:
          return 'أكل بيتي';
        case PostCategory.foodBakery:
          return 'مخبوزات وحلويات';
        case PostCategory.foodGrocery:
          return 'بقالة ومواد غذائية';
        case PostCategory.foodOther:
          return 'مأكولات أخرى';

        // أثاث ومنزليات
        case PostCategory.homeFurniture:
          return 'أثاث وموبيليا';
        case PostCategory.homeAppliances:
          return 'أجهزة منزلية';
        case PostCategory.homeDecor:
          return 'ديكور ومفروشات';
        case PostCategory.homeKitchen:
          return 'أدوات مطبخ';
        case PostCategory.homeOther:
          return 'منزليات أخرى';

        // سوق العربات
        case PostCategory.autoBuySell:
          return 'بيع وشراء عربات';
        case PostCategory.autoParts:
          return 'قطع غيار';
        case PostCategory.autoRepair:
          return 'ورش وصيانة';
        case PostCategory.autoRental:
          return 'تأجير عربات';
        case PostCategory.autoAccessories:
          return 'إكسسوارات عربات';
        case PostCategory.autoOther:
          return 'عربات أخرى';

        // عقارات وسمسرة
        case PostCategory.realEstateSale:
          return 'بيع عقار';
        case PostCategory.realEstateRent:
          return 'إيجار';
        case PostCategory.realEstateLand:
          return 'أراضي وقطع';
        case PostCategory.realEstateOffice:
          return 'مكاتب ومحلات';
        case PostCategory.realEstateOther:
          return 'عقارات أخرى';

        // صنايعية وحرفيين
        case PostCategory.craftPlumbing:
          return 'سباكة';
        case PostCategory.craftElectricity:
          return 'كهرباء';
        case PostCategory.craftCarpentry:
          return 'نجارة';
        case PostCategory.craftPainting:
          return 'دهان وطلاء';
        case PostCategory.craftWelding:
          return 'لحام وحدادة';
        case PostCategory.craftAC:
          return 'تكييف وتبريد';
        case PostCategory.craftCleaning:
          return 'تنظيف ونظافة';
        case PostCategory.craftTransport:
          return 'نقل وترحيل';
        case PostCategory.craftOther:
          return 'حرف أخرى';

        // خدمات خاصة
        case PostCategory.svcLegal:
          return 'محاماة وقانون';
        case PostCategory.svcAccounting:
          return 'محاسبة ومالية';
        case PostCategory.svcPhotography:
          return 'تصوير فوتوغرافي';
        case PostCategory.svcEvents:
          return 'تنظيم مناسبات';
        case PostCategory.svcTranslation:
          return 'ترجمة';
        case PostCategory.svcDelivery:
          return 'توصيل ومشاوير';
        case PostCategory.svcOther:
          return 'خدمات أخرى';

        // مبرمجين ومصممين
        case PostCategory.techWebDev:
          return 'تطوير مواقع';
        case PostCategory.techMobileDev:
          return 'تطوير تطبيقات';
        case PostCategory.techDesign:
          return 'تصميم جرافيك';
        case PostCategory.techUIUX:
          return 'تصميم واجهات';
        case PostCategory.techMarketing:
          return 'تسويق رقمي';
        case PostCategory.techVideoEditing:
          return 'مونتاج وتصوير';
        case PostCategory.techNetworking:
          return 'شبكات وصيانة';
        case PostCategory.techOther:
          return 'تقنية أخرى';

        // تعليم وتدريب
        case PostCategory.eduTutoring:
          return 'دروس خصوصية';
        case PostCategory.eduLanguages:
          return 'لغات';
        case PostCategory.eduTraining:
          return 'تدريب مهني';
        case PostCategory.eduOnlineCourses:
          return 'دورات أونلاين';
        case PostCategory.eduOther:
          return 'تعليم أخرى';

        // ترفيه وألعاب
        case PostCategory.entVideoGames:
          return 'ألعاب فيديو وبلايستيشن';
        case PostCategory.entSeriesMovies:
          return 'أفلام ومسلسلات';
        case PostCategory.entToys:
          return 'ألعاب أطفال';
        case PostCategory.entOther:
          return 'ترفيه أخرى';

        // وظائف وفرص
        case PostCategory.jobsFullTime:
          return 'وظيفة دوام كامل';
        case PostCategory.jobsPartTime:
          return 'وظيفة دوام جزئي';
        case PostCategory.jobsFreelance:
          return 'عمل حر';
        case PostCategory.jobsInternship:
          return 'تدريب وتأهيل';
        case PostCategory.jobsOther:
          return 'فرص أخرى';
      }
    } else {
      switch (this) {
        // General
        case PostCategory.general:
          return 'General';
        case PostCategory.question:
          return 'Question';
        case PostCategory.help:
          return 'Help';
        case PostCategory.announcement:
          return 'Announcement';
        case PostCategory.discussion:
          return 'Discussion';
        case PostCategory.barter:
          return 'Barter & Swap';
        case PostCategory.buySell:
          return 'Buy/Sell';

        // Clothing
        case PostCategory.clothingMen:
          return 'Men\'s Clothing';
        case PostCategory.clothingWomen:
          return 'Women\'s Clothing';
        case PostCategory.clothingKids:
          return 'Kids\' Clothing';
        case PostCategory.clothingShoes:
          return 'Shoes & Bags';
        case PostCategory.clothingAccessories:
          return 'Accessories';
        case PostCategory.clothingTraditional:
          return 'Traditional Wear';
        case PostCategory.clothingOther:
          return 'Other Clothing';

        // Beauty
        case PostCategory.beautyMakeup:
          return 'Makeup';
        case PostCategory.beautySkinCare:
          return 'Skin Care';
        case PostCategory.beautyHair:
          return 'Hair & Salon';
        case PostCategory.beautyPerfume:
          return 'Perfume & Incense';
        case PostCategory.beautyClinic:
          return 'Beauty Clinic';
        case PostCategory.beautyOther:
          return 'Other Beauty';

        // Electronics
        case PostCategory.elecMobiles:
          return 'Phones & Mobiles';
        case PostCategory.elecLaptops:
          return 'Laptops & Computers';
        case PostCategory.elecTV:
          return 'TVs & Screens';
        case PostCategory.elecAccessories:
          return 'Electronic Accessories';
        case PostCategory.elecRepair:
          return 'Device Repair';
        case PostCategory.elecOther:
          return 'Other Electronics';

        // Building
        case PostCategory.buildCement:
          return 'Cement & Bricks';
        case PostCategory.buildIron:
          return 'Iron & Metals';
        case PostCategory.buildPlumbing:
          return 'Plumbing Supplies';
        case PostCategory.buildElectrical:
          return 'Electrical Supplies';
        case PostCategory.buildPaint:
          return 'Paint & Coating';
        case PostCategory.buildTiles:
          return 'Tiles & Ceramics';
        case PostCategory.buildOther:
          return 'Other Building';

        // Food
        case PostCategory.foodRestaurant:
          return 'Restaurants';
        case PostCategory.foodCatering:
          return 'Catering';
        case PostCategory.foodHomemade:
          return 'Homemade Food';
        case PostCategory.foodBakery:
          return 'Bakery & Sweets';
        case PostCategory.foodGrocery:
          return 'Grocery';
        case PostCategory.foodOther:
          return 'Other Food';

        // Home
        case PostCategory.homeFurniture:
          return 'Furniture';
        case PostCategory.homeAppliances:
          return 'Home Appliances';
        case PostCategory.homeDecor:
          return 'Decor & Furnishings';
        case PostCategory.homeKitchen:
          return 'Kitchen Tools';
        case PostCategory.homeOther:
          return 'Other Home';

        // Automotive
        case PostCategory.autoBuySell:
          return 'Buy & Sell Cars';
        case PostCategory.autoParts:
          return 'Auto Parts';
        case PostCategory.autoRepair:
          return 'Auto Repair';
        case PostCategory.autoRental:
          return 'Car Rental';
        case PostCategory.autoAccessories:
          return 'Car Accessories';
        case PostCategory.autoOther:
          return 'Other Auto';

        // Real Estate
        case PostCategory.realEstateSale:
          return 'Property Sale';
        case PostCategory.realEstateRent:
          return 'Property Rent';
        case PostCategory.realEstateLand:
          return 'Land';
        case PostCategory.realEstateOffice:
          return 'Offices & Shops';
        case PostCategory.realEstateOther:
          return 'Other Real Estate';

        // Craftsmen
        case PostCategory.craftPlumbing:
          return 'Plumbing';
        case PostCategory.craftElectricity:
          return 'Electrical';
        case PostCategory.craftCarpentry:
          return 'Carpentry';
        case PostCategory.craftPainting:
          return 'Painting';
        case PostCategory.craftWelding:
          return 'Welding';
        case PostCategory.craftAC:
          return 'AC & Cooling';
        case PostCategory.craftCleaning:
          return 'Cleaning';
        case PostCategory.craftTransport:
          return 'Transport';
        case PostCategory.craftOther:
          return 'Other Craft';

        // Special Services
        case PostCategory.svcLegal:
          return 'Legal';
        case PostCategory.svcAccounting:
          return 'Accounting';
        case PostCategory.svcPhotography:
          return 'Photography';
        case PostCategory.svcEvents:
          return 'Events';
        case PostCategory.svcTranslation:
          return 'Translation';
        case PostCategory.svcDelivery:
          return 'Delivery';
        case PostCategory.svcOther:
          return 'Other Service';

        // Tech
        case PostCategory.techWebDev:
          return 'Web Development';
        case PostCategory.techMobileDev:
          return 'App Development';
        case PostCategory.techDesign:
          return 'Graphic Design';
        case PostCategory.techUIUX:
          return 'UI/UX Design';
        case PostCategory.techMarketing:
          return 'Digital Marketing';
        case PostCategory.techVideoEditing:
          return 'Video Editing';
        case PostCategory.techNetworking:
          return 'Networking & IT';
        case PostCategory.techOther:
          return 'Other Tech';

        // Education
        case PostCategory.eduTutoring:
          return 'Tutoring';
        case PostCategory.eduLanguages:
          return 'Languages';
        case PostCategory.eduTraining:
          return 'Vocational Training';
        case PostCategory.eduOnlineCourses:
          return 'Online Courses';
        case PostCategory.eduOther:
          return 'Other Education';

        // Entertainment
        case PostCategory.entVideoGames:
          return 'Video Games';
        case PostCategory.entSeriesMovies:
          return 'Movies & Series';
        case PostCategory.entToys:
          return 'Toys';
        case PostCategory.entOther:
          return 'Other Entertainment';

        // Jobs
        case PostCategory.jobsFullTime:
          return 'Full-time Job';
        case PostCategory.jobsPartTime:
          return 'Part-time Job';
        case PostCategory.jobsFreelance:
          return 'Freelance';
        case PostCategory.jobsInternship:
          return 'Internship';
        case PostCategory.jobsOther:
          return 'Other Opportunity';
      }
    }
  }

  /// Get categories for a specific group
  static List<PostCategory> getCategoriesForGroup(PostCategoryGroup group) {
    return PostCategory.values
        .where((c) => c.group == group && c != PostCategory.barter)
        .toList();
  }
} // End PostCategory Enum

/// نموذج استطلاع الرأي — يُضاف داخل المنشور
class PollOption {
  final String text;
  final List<String> voterIds;

  PollOption({required this.text, this.voterIds = const []});

  factory PollOption.fromMap(Map<String, dynamic> data) {
    return PollOption(
      text: SafeParse.string(data['text']),
      voterIds: SafeParse.stringList(data['voterIds']),
    );
  }

  Map<String, dynamic> toMap() => {
        'text': text,
        'voterIds': voterIds,
      };

  PollOption copyWith({String? text, List<String>? voterIds}) {
    return PollOption(
      text: text ?? this.text,
      voterIds: voterIds ?? this.voterIds,
    );
  }
}

class PollModel {
  final String question;
  final List<PollOption> options;
  final DateTime? expiresAt;
  final bool isMultipleChoice;

  PollModel({
    required this.question,
    required this.options,
    this.expiresAt,
    this.isMultipleChoice = false,
  });

  factory PollModel.fromMap(Map<String, dynamic> data) {
    return PollModel(
      question: data['question'] ?? '',
      options: (data['options'] as List<dynamic>? ?? [])
          .map((o) => PollOption.fromMap(Map<String, dynamic>.from(o)))
          .toList(),
      expiresAt: data['expiresAt'] is Timestamp
          ? (data['expiresAt'] as Timestamp).toDate()
          : null,
      isMultipleChoice: data['isMultipleChoice'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'question': question,
        'options': options.map((o) => o.toMap()).toList(),
        if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
        'isMultipleChoice': isMultipleChoice,
      };

  int get totalVotes => options.fold(0, (sum, o) => sum + o.voterIds.length);

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// هل صوّت هذا المستخدم؟
  bool hasVoted(String userId) {
    return options.any((o) => o.voterIds.contains(userId));
  }

  /// ما الخيار الذي صوّت له المستخدم؟
  int? getUserVoteIndex(String userId) {
    for (int i = 0; i < options.length; i++) {
      if (options[i].voterIds.contains(userId)) return i;
    }
    return null;
  }
}

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userRole;
  final String? userJobTitle;
  final String? userImageUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? caption;
  final String? category;
  final List<String> mentionedUsers;
  final Map<String, String> reactions; // userId -> reactionType
  final int commentsCount;
  final int sharesCount;
  final bool showInCommunity;
  final bool showInProfile;
  final bool isPinned;
  final bool isUserVerified;
  final DateTime createdAt;
  final double? price;
  // ── Product-specific fields ──────────────────────────────────
  final List<String> productSizes; // ['S','M','L','XL'] or custom
  final String? productCondition; // 'new' | 'used'
  final String?
      productAgeGroup; // 'baby' | 'child' | 'youth' | 'adult' | 'elderly'
  final List<String> productColors; // ['أحمر','أزرق'] etc.
  final int? quantity; // كمية متاحة
  final bool hasShipping; // هل يوجد توصيل
  // ── Product Link (for community posts) ──────────────────────
  final String? linkedProductId; // رابط المنشور المنتج المرتبط
  final String? linkedProductName; // اسم المنتج للعرض السريع
  final String? linkedProductImage; // صورة المنتج المصغرة
  final double? linkedProductPrice; // سعر المنتج
  final int viewsCount; // عدد المشاهدات
  // ── Poll (استطلاع رأي) ──────────────────────────────────────
  final PollModel? poll;
  // ── Hashtags ────────────────────────────────────────────────
  final List<String> hashtags;

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userRole,
    this.userJobTitle,
    this.userImageUrl,
    this.imageUrl,
    this.imageUrls = const [],
    this.caption,
    this.category,
    this.mentionedUsers = const [],
    this.reactions = const {},
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.showInCommunity = true,
    this.showInProfile = true,
    this.isPinned = false,
    this.isUserVerified = false,
    required this.createdAt,
    this.price,
    this.productSizes = const [],
    this.productCondition,
    this.productAgeGroup,
    this.productColors = const [],
    this.quantity,
    this.hasShipping = false,
    this.linkedProductId,
    this.linkedProductName,
    this.linkedProductImage,
    this.linkedProductPrice,
    this.viewsCount = 0,
    this.poll,
    this.hashtags = const [],
  });

  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return PostModel.fromMap(data);
  }

  factory PostModel.fromMap(Map<String, dynamic> data) {
    return PostModel(
      id: SafeParse.string(data['id']),
      userId: SafeParse.string(data['userId']),
      userName: SafeParse.string(data['userName']),
      userRole: SafeParse.nullableString(data['userRole']),
      userJobTitle: SafeParse.nullableString(data['userJobTitle']),
      userImageUrl: SafeParse.nullableString(data['userImageUrl']),
      imageUrl: SafeParse.nullableString(data['imageUrl']),
      imageUrls: SafeParse.stringList(data['imageUrls']),
      caption: SafeParse.nullableString(data['caption']),
      category: SafeParse.nullableString(data['category']),
      mentionedUsers: SafeParse.stringList(data['mentionedUsers']),
      reactions: SafeParse.stringMap(data['reactions']),
      commentsCount: SafeParse.integer(data['commentsCount']),
      sharesCount: SafeParse.integer(data['sharesCount']),
      showInCommunity: SafeParse.boolean(data['showInCommunity'], true),
      showInProfile: SafeParse.boolean(data['showInProfile']),
      isPinned: SafeParse.boolean(data['isPinned']),
      isUserVerified: SafeParse.boolean(data['isUserVerified']),
      createdAt: SafeParse.dateTime(data['createdAt']),
      price: SafeParse.nullableDecimal(data['price']),
      productSizes: SafeParse.stringList(data['productSizes']),
      productCondition: SafeParse.nullableString(data['productCondition']),
      productAgeGroup: SafeParse.nullableString(data['productAgeGroup']),
      productColors: SafeParse.stringList(data['productColors']),
      quantity:
          data['quantity'] != null ? SafeParse.integer(data['quantity']) : null,
      hasShipping: SafeParse.boolean(data['hasShipping']),
      linkedProductId: SafeParse.nullableString(data['linkedProductId']),
      linkedProductName: SafeParse.nullableString(data['linkedProductName']),
      linkedProductImage: SafeParse.nullableString(data['linkedProductImage']),
      linkedProductPrice: SafeParse.nullableDecimal(data['linkedProductPrice']),
      viewsCount: SafeParse.integer(data['viewsCount']),
      poll: data['poll'] is Map
          ? (() {
              try {
                return PollModel.fromMap(
                    Map<String, dynamic>.from(data['poll'] as Map));
              } catch (_) {
                return null;
              }
            })()
          : null,
      hashtags: SafeParse.stringList(data['hashtags']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'userId': userId,
      'userName': userName,
      'userRole': userRole,
      'userJobTitle': userJobTitle,
      'userImageUrl': userImageUrl,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'caption': caption,
      'mentionedUsers': mentionedUsers,
      'reactions': reactions,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'showInCommunity': showInCommunity,
      'showInProfile': showInProfile,
      'isPinned': isPinned,
      'isUserVerified': isUserVerified,
      'createdAt': Timestamp.fromDate(createdAt),
      if (price != null) 'price': price,
      if (productSizes.isNotEmpty) 'productSizes': productSizes,
      if (productCondition != null) 'productCondition': productCondition,
      if (productAgeGroup != null) 'productAgeGroup': productAgeGroup,
      if (productColors.isNotEmpty) 'productColors': productColors,
      if (quantity != null) 'quantity': quantity,
      if (hasShipping) 'hasShipping': hasShipping,
      if (linkedProductId != null) 'linkedProductId': linkedProductId,
      if (linkedProductName != null) 'linkedProductName': linkedProductName,
      if (linkedProductImage != null) 'linkedProductImage': linkedProductImage,
      if (linkedProductPrice != null) 'linkedProductPrice': linkedProductPrice,
      'viewsCount': viewsCount,
      if (poll != null) 'poll': poll!.toMap(),
      if (hashtags.isNotEmpty) 'hashtags': hashtags,
    };
    if (category != null) {
      map['category'] = category;
    }
    return map;
  }

  // JSON Map for Hive Cache
  Map<String, dynamic> toJsonMap() {
    final map = toFirestore();
    map['id'] = id;
    return SafeParse.sanitizeForCache(map);
  }

  /// Returns all image URLs (merges legacy imageUrl + imageUrls list)
  List<String> get allImageUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    for (final url in imageUrls) {
      if (!urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  int get totalReactions => reactions.length;

  String? getUserReaction(String userId) => reactions[userId];

  PostModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userRole,
    String? userJobTitle,
    String? userImageUrl,
    String? imageUrl,
    List<String>? imageUrls,
    String? caption,
    String? category,
    List<String>? mentionedUsers,
    Map<String, String>? reactions,
    int? commentsCount,
    int? sharesCount,
    bool? isPinned,
    bool? isUserVerified,
    bool? showInCommunity,
    bool? showInProfile,
    DateTime? createdAt,
    double? price,
    List<String>? productSizes,
    String? productCondition,
    String? productAgeGroup,
    List<String>? productColors,
    int? quantity,
    bool? hasShipping,
    String? linkedProductId,
    String? linkedProductName,
    String? linkedProductImage,
    double? linkedProductPrice,
    int? viewsCount,
    PollModel? poll,
    List<String>? hashtags,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      userJobTitle: userJobTitle ?? this.userJobTitle,
      userImageUrl: userImageUrl ?? this.userImageUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      caption: caption ?? this.caption,
      category: category ?? this.category,
      mentionedUsers: mentionedUsers ?? this.mentionedUsers,
      reactions: reactions ?? this.reactions,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      showInCommunity: showInCommunity ?? this.showInCommunity,
      showInProfile: showInProfile ?? this.showInProfile,
      isPinned: isPinned ?? this.isPinned,
      isUserVerified: isUserVerified ?? this.isUserVerified,
      createdAt: createdAt ?? this.createdAt,
      price: price ?? this.price,
      productSizes: productSizes ?? this.productSizes,
      productCondition: productCondition ?? this.productCondition,
      productAgeGroup: productAgeGroup ?? this.productAgeGroup,
      productColors: productColors ?? this.productColors,
      quantity: quantity ?? this.quantity,
      hasShipping: hasShipping ?? this.hasShipping,
      linkedProductId: linkedProductId ?? this.linkedProductId,
      linkedProductName: linkedProductName ?? this.linkedProductName,
      linkedProductImage: linkedProductImage ?? this.linkedProductImage,
      linkedProductPrice: linkedProductPrice ?? this.linkedProductPrice,
      viewsCount: viewsCount ?? this.viewsCount,
      poll: poll ?? this.poll,
      hashtags: hashtags ?? this.hashtags,
    );
  }
}
