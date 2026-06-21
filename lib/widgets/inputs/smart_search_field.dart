import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/smart_search_service.dart';
import '../common/glass_container.dart';

/// حقل بحث ذكي مع اقتراحات تلقائية بأسلوب جوجل
/// يعمل مع صفحات الحرفيين والمتاجر والمجتمع
class SmartSearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onSearch;
  final TextEditingController? controller;
  final SearchContext searchContext;
  final Color? accentColor;

  const SmartSearchField({
    super.key,
    required this.hintText,
    required this.onSearch,
    this.controller,
    this.searchContext = SearchContext.freelancers,
    this.accentColor,
  });

  @override
  State<SmartSearchField> createState() => _SmartSearchFieldState();
}

enum SearchContext { freelancers, shops, community }

class _SmartSearchFieldState extends State<SmartSearchField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<String> _suggestions = [];
  Timer? _debounce;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _updateSuggestions(_controller.text);
    } else {
      // Delay removal to allow tap on suggestion (increased to 800ms per user request)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _updateSuggestions(text);
    });
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      _suggestions = _getQuickSuggestions();
    } else {
      _suggestions = _getSuggestionsForContext(query);
    }

    if (_hasFocus && _suggestions.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  List<String> _getSuggestionsForContext(String query) {
    final results = <String>{};

    // 1. اقتراحات المهن والمرادفات من SmartSearchService
    results.addAll(SmartSearchService.getPredefinedSuggestions(query));

    // 2. اقتراحات حسب السياق
    final contextKeywords = _getContextKeywords();
    final normalizedQuery = _normalizeArabic(query.toLowerCase().trim());

    for (final keyword in contextKeywords) {
      if (_normalizeArabic(keyword.toLowerCase()).contains(normalizedQuery)) {
        results.add(keyword);
      }
    }

    // 3. اقتراحات مركبة (مهنة + موقع)
    // الآن نطبقها على جميع السياقات بما فيها المجتمع
    _addCompositeSuggestions(query, results);

    return results.take(8).toList();
  }

  void _addCompositeSuggestions(String query, Set<String> results) {
    // إذا كتب المستخدم مهنة فقط، اقترح إضافة "في" + مواقع شائعة
    final topLocations = [
      'الخرطوم',
      'أم درمان',
      'بحري',
      'ود مدني',
      'بورتسودان',
      'كسلا',
      'القضارف'
    ];

    // ابحث عن مطابقة في المهن
    final jobMatches = SmartSearchService.getPredefinedSuggestions(query);
    if (jobMatches.isNotEmpty && !query.contains('في')) {
      final bestMatch = jobMatches.first;
      for (final location in topLocations.take(3)) {
        results.add('$bestMatch في $location');
      }
    }
  }

  List<String> _getContextKeywords() {
    switch (widget.searchContext) {
      case SearchContext.freelancers:
        return const [
          // حرف وخدمات
          'كهربائي', 'سباك', 'نجار', 'حداد', 'دهان', 'بناء', 'تكييف',
          'ميكانيكي', 'مبرمج', 'مصمم', 'مدرس', 'معلم', 'سائق', 'نقل',
          'طباخ', 'خياط', 'تنظيف', 'صيانة', 'تصوير', 'مونتاج',
          'مدرس خصوصي', 'محامي', 'مترجم', 'طاولجي', 'فران',
          // مواقع
          'الخرطوم', 'أم درمان', 'بحري', 'ود مدني', 'بورتسودان',
          'كسلا', 'القضارف', 'نيالا', 'الفاشر', 'الأبيض',
        ];
      case SearchContext.shops:
        return const [
          // أنواع المتاجر
          'إلكترونيات', 'ملابس', 'أثاث', 'مواد غذائية', 'مطعم',
          'سوبرماركت', 'صيدلية', 'تجميل', 'قطع غيار', 'مواد بناء',
          'مجوهرات', 'جوالات', 'موبايلات', 'مكتبة', 'رياضة',
          'ألعاب أطفال', 'أدوات منزلية', 'معرض', 'محل',
          // مواقع
          'الخرطوم', 'أم درمان', 'بحري', 'ود مدني', 'بورتسودان',
          'كسلا', 'القضارف', 'نيالا', 'الفاشر',
        ];
      case SearchContext.community:
        return const [
          // مواضيع المجتمع
          'عمل', 'وظيفة', 'فرصة', 'خدمة', 'عرض', 'طلب',
          'تدريب', 'دورة', 'نصيحة', 'سؤال', 'مساعدة',
          'مشروع', 'تعاون', 'شراكة',
          // حرف وخدمات
          'كهربائي', 'سباك', 'نجار', 'حداد', 'دهان', 'بناء', 'تكييف',
          'ميكانيكي', 'مبرمج', 'مصمم', 'مدرس', 'معلم', 'سائق', 'نقل',
          'طباخ', 'خياط', 'تنظيف', 'صيانة', 'تصوير', 'مونتاج',
          // مواقع
          'الخرطوم', 'أم درمان', 'بحري', 'ود مدني', 'بورتسودان',
          'كسلا', 'القضارف', 'نيالا', 'الفاشر', 'الأبيض',
        ];
    }
  }

  List<String> _getQuickSuggestions() {
    switch (widget.searchContext) {
      case SearchContext.freelancers:
        return const [
          'كهربائي',
          'سباك',
          'نجار',
          'مبرمج',
          'مصمم',
          'ميكانيكي',
          'مدرس',
          'دهان'
        ];
      case SearchContext.shops:
        return const [
          'إلكترونيات',
          'ملابس',
          'مطعم',
          'صيدلية',
          'سوبرماركت',
          'أثاث',
          'جوالات',
          'مجوهرات'
        ];
      case SearchContext.community:
        return const ['عمل', 'فرصة', 'خدمة', 'تدريب', 'مشروع', 'سؤال'];
    }
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '');
  }

  IconData _getSuggestionIcon(String suggestion) {
    final lower = suggestion.toLowerCase();
    // حرف وخدمات
    if (lower.contains('سباك') || lower.contains('سباكه'))
      return Icons.plumbing;
    if (lower.contains('كهرب')) return Icons.electrical_services;
    if (lower.contains('نجار')) return Icons.carpenter;
    if (lower.contains('دهان') || lower.contains('نقاش'))
      return Icons.format_paint;
    if (lower.contains('ميكانيك')) return Icons.build;
    if (lower.contains('مصمم') || lower.contains('تصميم'))
      return Icons.design_services;
    if (lower.contains('مبرمج') || lower.contains('مطور')) return Icons.code;
    if (lower.contains('مدرس') ||
        lower.contains('معلم') ||
        lower.contains('تدريس')) return Icons.school;
    if (lower.contains('سائق') ||
        lower.contains('نقل') ||
        lower.contains('توصيل')) return Icons.local_shipping;
    if (lower.contains('طباخ') || lower.contains('شيف'))
      return Icons.restaurant;
    if (lower.contains('تنظيف') || lower.contains('نظافه'))
      return Icons.cleaning_services;
    if (lower.contains('تكييف') || lower.contains('مكيف')) return Icons.ac_unit;
    if (lower.contains('تصوير')) return Icons.camera_alt;
    if (lower.contains('خياط')) return Icons.checkroom;
    if (lower.contains('محامي')) return Icons.gavel;
    if (lower.contains('صيانه') || lower.contains('صيانة'))
      return Icons.build_circle;
    // متاجر
    if (lower.contains('إلكتروني') || lower.contains('الكتروني'))
      return Icons.devices;
    if (lower.contains('ملابس')) return Icons.checkroom;
    if (lower.contains('مطعم')) return Icons.restaurant;
    if (lower.contains('صيدلي')) return Icons.local_pharmacy;
    if (lower.contains('سوبرماركت')) return Icons.store;
    if (lower.contains('أثاث') || lower.contains('اثاث')) return Icons.chair;
    if (lower.contains('جوال') || lower.contains('موبايل'))
      return Icons.phone_android;
    if (lower.contains('مجوهرات')) return Icons.diamond;
    if (lower.contains('متجر') ||
        lower.contains('معرض') ||
        lower.contains('محل')) return Icons.storefront;
    // مواقع
    if (lower.contains('في ') ||
        lower.contains('الخرطوم') ||
        lower.contains('أم درمان') ||
        lower.contains('بحري') ||
        lower.contains('ود مدني') ||
        lower.contains('بورتسودان')) {
      return Icons.location_on;
    }
    // مجتمع
    if (lower.contains('عمل') || lower.contains('وظيف')) return Icons.work;
    if (lower.contains('فرص')) return Icons.trending_up;
    if (lower.contains('تدريب') || lower.contains('دوره')) return Icons.school;
    if (lower.contains('مشروع')) return Icons.business;
    return Icons.search;
  }

  final String _tapRegionGroupId = UniqueKey().toString();

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    final accent = widget.accentColor ?? AppColors.primary;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: TapRegion(
            groupId: _tapRegionGroupId,
            onTapOutside: (_) {
              _focusNode.unfocus();
              _removeOverlay();
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Colors.black26,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: _suggestions.length * 52.0 + 16,
                ),
                child: GlassContainer(
                  color: Theme.of(context).cardColor,
                  opacity: Theme.of(context).brightness == Brightness.dark
                      ? 0.3
                      : 0.6,
                  blur: 15,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.15),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        final isComposite = suggestion.contains('في ');

                        return InkWell(
                          onTap: () {
                            _controller.text = suggestion;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: suggestion.length),
                            );
                            widget.onSearch(suggestion);
                            _removeOverlay();
                            _focusNode.unfocus();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getSuggestionIcon(suggestion),
                                    size: 18,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    suggestion,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isComposite
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.color,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.north_west,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                  onPressed: () {
                                    _controller.text = suggestion;
                                    _controller.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(offset: suggestion.length),
                                    );
                                    _focusNode.requestFocus();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? AppColors.primary;

    return TapRegion(
      groupId: _tapRegionGroupId,
      onTapOutside: (_) {
        _focusNode.unfocus();
        _removeOverlay();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: GlassContainer(
          height: 40,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hasFocus ? accent : AppColors.border.withValues(alpha: 0.3),
            width: _hasFocus ? 1.5 : 1.0,
          ),
          color: Theme.of(context).cardColor,
          opacity: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.6,
          blur: 15,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onChanged: _onTextChanged,
            onSubmitted: (val) {
              _removeOverlay();
              widget.onSearch(val);
            },
            textAlignVertical: TextAlignVertical.center,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(Icons.search,
                  size: 20,
                  color: _hasFocus ? accent : AppColors.textSecondary),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _controller.clear();
                        _removeOverlay();
                        widget.onSearch('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
