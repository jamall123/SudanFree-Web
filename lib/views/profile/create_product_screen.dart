import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_error_handler.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/post_model.dart';
import '../../services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/smart_guide_service.dart';

class CreateProductScreen extends StatefulWidget {
  final PostModel? product; // for editing
  const CreateProductScreen({super.key, this.product});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _customSizeController = TextEditingController();
  final _customColorController = TextEditingController();

  final List<File> _selectedImages = [];
  final List<String> _selectedSizes = [];
  final List<String> _selectedColors = [];
  String? _condition; // 'new' | 'used'
  String? _ageGroup; // 'baby' | 'child' | 'youth' | 'adult' | 'elderly'
  bool _hasShipping = false;
  bool _isPosting = false;

  static const _predefinedSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL'];
  static const _predefinedColors = [
    'أبيض',
    'أسود',
    'رمادي',
    'أحمر',
    'أزرق',
    'أخضر',
    'أصفر',
    'بني',
    'وردي',
    'برتقالي',
    'بنفسجي',
    'ذهبي',
    'فضي'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.caption ?? '';
      _priceController.text = p.price?.toString() ?? '';
      _quantityController.text = p.quantity?.toString() ?? '';
      _condition = p.productCondition;
      _ageGroup = p.productAgeGroup;
      _hasShipping = p.hasShipping;
      _selectedSizes.addAll(p.productSizes);
      _selectedColors.addAll(p.productColors);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SmartGuideService.showMicroTip(
        context,
        messageAr: 'الصورة الجذابة والوصف الدقيق هما مفتاحك لمبيعات أسرع 📸',
        messageEn:
            'Great photos and clear descriptions are the key to faster sales 📸',
        tipId: 'product_create_tip',
        icon: Icons.add_photo_alternate_rounded,
      );
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _customSizeController.dispose();
    _customColorController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 7 - _selectedImages.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final images =
        await picker.pickMultiImage(imageQuality: 80, maxWidth: 1200);
    if (images.isNotEmpty && mounted) {
      setState(() => _selectedImages
          .addAll(images.take(remaining).map((e) => File(e.path))));
    }
  }

  Future<void> _handleSubmit() async {
    final isAr = context.read<LocaleProvider>().isArabic;
    if (_nameController.text.trim().isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(
            isAr ? 'يرجى كتابة اسم المنتج' : 'Please enter a product name'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_selectedImages.isEmpty &&
        (widget.product?.allImageUrls.isEmpty ?? true)) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(
            isAr ? 'يرجى إضافة صورة للمنتج' : 'Please add a product image'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_isPosting) return;
    setState(() => _isPosting = true);

    final caption =
        '${_nameController.text.trim()}\n\n${_descController.text.trim()}'
            .trim();

    try {
      final user = context.read<AuthProvider>().user!;
      final provider = context.read<PostsProvider>();
      bool success;

      if (widget.product != null) {
        success = await provider.updatePost(
          postId: widget.product!.id,
          imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
          caption: caption,
          showInCommunity: false,
          showInProfile: true,
          price: double.tryParse(_priceController.text.trim()),
          productSizes: _selectedSizes,
          productCondition: _condition,
          productAgeGroup: _ageGroup,
          productColors: _selectedColors,
          quantity: int.tryParse(_quantityController.text.trim()),
          hasShipping: _hasShipping,
        );
      } else {
        success = await provider.createPost(
          userId: user.id,
          userName: user.name,
          userRole: user.role.name,
          userJobTitle: user.getShopCategoryName(isAr ? 'ar' : 'en'),
          userImageUrl: user.profileImageUrl,
          imageFiles: _selectedImages.isNotEmpty ? _selectedImages : null,
          caption: caption,
          showInCommunity: false,
          showInProfile: true,
          price: double.tryParse(_priceController.text.trim()),
          productSizes: _selectedSizes,
          productCondition: _condition,
          productAgeGroup: _ageGroup,
          productColors: _selectedColors,
          quantity: int.tryParse(_quantityController.text.trim()),
          hasShipping: _hasShipping,
        );
      }

      if (!mounted) return;
      setState(() => _isPosting = false);
      if (success) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(isAr
              ? 'تم نشر المنتج بنجاح ✅'
              : 'Product published successfully ✅'),
          backgroundColor: Colors.green,
        ));
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() => _isPosting = false);
        AppErrorHandler.show(context, e, stack,
            logContext: 'CreateProductScreen');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<LocaleProvider>().isArabic;
    final theme = Theme.of(context);
    final isEditing = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr
            ? (isEditing ? 'تعديل المنتج' : 'إضافة منتج')
            : (isEditing ? 'Edit Product' : 'Add Product')),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _handleSubmit,
            child: _isPosting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    isAr
                        ? (isEditing ? 'حفظ' : 'نشر')
                        : (isEditing ? 'Save' : 'Publish'),
                    style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Images ──────────────────────────────────────────────
            _sectionTitle(isAr ? 'صور المنتج *' : 'Product Images *',
                Icons.photo_library_outlined),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add button
                  if (_selectedImages.length < 7)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                              style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: AppColors.secondary, size: 32),
                            SizedBox(height: 4),
                            Text('أضف صورة',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.secondary)),
                          ],
                        ),
                      ),
                    ),
                  // Existing images (edit mode)
                  if (isEditing)
                    ...widget.product!.allImageUrls.map((url) => Container(
                          width: 100,
                          height: 100,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.hardEdge,
                          child: CachedNetworkImage(
                            imageUrl: CloudinaryService.getOptimizedUrl(url,
                                width: 200),
                            fit: BoxFit.cover,
                          ),
                        )),
                  // New images
                  ..._selectedImages.asMap().entries.map((entry) => Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12)),
                            clipBehavior: Clip.hardEdge,
                            child: kIsWeb ? Image.network(entry.value.path, fit: BoxFit.cover) : Image.file(entry.value, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 2,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _selectedImages.removeAt(entry.key)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Product Name ─────────────────────────────────────────
            _sectionTitle(
                isAr ? 'اسم المنتج *' : 'Product Name *', Icons.label_outline),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: _inputDeco(
                  isAr ? 'مثال: حذاء رياضي نايك' : 'e.g. Nike Sports Shoe',
                  Icons.label_outline),
            ),

            const SizedBox(height: 16),

            // ── Description ──────────────────────────────────────────
            _sectionTitle(
                isAr ? 'الوصف' : 'Description', Icons.description_outlined),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: _inputDeco(
                  isAr
                      ? 'اكتب وصفاً تفصيلياً للمنتج...'
                      : 'Write a detailed description...',
                  Icons.description_outlined),
            ),

            const SizedBox(height: 16),

            // ── Price & Quantity ─────────────────────────────────────
            Row(
              children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(isAr ? 'السعر (SDG)' : 'Price (SDG)',
                        Icons.sell_outlined),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco(
                          isAr ? '0.00' : '0.00', Icons.sell_outlined),
                    ),
                  ],
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle(isAr ? 'الكمية المتاحة' : 'Quantity',
                        Icons.inventory_2_outlined),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: _inputDeco(isAr ? 'مثال: 10' : 'e.g. 10',
                          Icons.inventory_2_outlined),
                    ),
                  ],
                )),
              ],
            ),

            const SizedBox(height: 20),

            // ── Condition ────────────────────────────────────────────
            _sectionTitle(
                isAr ? 'حالة المنتج' : 'Product Condition', Icons.star_outline),
            const SizedBox(height: 8),
            Row(
              children: [
                _conditionChip(isAr ? 'جديد' : 'New', 'new',
                    Icons.fiber_new_rounded, Colors.green),
                const SizedBox(width: 12),
                _conditionChip(isAr ? 'مستعمل' : 'Used', 'used',
                    Icons.recycling_rounded, Colors.orange),
              ],
            ),

            const SizedBox(height: 20),

            // ── Age Group ────────────────────────────────────────────
            _sectionTitle(isAr ? 'الفئة العمرية المستهدفة' : 'Target Age Group',
                Icons.people_outline),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ageChip('baby', isAr ? '👶 رضيع' : '👶 Baby'),
                _ageChip('child', isAr ? '🧒 طفل' : '🧒 Child'),
                _ageChip('youth', isAr ? '👦 شباب' : '👦 Youth'),
                _ageChip('adult', isAr ? '👨 بالغ' : '👨 Adult'),
                _ageChip('elderly', isAr ? '👴 كبار' : '👴 Elderly'),
                _ageChip('all', isAr ? '👨‍👩‍👧 الكل' : '👨‍👩‍👧 All'),
              ],
            ),

            const SizedBox(height: 20),

            // ── Sizes ────────────────────────────────────────────────
            _sectionTitle(isAr ? 'المقاسات المتوفرة' : 'Available Sizes',
                Icons.straighten_outlined),
            const SizedBox(height: 4),
            Text(
                isAr
                    ? 'اختر من القائمة أو أضف مقاساً مخصصاً'
                    : 'Select from list or add custom size',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._predefinedSizes.map((s) {
                  final sel = _selectedSizes.contains(s);
                  return FilterChip(
                    label: Text(s),
                    selected: sel,
                    onSelected: (v) => setState(() =>
                        v ? _selectedSizes.add(s) : _selectedSizes.remove(s)),
                    selectedColor: AppColors.secondary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.secondary,
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _customSizeController,
                decoration: _inputDeco(
                    isAr ? 'مقاس مخصص...' : 'Custom size...', Icons.add),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final s = _customSizeController.text.trim();
                  if (s.isNotEmpty && !_selectedSizes.contains(s)) {
                    setState(() {
                      _selectedSizes.add(s);
                      _customSizeController.clear();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(isAr ? 'إضافة' : 'Add'),
              ),
            ]),
            if (_selectedSizes.any((s) => !_predefinedSizes.contains(s))) ...[
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  children: _selectedSizes
                      .where((s) => !_predefinedSizes.contains(s))
                      .map((s) => Chip(
                          label: Text(s),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () =>
                              setState(() => _selectedSizes.remove(s)),
                          backgroundColor:
                              AppColors.secondary.withValues(alpha: 0.1)))
                      .toList()),
            ],

            const SizedBox(height: 20),

            // ── Colors ───────────────────────────────────────────────
            _sectionTitle(
                isAr
                    ? 'الألوان / التنوعات المتوفرة'
                    : 'Available Colors / Variants',
                Icons.palette_outlined),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _predefinedColors.map((c) {
                final sel = _selectedColors.contains(c);
                return FilterChip(
                  label: Text(c, style: const TextStyle(fontSize: 12)),
                  selected: sel,
                  onSelected: (v) => setState(() =>
                      v ? _selectedColors.add(c) : _selectedColors.remove(c)),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _customColorController,
                decoration: _inputDeco(
                    isAr ? 'لون أو نوع مخصص...' : 'Custom color/variant...',
                    Icons.add),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final c = _customColorController.text.trim();
                  if (c.isNotEmpty && !_selectedColors.contains(c)) {
                    setState(() {
                      _selectedColors.add(c);
                      _customColorController.clear();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(isAr ? 'إضافة' : 'Add'),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Shipping ─────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _hasShipping
                    ? Colors.teal.withValues(alpha: 0.08)
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _hasShipping
                        ? Colors.teal.withValues(alpha: 0.4)
                        : AppColors.border.withValues(alpha: 0.3)),
              ),
              child: SwitchListTile(
                value: _hasShipping,
                onChanged: (v) => setState(() => _hasShipping = v),
                title: Text(isAr ? '🚚 يوجد توصيل' : '🚚 Shipping Available',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    isAr
                        ? 'تفعيل إذا كنت تقدم خدمة التوصيل'
                        : 'Enable if you offer delivery service',
                    style: const TextStyle(fontSize: 12)),
                activeThumbColor: Colors.teal,
              ),
            ),

            const SizedBox(height: 32),

            // ── Submit ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isPosting ? null : _handleSubmit,
                icon: _isPosting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  isAr
                      ? (isEditing ? 'حفظ التغييرات' : 'نشر المنتج')
                      : (isEditing ? 'Save Changes' : 'Publish Product'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Row(children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ]);

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.secondary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.secondary, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Widget _conditionChip(
      String label, String value, IconData icon, Color color) {
    final selected = _condition == value;
    return GestureDetector(
      onTap: () => setState(() => _condition = selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : AppColors.border.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? color : null)),
        ]),
      ),
    );
  }

  Widget _ageChip(String value, String label) {
    final selected = _ageGroup == value;
    return GestureDetector(
      onTap: () => setState(() => _ageGroup = selected ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? AppColors.secondary
                  : AppColors.border.withValues(alpha: 0.3),
              width: selected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppColors.secondary : null,
                fontSize: 13)),
      ),
    );
  }
}
