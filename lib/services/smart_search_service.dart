/// خدمة البحث الذكي - Smart Search Service
/// يبحث باستخدام المرادفات والتطابق التقريبي بدون AI
class SmartSearchService {
  // مرادفات الأعمال الشائعة في السودان
  static const Map<String, List<String>> _jobSynonyms = {
    // السباكة
    'سباك': ['سباكة', 'سبّاك', 'فني صحي', 'فني مواسير'],
    'سباكة': ['سباك', 'سبّاك', 'فني صحي', 'فني مواسير'],

    // الكهرباء
    'كهربائي': ['كهرباء', 'كهربجي', 'فني كهرباء'],
    'كهرباء': ['كهربائي', 'كهربجي', 'فني كهرباء'],

    // النجارة
    'نجار': ['نجارة', 'نجّار', 'فني أثاث', 'اعمال خشبية'],
    'نجارة': ['نجار', 'نجّار', 'فني أثاث', 'اعمال خشبية'],

    // الحدادة
    'حداد': ['حدادة', 'حدّاد', 'فني حديد', 'اعمال حديد'],
    'حدادة': ['حداد', 'حدّاد', 'فني حديد', 'اعمال حديد'],

    // الدهان
    'دهان': ['دهانات', 'نقاش', 'صباغ', 'فني طلاء'],
    'نقاش': ['دهان', 'دهانات', 'صباغ', 'فني طلاء'],

    // البناء
    'بناء': ['بنّاء', 'عامل بناء', 'مقاول', 'بناية'],
    'مقاول': ['بناء', 'بنّاء', 'عامل بناء', 'مقاولات'],

    // التكييف
    'تكييف': ['مكيفات', 'فني تكييف', 'تبريد', 'صيانة مكيفات'],
    'مكيفات': ['تكييف', 'فني تكييف', 'تبريد', 'صيانة مكيفات'],

    // السيارات
    'ميكانيكي': ['ميكانيكا', 'كهربائي سيارات', 'فني سيارات', 'ميكانيكي سيارات'],
    'كهربائي سيارات': ['ميكانيكي', 'فني سيارات', 'ميكانيكي سيارات'],

    // التعليم
    'مدرس': ['مدرّس', 'معلم', 'أستاذ', 'تدريس'],
    'معلم': ['مدرس', 'مدرّس', 'أستاذ', 'تدريس'],

    // التصميم
    'مصمم': ['تصميم', 'مصمم جرافيك', 'جرافيك', 'ديزاينر'],
    'تصميم': ['مصمم', 'مصمم جرافيك', 'جرافيك'],

    // البرمجة
    'مبرمج': ['برمجة', 'مطور', 'برمجيات', 'مطور برامج', 'مطور تطبيقات'],
    'مطور': ['مبرمج', 'برمجة', 'برمجيات', 'مطور تطبيقات'],

    // التنظيف
    'تنظيف': ['نظافة', 'عامل نظافة', 'تنضيف', 'غسيل', 'مكوة', 'مكوجي'],
    'نظافة': ['تنظيف', 'عامل نظافة', 'نضافه'],

    // النقل والترحيل (لهجة سودانية)
    'سائق': [
      'سواق',
      'توصيل',
      'نقل عفش',
      'ترحيل',
      'مشاوير',
      'امجاد',
      'أمجاد',
      'ركشة',
      'طرحة',
      'هايس',
      'دفار'
    ],
    'نقل': [
      'سائق',
      'سواق',
      'توصيل',
      'ناقل',
      'ترحيل',
      'نقل عفش',
      'دفار',
      'ركشة'
    ],

    // الطبخ والأكل
    'طباخ': [
      'طبخ',
      'شيف',
      'طاهي',
      'صناعة طعام',
      'طباخة',
      'اكل بيتي',
      'عصيدة',
      'كسرة'
    ],
    'شيف': ['طباخ', 'طبخ', 'طاهي'],

    // الهواتف وصيانتها
    'موبايل': [
      'موبايلات',
      'هاتف',
      'هواتف',
      'جوال',
      'جوالات',
      'تلفون',
      'تلفونات'
    ],
    'موبايلات': [
      'موبايل',
      'هاتف',
      'هواتف',
      'جوال',
      'جوالات',
      'تلفون',
      'تلفونات'
    ],
    'هاتف': ['موبايل', 'هواتف', 'جوال', 'تلفون', 'تلفونات'],
    'جوال': ['موبايل', 'موبايلات', 'هاتف', 'هواتف', 'تلفون', 'تلفونات'],

    // الصيانة بشكل عام
    'صيانة': ['تصليح', 'مهندس صيانة', 'فني صيانة'],
    'تصليح': ['صيانة', 'مهندس صيانة', 'فني صيانة'],

    // الأجهزة الإلكترونية
    'إلكترونيات': [
      'اجهزه',
      'أجهزة',
      'لابتوب',
      'حاسوب',
      'كمبيوتر',
      'شاشات',
      'صيانة اجهزة',
      'رسيفر',
      'دش'
    ],
    'كمبيوتر': ['لابتوب', 'حاسوب', 'إلكترونيات', 'صيانة كمبيوتر', 'لبتوب'],

    // صيانة الهواتف المدمجة
    'صيانة موبايل': [
      'صيانة هواتف',
      'تصليح موبايلات',
      'صيانة جوالات',
      'صيانة تلفونات',
      'تصليح هواتف',
      'صيانة موبايلات',
      'سوفت وير'
    ],
    'صيانة هواتف': [
      'صيانة موبايل',
      'تصليح موبايلات',
      'صيانة جوالات',
      'صيانة تلفونات',
      'تصليح هواتف',
      'صيانة موبايلات',
      'بتاع تلفونات'
    ],

    // المهن والحرف الإضافية (لهجة سودانية)
    'خياط': ['ترزي', 'تفصيل', 'خياطة', 'تطريز', 'جلابية', 'توب'],
    'ترزي': ['خياط', 'خياطة', 'تفصيل', 'جلابية'],
    'سمكري': ['بوهيجي', 'سمكرة', 'بوهية', 'بتاع بوهية', 'صيانة عربات'],
    'بنشرجي': ['بتاع لساتك', 'رقعة', 'هواء', 'بنشر', 'لساتك'],
  };

  /// خريطة تحويل أسماء الـ Enum الإنجليزية → كلمات عربية للبحث
  /// هذا هو الإصلاح الجذري: المهارات مخزونة كـ "mobileDevelopment" لكن المستخدم يبحث بـ "مبرمج"
  static const Map<String, List<String>> _skillCategoryKeywords = {
    'webDevelopment': [
      'مبرمج',
      'برمجة',
      'مطور',
      'مطور ويب',
      'تطوير ويب',
      'ويب'
    ],
    'mobileDevelopment': [
      'مبرمج',
      'برمجة',
      'مطور',
      'تطوير تطبيقات',
      'مطور تطبيقات',
      'تطبيقات'
    ],
    'design': ['مصمم', 'تصميم', 'جرافيك', 'ديزاينر', 'مصمم جرافيك'],
    'writing': ['كاتب', 'كتابة', 'محتوى'],
    'translation': ['مترجم', 'ترجمة'],
    'marketing': ['تسويق', 'مسوق', 'اعلانات'],
    'dataEntry': ['إدخال بيانات', 'داتا', 'داتا انتري'],
    'videoEditing': ['مونتاج', 'مونتير', 'فيديو', 'مونتاج فيديو'],
    'photography': ['مصور', 'تصوير', 'فوتوغرافي'],
    'tutoring': ['مدرس', 'معلم', 'تدريس', 'دروس'],
    'teaching': ['مدرس', 'معلم', 'تدريس', 'أستاذ'],
    'privateTutoring': ['مدرس خصوصي', 'مدرس', 'معلم', 'دروس خصوصية'],
    'teachingConsultant': ['مستشار تدريس', 'مدرس', 'معلم'],
    'construction': ['بناء', 'بنّاء', 'مقاول', 'عامل بناء'],
    'electrical': ['كهربائي', 'كهرباء', 'فني كهرباء', 'كهربجي'],
    'plumbing': ['سباك', 'سباكة', 'فني صحي', 'فني مواسير'],
    'painting': ['دهان', 'نقاش', 'صباغ', 'فني طلاء'],
    'carpentry': ['نجار', 'نجارة', 'فني أثاث'],
    'carMaintenance': ['ميكانيكي', 'ميكانيكا', 'صيانة سيارات', 'فني سيارات'],
    'carWash': ['غسيل سيارات', 'غسيل عربيات'],
    'cleaning': ['تنظيف', 'نظافة', 'عامل نظافة'],
    'movingServices': ['نقل', 'نقل عفش', 'ترحيل', 'سائق'],
    'airConditioning': ['تكييف', 'مكيفات', 'فني تكييف', 'تبريد'],
    'applianceRepair': ['صيانة أجهزة', 'صيانة', 'فني صيانة', 'تصليح'],
    'tourGuide': ['مرشد سياحي', 'مرشد', 'سياحة'],
    'driving': ['سائق', 'سواق', 'شوفير'],
    'delivery': ['توصيل', 'ديليفري', 'دليفري'],
    'cooking': ['طباخ', 'طبخ', 'شيف', 'طاهي'],
    'tailoring': ['خياط', 'خياطة', 'ترزي', 'تفصيل'],
    'beauty': ['تجميل', 'كوافير', 'مكياج', 'بيوتي'],
    'lawyer': ['محامي', 'محاماة', 'قانوني'],
    'chef': ['طباخ', 'شيف', 'طبخ'],
    'translator': ['مترجم', 'ترجمة'],
    'eventCatering': ['تلبية مناسبات', 'أفراح', 'حفلات', 'ضيافة'],
    'baker': ['فران', 'خباز', 'خبز'],
    'pastryChef': ['حلويات', 'بنكجي', 'كيكة'],
    'waiter': ['طاولجي', 'نادل', 'خدمة طاولات'],
    'clinicReception': ['استقبال عيادات', 'استقبال', 'سكرتير'],
    'appointmentBooking': ['حجز مواعيد', 'حجز'],
    'clinicInquiry': ['استفسار عيادات', 'استفسار'],
    'furnitureMoving': ['نقل أثاث', 'نقل عفش', 'ترحيل'],
    'goodsTransport': ['نقل بضائع', 'شحن', 'نقل'],
    'privateRides': ['مشاوير خاصة', 'مشاوير', 'ترحيل', 'ركشة'],
    'vacuumTruck': ['شفط بالهواء', 'شفط', 'سحب'],
    'buildingMaterialsTransport': ['نقل مواد بناء', 'نقل بناء'],
    'dumpTruckDirt': ['قلابات تراب', 'قلابة', 'تراب'],
    'dumpTruckSand': ['قلابات رملة', 'قلابة', 'رمل', 'رملة'],
    'dumpTruckConcrete': ['قلابات خرسانة', 'خرسانة'],
    'bartering': ['مقايضة', 'بيع وشراء'],
  };

  /// استخراج اقتراحات بحث محفوظة محلياً في التطبيق بناءً على الإدخال
  static List<String> getPredefinedSuggestions(String query) {
    if (query.isEmpty) return [];

    final normalizedQuery = _normalizeArabic(query.toLowerCase().trim());
    final Set<String> results = {};

    // البحث في المفاتيح الأساسية
    for (final key in _jobSynonyms.keys) {
      if (_normalizeArabic(key).contains(normalizedQuery)) {
        results.add(key);
      }
    }

    // البحث في المرادفات
    for (final entry in _jobSynonyms.entries) {
      for (final synonym in entry.value) {
        if (_normalizeArabic(synonym).contains(normalizedQuery)) {
          results.add(synonym);
          // يمكن أيضاً إضافة المفتاح الرئيسي ليظهر كخيار
          results.add(entry.key);
        }
      }
    }

    // إضافة المجالات الأخرى وتصنيفات المتاجر
    const otherKeywords = [
      // خدمات متنوعة
      'تطوير تطبيقات', 'مونتاج فيديو', 'إدخال بيانات', 'تسويق',
      'ترجمة', 'صيانة أجهزة', 'خياطة', 'تجميل', 'مدرس خصوصي',
      'محامي', 'نقل عفش', 'مشاوير',
      // تصنيفات المتاجر (Shops)
      'إلكترونيات', 'ملابس', 'أثاث', 'مواد غذائية', 'مطعم',
      'سوبرماركت', 'صيدلية', 'تجميل ومستحضرات', 'قطع غيار سيارات',
      'مواد بناء', 'مجوهرات', 'جوالات وإكسسوارات', 'مكتبة',
      'رياضة', 'ألعاب أطفال', 'أدوات منزلية', 'موبايلات'
    ];

    for (final keyword in otherKeywords) {
      if (_normalizeArabic(keyword).contains(normalizedQuery)) {
        results.add(keyword);
      }
    }

    // إضافة المواقع والأحياء
    for (final neighborhood in _knownNeighborhoods) {
      if (_normalizeArabic(neighborhood).contains(normalizedQuery)) {
        results.add(neighborhood);
      }
    }

    return results.take(8).toList();
  }

  // كلمات الربط التي تفصل بين الخدمة والموقع
  static const List<String> _locationKeywords = [
    'في',
    'ب',
    'من',
    'قرب',
    'حي',
    'منطقة',
    'شارع'
  ];

  // أسماء أحياء ومناطق مشهورة في السودان (للتطابق التقريبي)
  static const List<String> _knownNeighborhoods = [
    // ==================== ولاية الخرطوم ====================
    // الخرطوم
    'الرياض', 'المعمورة', 'الخرطوم ٢', 'الخرطوم 2', 'الصحافة', 'جبرة',
    'المنشية',
    'الديوم', 'الديوم الشرقية', 'بري', 'بري اللاماب', 'بري المحس',
    'الطائف', 'الأزهري', 'المقرن', 'الخرطوم شرق', 'كافوري',
    'أركويت', 'الشجرة', 'جبل المرخيات', 'سوبا', 'الكلاكلة',
    'ناصر', 'الفيحاء', 'الجريف شرق', 'الجريف غرب', 'المنصورة',
    'الاندلس', 'النزهة', 'حي العرب', 'الشهيد طه', 'العمارات', 'الخرطوم ٣',
    'جبل أولياء', 'الشعبية', 'النصر', 'حلة حمد', 'الدروشاب',
    // أم درمان
    'أم بدة', 'ام بدة', 'أم بده', 'الثورة', 'أبو سعد', 'ابو سعد',
    'الفتيحاب', 'بيت المال', 'الملازمين', 'الموردة', 'العباسية',
    'ود نوباوي', 'أبو روف', 'ابو روف', 'الحارة', 'الحارة الأولى',
    'الحارة الثانية', 'الحارة الثالثة', 'العرضة', 'السوق الكبير',
    'ال30', 'ال ٣٠', 'الثلاثين', 'عربية خاصة',
    'أم درمان الثورة', 'حي النصر', 'حي الوحدة', 'الهاشماب',
    'ود البخيت', 'الخليفة', 'حي السلام', 'حي المهندسين',
    // بحري
    'الحاج يوسف', 'حاج يوسف', 'الحلفاية', 'شمبات', 'الصبابي',
    'الخوجلاب', 'التكينة', 'بحري الصناعية', 'المزاد',
    'حلة خوجلي', 'الدناقلة', 'الكدرو', 'السامراب',
    'الشقلة', 'أم دوم', 'ام دوم', 'الباقير', 'المؤسسة',
    // كرري وشرق النيل
    'كرري', 'أم القرى', 'الفتح', 'أبو حليمة',
    'شرق النيل', 'الجريف', 'حلة كوكو',

    // ==================== ولاية الجزيرة ====================
    'ود مدني', 'الكاملين', 'الحصاحيصا', 'المناقل', 'الهلالية',
    'حي الموظفين', 'حي الضباط', 'حي الوادي', 'حي السلام', 'حي الربيع',
    'حنتوب', 'الحوش', 'طابت', 'الحاج عبدالله', 'أبو عشر',
    'ود النيل', 'ود المليك', 'المسيد', 'الخيرات', 'أبو حراز',

    // ==================== ولاية نهر النيل ====================
    'الدامر', 'عطبرة', 'شندي', 'بربر', 'أبو حمد', 'المتمة',
    'حي السوق', 'حي الجامعة', 'حي المطار', 'حي الشاطئ',
    'أم علي', 'كبوشية', 'الزيداب', 'العبيدية', 'المكابراب',
    'حي النخيل', 'حي البساتين', 'حي التقدم', 'حي الأمل',

    // ==================== الولاية الشمالية ====================
    'دنقلا', 'مروي', 'كريمة', 'دلقو', 'حلفا', 'أرقو', 'نوري',
    'الدبة', 'البرقيق', 'القولد', 'صاي', 'دنقلا العجوز',
    'الغابة', 'الخندق', 'أبكر', 'جدي',

    // ==================== ولاية كسلا ====================
    'كسلا', 'حلفا الجديدة', 'خشم القربة', 'ود الحليو', 'أروما',
    'حي الجامعة', 'حي المطار', 'حي التاكا', 'حي النشيشبة',
    'حي كرن', 'حي الخلاء', 'حي المنشية', 'حي الميرغنية',
    'تلكوك', 'همشكوريب', 'الشوك',

    // ==================== ولاية القضارف ====================
    'القضارف', 'قلع النحل', 'الفاو', 'الفشقة', 'القريشة', 'الرهد',
    'حي الشرقي', 'حي الغربي', 'حي الوحدة', 'حي الثورة',
    'حي المصالح', 'حي سلالاب', 'حي المدنيين', 'الغرب',
    'دوكة', 'القلابات', 'أم السنط',

    // ==================== ولاية البحر الأحمر ====================
    'بورتسودان', 'سواكن', 'طوكر', 'هيا', 'جبيت', 'سنكات',
    'حي ديم عرب', 'حي ديم مدني', 'حي ديم النور', 'حي السلام',
    'حي الضباط', 'حي المطار', 'حي الهبيل', 'حي العمال',
    'حي الأمراء', 'حي البوادر', 'حي المينا', 'حي فلامنقو',

    // ==================== ولاية سنار ====================
    'سنار', 'سنجة', 'الدندر', 'الدالي', 'المزموم',
    'حي العشرة', 'حي السوق', 'حي البوستة', 'حي الدرجة',
    'أبو نعامة', 'مايورنو', 'الصوفي',

    // ==================== ولاية النيل الأزرق ====================
    'الدمازين', 'الروصيرص', 'باو', 'قيسان', 'الكرمك',
    'حي السوق', 'حي الوحدة', 'حي السلام', 'حي النيل',
    'ديم النور', 'حي المعلمين', 'حي المهندسين',

    // ==================== ولاية النيل الأبيض ====================
    'ربك', 'كوستي', 'الدويم', 'تندلتي', 'أم رمتة', 'الجزيرة أبا',
    'حي المنشية', 'حي بانت', 'حي الأزهري', 'حي السلام',
    'حي النصر', 'حي الثورة', 'حي الزهور', 'أم جر',
    'جبل الأولياء', 'الجبلين', 'كنانة',

    // ==================== شمال كردفان ====================
    'الأبيض', 'شيكان', 'أم روابة', 'النهود', 'بارا', 'سودري',
    'حي السوق الكبير', 'حي الثورة', 'حي السلام', 'حي المعلمين',
    'حي أبو حبل', 'حي النزلة', 'حي الموظفين', 'حي الضباط',
    'حي المطار', 'حي النصر', 'أم درمان كردفان',

    // ==================== جنوب كردفان ====================
    'كادقلي', 'الدلنج', 'أبو جبيهة', 'تلودي', 'رشاد', 'الليري',
    'حي السوق', 'حي الضباط', 'حي الأمل', 'حي العسكر',
    'هبيلا', 'كيلك', 'كلوقي', 'أم برمبيطة',

    // ==================== غرب كردفان ====================
    'الفولة', 'النهود', 'أبو زبد', 'المجلد', 'لقاوة',
    'حي السوق', 'حي البلدية', 'حي الثورة', 'حي النصر',
    'بابنوسة', 'المرام', 'غبيش',

    // ==================== شمال دارفور ====================
    'الفاشر', 'كتم', 'كبكابية', 'أم كدادة', 'الكومة', 'طويلة', 'مليط',
    'حي السوق', 'حي المطار', 'حي الوحدة', 'حي السلام',
    'حي الثورة', 'حي الميدان', 'أبو شوك',

    // ==================== جنوب دارفور ====================
    'نيالا', 'كاس', 'مرشنج', 'قريضة', 'تلس', 'عد الفرسان', 'شعيرية',
    'حي السوق الكبير', 'حي دومة', 'حي السلام', 'حي الوحدة',
    'حي المطار', 'حي الثورة', 'حي المنشية', 'كلمة',

    // ==================== غرب دارفور ====================
    'الجنينة', 'كرينك', 'سربا', 'هبيلا', 'مستري', 'بيضة',
    'حي السوق', 'حي الجامعة', 'حي النصر', 'حي الوحدة',
    'حي الشهداء', 'حي الضباط', 'مسطري',

    // ==================== وسط دارفور ====================
    'زالنجي', 'نرتتي', 'أم دخن', 'أزوم', 'بندسي',
    'حي السوق', 'حي المركز', 'حي السلام', 'روكيرو',

    // ==================== شرق دارفور ====================
    'الضعين', 'أبو كارنكا', 'عديلة', 'أبو جابرة',
    'حي السوق', 'حي الشعبي', 'حي النصر', 'حي المجلس',
    'أبو مطارق', 'لعيت',
  ];

  /// البحث الذكي - يشمل المرادفات والتطابق الجزئي
  static bool matchesSearch(
    String searchQuery, {
    required String name,
    required List<String> skills,
    String? jobTitle,
    String? bio,
  }) {
    if (searchQuery.isEmpty) return true;

    final query = _normalizeArabic(searchQuery.toLowerCase().trim());
    final expandedQueries = _expandQuery(query);

    // البحث في كل الحقول
    for (final q in expandedQueries) {
      // البحث في الاسم
      if (_containsMatch(_normalizeArabic(name.toLowerCase()), q)) return true;

      // البحث في نوع العمل
      if (jobTitle != null &&
          _containsMatch(_normalizeArabic(jobTitle.toLowerCase()), q))
        return true;

      // البحث في المهارات (نصاً مباشراً أو عبر خريطة الـ Enum → عربي)
      for (final skill in skills) {
        // مطابقة مباشرة (للمهارات المخصصة المكتوبة بالعربي)
        if (_containsMatch(_normalizeArabic(skill.toLowerCase()), q))
          return true;
        // *** الإصلاح الجذري: تحويل اسم الـ Enum الإنجليزي → كلمات عربية ثم مطابقة ***
        final arabicKeywords = _skillCategoryKeywords[skill] ?? [];
        for (final keyword in arabicKeywords) {
          if (_containsMatch(_normalizeArabic(keyword.toLowerCase()), q))
            return true;
        }
      }

      // البحث في النبذة
      if (bio != null && _containsMatch(_normalizeArabic(bio.toLowerCase()), q))
        return true;
    }

    return false;
  }

  /// البحث الذكي المتقدم - يفهم جمل مثل "سباك في أم درمان"
  /// يفصل الاستعلام إلى جزء المهارة وجزء الموقع
  static bool matchesSmartSearch(
    String searchQuery, {
    required String name,
    required List<String> skills,
    String? jobTitle,
    String? bio,
    String? state,
    String? locality,
  }) {
    if (searchQuery.isEmpty) return true;

    final query = _normalizeArabic(searchQuery.toLowerCase().trim());

    // محاولة تقسيم الاستعلام إلى مهارة + موقع
    final parsed = _parseQuery(query);

    if (parsed != null) {
      // تم العثور على كلمة ربط → بحث مركب (مهارة + موقع)
      final skillMatch = _matchesSkillPart(parsed.skillPart,
          name: name, skills: skills, jobTitle: jobTitle);
      final locationMatch = _matchesLocationPart(parsed.locationPart,
          bio: bio, state: state, locality: locality);
      return skillMatch && locationMatch;
    }

    // لا توجد كلمة ربط → بحث عادي (ممكن يكون اسم حي أو مهارة)
    // جرّب البحث العادي أولاً
    if (matchesSearch(searchQuery,
        name: name, skills: skills, jobTitle: jobTitle, bio: bio)) {
      return true;
    }

    // جرّب مطابقة كحي في النبذة أو الموقع
    if (_matchesLocationPart(query,
        bio: bio, state: state, locality: locality)) {
      return true;
    }

    return false;
  }

  static _ParsedQuery? _parseQuery(String query) {
    // 1. Try explicit connecting words ("في", "ب")
    for (final keyword in _locationKeywords) {
      final normalizedKeyword = _normalizeArabic(keyword);
      final pattern = keyword.length == 1
          ? ' $normalizedKeyword' // حرف واحد مثل "ب"
          : ' $normalizedKeyword '; // كلمة كاملة مثل "في"

      final index = query.indexOf(pattern);
      if (index > 0) {
        final skillPart = query.substring(0, index).trim();
        final locationPart = query.substring(index + pattern.length).trim();
        if (skillPart.isNotEmpty && locationPart.isNotEmpty) {
          return _ParsedQuery(skillPart: skillPart, locationPart: locationPart);
        }
      }
    }

    // 2. Try implicit composite search (e.g. "مبرمج ام درمان")
    for (final keyword in [..._locationKeywords, ..._knownNeighborhoods]) {
      final normalizedKeyword = _normalizeArabic(keyword);
      if (query.length > normalizedKeyword.length &&
          query.contains(normalizedKeyword)) {
        final skillPart = query.replaceAll(normalizedKeyword, '').trim();
        if (skillPart.isNotEmpty) {
          return _ParsedQuery(
              skillPart: skillPart, locationPart: normalizedKeyword);
        }
      }
    }

    return null;
  }

  /// مطابقة جزء المهارة
  static bool _matchesSkillPart(
    String skillQuery, {
    required String name,
    required List<String> skills,
    String? jobTitle,
  }) {
    final expandedQueries = _expandQuery(skillQuery);
    for (final q in expandedQueries) {
      if (_containsMatch(_normalizeArabic(name.toLowerCase()), q)) return true;
      if (jobTitle != null &&
          _containsMatch(_normalizeArabic(jobTitle.toLowerCase()), q))
        return true;
      for (final skill in skills) {
        // مطابقة مباشرة (للمهارات المخصصة المكتوبة بالعربي)
        if (_containsMatch(_normalizeArabic(skill.toLowerCase()), q))
          return true;
        // *** الإصلاح الجذري: تحويل اسم الـ Enum → عربي ***
        final arabicKeywords = _skillCategoryKeywords[skill] ?? [];
        for (final keyword in arabicKeywords) {
          if (_containsMatch(_normalizeArabic(keyword.toLowerCase()), q))
            return true;
        }
      }
    }
    return false;
  }

  /// مطابقة جزء الموقع (ولاية، محلية، نبذة، أحياء)
  static bool _matchesLocationPart(
    String locationQuery, {
    String? bio,
    String? state,
    String? locality,
  }) {
    final normalizedQuery = _normalizeArabic(locationQuery);

    // مطابقة مباشرة مع الولاية والمحلية
    if (state != null &&
        _containsMatch(_normalizeArabic(state.toLowerCase()), normalizedQuery))
      return true;
    if (locality != null &&
        _containsMatch(
            _normalizeArabic(locality.toLowerCase()), normalizedQuery))
      return true;

    // مطابقة مع النبذة (هنا يكتب المستخدم حيه)
    if (bio != null) {
      final normalizedBio = _normalizeArabic(bio.toLowerCase());
      if (_containsMatch(normalizedBio, normalizedQuery)) return true;

      // مطابقة تقريبية مع أسماء الأحياء المعروفة
      // إذا بحث المستخدم باسم حي معروف، نبحث عنه في النبذة بتطابق تقريبي
      for (final neighborhood in _knownNeighborhoods) {
        final normalizedNeighborhood =
            _normalizeArabic(neighborhood.toLowerCase());
        // هل الاستعلام يطابق اسم حي معروف (تقريبياً)؟
        if (_isFuzzyMatch(normalizedQuery, normalizedNeighborhood)) {
          // هل هذا الحي مذكور في النبذة (تقريبياً)؟
          final bioWords = normalizedBio.split(RegExp(r'\s+'));
          for (int i = 0; i < bioWords.length; i++) {
            // مطابقة كلمة واحدة أو كلمتين متتاليتين
            final singleWord = bioWords[i];
            final doubleWord = i + 1 < bioWords.length
                ? '${bioWords[i]} ${bioWords[i + 1]}'
                : '';

            if (_isFuzzyMatch(singleWord, normalizedNeighborhood) ||
                _isFuzzyMatch(doubleWord, normalizedNeighborhood)) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  /// مطابقة تقريبية متقدمة - تسمح بأخطاء إملائية
  static bool _isFuzzyMatch(String text, String target) {
    if (text.isEmpty || target.isEmpty) return false;
    if (text == target) return true;
    if (text.contains(target) || target.contains(text)) return true;

    // مقارنة بدون فراغات
    final textNoSpaces = text.replaceAll(' ', '');
    final targetNoSpaces = target.replaceAll(' ', '');
    if (textNoSpaces == targetNoSpaces) return true;
    if (textNoSpaces.contains(targetNoSpaces) ||
        targetNoSpaces.contains(textNoSpaces)) return true;

    // Levenshtein-like: إذا كان الفرق <= 2 حرف (للكلمات الطويلة)
    if (text.length >= 3 && target.length >= 3) {
      final distance = _levenshtein(textNoSpaces, targetNoSpaces);
      final maxLen = textNoSpaces.length > targetNoSpaces.length
          ? textNoSpaces.length
          : targetNoSpaces.length;
      // سماح بخطأ 1 لكل 4 أحرف (الحد الأدنى 1)
      final allowedErrors = (maxLen / 4).ceil();
      if (distance <= allowedErrors) return true;
    }

    return false;
  }

  /// حساب مسافة Levenshtein (عدد التعديلات للتحويل من نص لآخر)
  static int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> previousRow = List<int>.generate(t.length + 1, (i) => i);

    for (int i = 0; i < s.length; i++) {
      List<int> currentRow = [i + 1];
      for (int j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        currentRow.add([
          currentRow[j] + 1, // إدخال
          previousRow[j + 1] + 1, // حذف
          previousRow[j] + cost, // استبدال
        ].reduce((a, b) => a < b ? a : b));
      }
      previousRow = currentRow;
    }
    return previousRow.last;
  }

  /// توسيع البحث ليشمل المرادفات
  static List<String> _expandQuery(String query) {
    final queries = <String>{query};

    // إضافة المرادفات
    _jobSynonyms.forEach((key, synonyms) {
      final normalizedKey = _normalizeArabic(key);
      final normalizedSynonyms = synonyms.map(_normalizeArabic).toList();

      // Expand ONLY if the query exactly matches the key or one of the synonyms
      if (query == normalizedKey || normalizedSynonyms.contains(query)) {
        queries.add(normalizedKey);
        queries.addAll(normalizedSynonyms);
      }
    });

    return queries.toList();
  }

  static bool _containsMatch(String text, String query) {
    if (text == query) return true;

    final queryWords =
        query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return false;

    final textWords =
        text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // البحث عن جملة كاملة متصلة إذا كانت أكثر من كلمة
    if (queryWords.length > 1 && text.contains(query)) return true;

    // يجب أن تتطابق كل كلمة في جملة البحث مع كلمة في النص
    for (final qWord in queryWords) {
      bool foundMatchForThisQueryWord = false;
      for (final tWord in textWords) {
        if (_isCloseMatch(tWord, qWord)) {
          foundMatchForThisQueryWord = true;
          break;
        }
      }
      if (!foundMatchForThisQueryWord) {
        return false;
      }
    }

    return true;
  }

  static bool _isCloseMatch(String word, String query) {
    if (word == query) return true;

    // معالجة السوابق الشائعة في اللغة العربية
    String cleanWord = word;
    if (cleanWord.startsWith('ال')) {
      cleanWord = cleanWord.substring(2);
    } else if (cleanWord.startsWith('بال')) {
      cleanWord = cleanWord.substring(3);
    } else if (cleanWord.startsWith('كال')) {
      cleanWord = cleanWord.substring(3);
    } else if (cleanWord.startsWith('فال')) {
      cleanWord = cleanWord.substring(3);
    } else if (cleanWord.startsWith('ول')) {
      cleanWord = cleanWord.substring(2);
    } else if (cleanWord.startsWith('ب') && cleanWord.length > 3) {
      cleanWord = cleanWord.substring(1);
    }

    String cleanQuery = query;
    if (cleanQuery.startsWith('ال')) {
      cleanQuery = cleanQuery.substring(2);
    }

    if (cleanWord == cleanQuery) return true;

    // السماح بالتطابق إذا كان الفرق في الطول صغيراً جداً (مثل الجمع: سباك -> سباكين)
    // نطبق هذا فقط إذا كانت الكلمة الأصلية مكونة من 3 أحرف على الأقل
    if (cleanWord.isNotEmpty &&
        cleanQuery.isNotEmpty &&
        cleanQuery.length >= 3) {
      if (cleanWord.contains(cleanQuery) &&
          cleanWord.length - cleanQuery.length <= 2) return true;
      if (cleanQuery.contains(cleanWord) &&
          cleanQuery.length - cleanWord.length <= 2) return true;
    }

    return false;
  }

  /// تطبيع النص العربي (إزالة التشكيل والهمزات) للوصول العام
  static String normalizeArabic(String text) {
    return _normalizeArabic(text);
  }

  /// تطبيع النص العربي (إزالة التشكيل والهمزات)
  static String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // إزالة التشكيل
  }

  /// Calculate relevance score for search results ranking
  static int calculateRelevanceScore(
    String query, {
    required String name,
    required List<String> skills,
    String? jobTitle,
    String? bio,
  }) {
    int score = 0;
    final normalizedQuery = _normalizeArabic(query.toLowerCase());

    // Exact matches get highest score
    if (_normalizeArabic(name.toLowerCase()).contains(normalizedQuery))
      score += 100;
    if (jobTitle != null &&
        _normalizeArabic(jobTitle.toLowerCase()).contains(normalizedQuery))
      score += 90;

    // Skill matches
    for (final skill in skills) {
      if (_normalizeArabic(skill.toLowerCase()).contains(normalizedQuery)) {
        score += 80;
        break; // Only count once for skills
      }
    }

    // Bio matches
    if (bio != null &&
        _normalizeArabic(bio.toLowerCase()).contains(normalizedQuery))
      score += 50;

    // Fuzzy matches get lower score
    if (score == 0) {
      if (_isFuzzyMatch(normalizedQuery, _normalizeArabic(name.toLowerCase())))
        score += 30;
      if (jobTitle != null &&
          _isFuzzyMatch(
              normalizedQuery, _normalizeArabic(jobTitle.toLowerCase())))
        score += 25;
      for (final skill in skills) {
        if (_isFuzzyMatch(
            normalizedQuery, _normalizeArabic(skill.toLowerCase()))) {
          score += 20;
          break;
        }
      }
    }

    return score;
  }
}

/// نتيجة تقسيم الاستعلام
class _ParsedQuery {
  final String skillPart;
  final String locationPart;

  _ParsedQuery({required this.skillPart, required this.locationPart});
}
