import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/portfolio_project_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../core/utils/job_titles_utils.dart';
class CreatePortfolioProjectScreen extends StatefulWidget {
  final String? squadId;
  final List<String>? defaultCollaboratorIds;
  final PortfolioProjectModel? existingProject;

  const CreatePortfolioProjectScreen(
      {super.key, this.squadId, this.defaultCollaboratorIds, this.existingProject});

  @override
  State<CreatePortfolioProjectScreen> createState() =>
      _CreatePortfolioProjectScreenState();
}

class _CreatePortfolioProjectScreenState
    extends State<CreatePortfolioProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _purposeController = TextEditingController();
  final _linkController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;
  String? _selectedType;
  final List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];
  bool _isLoading = false;
  String _loadingStatus = '';
  final List<Map<String, dynamic>> _selectedCollaborators = [];

  static const int _maxImages = 5;

  // Category options with icons and colors
  static const List<Map<String, dynamic>> _categories = [
    {
      'key': 'design',
      'ar': 'تصميم',
      'en': 'Design',
      'icon': Icons.palette,
      'color': Color(0xFF6c5ce7)
    },
    {
      'key': 'programming',
      'ar': 'برمجة',
      'en': 'Programming',
      'icon': Icons.code,
      'color': Color(0xFF0984e3)
    },
    {
      'key': 'maintenance',
      'ar': 'صيانة',
      'en': 'Maintenance',
      'icon': Icons.build,
      'color': Color(0xFFe17055)
    },
    {
      'key': 'construction',
      'ar': 'بناء وتشييد',
      'en': 'Construction',
      'icon': Icons.construction,
      'color': Color(0xFF00b894)
    },
    {
      'key': 'electrical',
      'ar': 'كهرباء',
      'en': 'Electrical',
      'icon': Icons.electric_bolt,
      'color': Color(0xFFfdcb6e)
    },
    {
      'key': 'plumbing',
      'ar': 'سباكة',
      'en': 'Plumbing',
      'icon': Icons.plumbing,
      'color': Color(0xFF00cec9)
    },
    {
      'key': 'painting',
      'ar': 'دهان وطلاء',
      'en': 'Painting',
      'icon': Icons.format_paint,
      'color': Color(0xFFa29bfe)
    },
    {
      'key': 'carpentry',
      'ar': 'نجارة',
      'en': 'Carpentry',
      'icon': Icons.carpenter,
      'color': Color(0xFF636e72)
    },
    {
      'key': 'other',
      'ar': 'أخرى',
      'en': 'Other',
      'icon': Icons.category,
      'color': Color(0xFF74b9ff)
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDefaultCollaborators();
    if (widget.existingProject != null) {
      final ep = widget.existingProject!;
      _titleController.text = ep.title;
      _descriptionController.text = ep.description;
      _purposeController.text = ep.purpose ?? '';
      _linkController.text = ep.externalLink ?? '';
      _selectedCategory = ep.category;
      _selectedStatus = ep.status;
      _selectedType = ep.projectType;
      _existingImageUrls = List.from(ep.imageUrls);
      if (ep.collaborators != null) {
        _selectedCollaborators.addAll(List<Map<String, dynamic>>.from(ep.collaborators!));
      }
    }
  }

  Future<void> _loadDefaultCollaborators() async {
    if (widget.defaultCollaboratorIds != null &&
        widget.defaultCollaboratorIds!.isNotEmpty) {
      try {
        final members = await FirestoreService()
            .getUsersByIds(widget.defaultCollaboratorIds!);
        if (mounted) {
          setState(() {
            for (var m in members) {
              _selectedCollaborators.add(
                  {'id': m.id, 'name': m.name, 'imageUrl': m.profileImageUrl});
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading default collaborators: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _purposeController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  String _l(BuildContext ctx) => ctx.read<LocaleProvider>().locale.languageCode;
  bool _isAr(BuildContext ctx) => ctx.read<LocaleProvider>().isArabic;

  Future<void> _pickImages() async {
    final remaining = _maxImages - (_selectedImages.length + _existingImageUrls.length);
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isAr(context) ? 'لقد وصلت للحد الأقصى للصور' : 'Maximum images reached'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.primary)),
              title: Text(_isAr(context) ? 'المعرض' : 'Gallery'),
              subtitle: Text(_isAr(context) ? 'اختر عدة صور' : 'Pick multiple',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Colors.orange)),
              title: Text(_isAr(context) ? 'الكاميرا' : 'Camera'),
              subtitle: Text(_isAr(context) ? 'التقط صورة' : 'Take a photo',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ]),
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final image = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 70, maxWidth: 1200);
      if (image != null && mounted)
        setState(() => _selectedImages.add(File(image.path)));
    } else {
      final images =
          await picker.pickMultiImage(imageQuality: 70, maxWidth: 1200);
      if (images.isNotEmpty && mounted) {
        setState(() => _selectedImages
            .addAll(images.take(remaining).map((img) => File(img.path))));
      }
    }
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(_isAr(context)
            ? 'يرجى إضافة صورة واحدة على الأقل'
            : 'Please add at least one image'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    setState(() {
      _isLoading = true;
      _loadingStatus =
          _isAr(context) ? 'جاري رفع الصور...' : 'Uploading images...';
    });

    try {
      final List<String> uploadedUrls = List.from(_existingImageUrls);
      for (int i = 0; i < _selectedImages.length; i++) {
        setState(() => _loadingStatus = _isAr(context)
            ? 'رفع صورة ${i + 1} من ${_selectedImages.length}...'
            : 'Uploading image ${i + 1} of ${_selectedImages.length}...');
        final url = await StorageService().uploadPortfolioImage(
          user.id,
          _selectedImages[i],
        );
        uploadedUrls.add(url);
      }

      setState(() => _loadingStatus =
          _isAr(context) ? 'جاري حفظ المشروع...' : 'Saving project...');

      final project = PortfolioProjectModel(
        id: widget.existingProject?.id ?? '',
        userId: widget.existingProject?.userId ?? widget.squadId ?? user.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        status: _selectedStatus,
        projectType: _selectedType,
        purpose: _purposeController.text.trim().isNotEmpty
            ? _purposeController.text.trim()
            : null,
        externalLink: _linkController.text.trim().isNotEmpty
            ? _linkController.text.trim()
            : null,
        collaborators:
            _selectedCollaborators.isNotEmpty ? _selectedCollaborators : null,
        imageUrls: uploadedUrls,
        createdAt: widget.existingProject?.createdAt ?? DateTime.now(),
      );

      if (widget.existingProject != null) {
        await FirestoreService().updatePortfolioProject(
            project.userId, project.id, project.toFirestore());
      } else {
        await FirestoreService().addPortfolioProject(project);
      }

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(_isAr(context)
              ? 'تمت إضافة المشروع بنجاح! ✅'
              : 'Project added successfully! ✅'),
          backgroundColor: AppColors.success,
        ));
        if (context.mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('${_isAr(context) ? "خطأ" : "Error"}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadingStatus = '';
        });
    }
  }

  void _showCollaboratorsPicker() {
    final user = context.read<AuthProvider>().user;
    if (user == null || user.partnerIds.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(_isAr(context)
            ? 'ليس لديك زملاء مضافين حالياً'
            : 'You have no colleagues added currently'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final partnersFuture = FirestoreService().getUsersByIds(user.partnerIds);

    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Text(
                      _isAr(context)
                          ? 'اختر الشركاء في المشروع'
                          : 'Select Project Partners',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: partnersFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const Center(
                              child: CircularProgressIndicator());
                        if (!snapshot.hasData || snapshot.data!.isEmpty)
                          return const Center(child: Text('لا يوجد شركاء'));

                        final partners = snapshot.data!;
                        return ListView.builder(
                          itemCount: partners.length,
                          itemBuilder: (context, index) {
                            final p = partners[index];
                            final isSelected = _selectedCollaborators
                                .any((c) => c['id'] == p.id);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: p.profileImageUrl != null
                                    ? CachedNetworkImageProvider(
                                        p.profileImageUrl!)
                                    : null,
                                child: p.profileImageUrl == null
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                              title: Text(p.name),
                              subtitle: Text(p.jobTitle != null ? JobTitlesUtils.getLocalizedTitle(p.jobTitle!, _l(context)) : ''),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (val) {
                                  if (val == true) {
                                    _selectedCollaborators.add({
                                      'id': p.id,
                                      'name': p.name,
                                      'imageUrl': p.profileImageUrl
                                    });
                                    setSheetState(() {});
                                  } else {
                                    _selectedCollaborators
                                        .removeWhere((c) => c['id'] == p.id);
                                    setSheetState(() {});
                                  }
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50)),
                    child: Text(_isAr(context) ? 'تأكيد' : 'Confirm'),
                  )
                ],
              ),
            );
          });
        }).then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isAr(context);
    final locale = _l(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'إضافة مشروع منجز' : 'Add Completed Project'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Loading overlay
          if (_isLoading)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Row(children: [
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(_loadingStatus,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600))),
              ]),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Title ───
                    _buildSectionLabel(
                        isArabic ? 'عنوان المشروع' : 'Project Title',
                        Icons.title),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        hint: isArabic
                            ? 'مثال: تركيب نظام كهرباء لمنزل'
                            : 'e.g. Home electrical system installation',
                        icon: Icons.edit,
                        isDark: isDark,
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // ─── Category Chips ───
                    _buildSectionLabel(
                        isArabic ? 'تصنيف المشروع' : 'Project Category',
                        Icons.category),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat['key'];
                        final Color color = cat['color'];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory =
                              isSelected ? null : cat['key']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? color
                                  : color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isSelected
                                      ? color
                                      : color.withValues(alpha: 0.3)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(cat['icon'] as IconData,
                                  size: 16,
                                  color: isSelected ? Colors.white : color),
                              const SizedBox(width: 6),
                              Text(
                                locale == 'ar' ? cat['ar'] : cat['en'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : color,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    const SizedBox(height: 20),

                    // ─── Status & Type ───
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel(
                                  isArabic ? 'حالة المشروع' : 'Project Status',
                                  Icons.task_alt),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: _selectedStatus,
                                decoration: _inputDecoration(
                                    hint: isArabic
                                        ? 'اختر الحالة'
                                        : 'Select Status',
                                    isDark: isDark),
                                items: [
                                  DropdownMenuItem(
                                      value: 'completed',
                                      child: Text(
                                          isArabic ? 'مكتمل' : 'Completed')),
                                  DropdownMenuItem(
                                      value: 'ongoing',
                                      child: Text(isArabic
                                          ? 'قيد التنفيذ'
                                          : 'Ongoing')),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedStatus = val),
                                validator: (v) => v == null
                                    ? (isArabic ? 'مطلوب' : 'Required')
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionLabel(
                                  isArabic ? 'نوع المشروع' : 'Project Type',
                                  Icons.work_outline),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: _selectedType,
                                decoration: _inputDecoration(
                                    hint:
                                        isArabic ? 'اختر النوع' : 'Select Type',
                                    isDark: isDark),
                                items: [
                                  DropdownMenuItem(
                                      value: 'personal',
                                      child:
                                          Text(isArabic ? 'شخصي' : 'Personal')),
                                  DropdownMenuItem(
                                      value: 'client',
                                      child:
                                          Text(isArabic ? 'لعميل' : 'Client')),
                                  DropdownMenuItem(
                                      value: 'startup',
                                      child: Text(
                                          isArabic ? 'شركة ناشئة' : 'Startup')),
                                  DropdownMenuItem(
                                      value: 'other',
                                      child: Text(isArabic ? 'أخرى' : 'Other')),
                                ],
                                onChanged: (val) =>
                                    setState(() => _selectedType = val),
                                validator: (v) => v == null
                                    ? (isArabic ? 'مطلوب' : 'Required')
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── Description ───
                    _buildSectionLabel(
                        isArabic ? 'وصف المشروع' : 'Project Description',
                        Icons.description),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _inputDecoration(
                        hint: isArabic
                            ? 'اكتب تفاصيل عن المشروع وما قمت بإنجازه...'
                            : 'Write details about your project...',
                        isDark: isDark,
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? (isArabic ? 'مطلوب' : 'Required')
                          : null,
                    ),

                    const SizedBox(height: 20),

                    // ─── Purpose ───
                    _buildSectionLabel(
                        isArabic
                            ? 'أهداف المشروع / ما يهدف إليه'
                            : 'Project Purpose',
                        Icons.flag_outlined),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _purposeController,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        hint: isArabic
                            ? 'ما المشكلة التي يحلها هذا المشروع؟'
                            : 'What problem does this project solve?',
                        isDark: isDark,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ─── External Link ───
                    _buildSectionLabel(
                        isArabic
                            ? 'رابط المشروع (اختياري)'
                            : 'Project Link (Optional)',
                        Icons.link),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _linkController,
                      decoration: _inputDecoration(
                        hint: isArabic ? 'https://...' : 'https://...',
                        icon: Icons.link,
                        isDark: isDark,
                      ),
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 20),

                    // ─── Collaborators ───
                    _buildSectionLabel(
                        isArabic
                            ? 'شركاء أو منفذي المشروع'
                            : 'Project Partners',
                        Icons.group),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _showCollaboratorsPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person_add_alt_1,
                                color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedCollaborators.isEmpty
                                    ? (isArabic
                                        ? 'أضف زملاء شاركوا في التنفيذ'
                                        : 'Add colleagues who worked on this')
                                    : (isArabic
                                        ? 'تم اختيار ${_selectedCollaborators.length} شركاء'
                                        : '${_selectedCollaborators.length} partners selected'),
                                style: TextStyle(
                                    color: _selectedCollaborators.isEmpty
                                        ? Colors.grey
                                        : AppColors.textPrimary,
                                    fontSize: 14),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios,
                                size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedCollaborators.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedCollaborators
                              .map((c) => Chip(
                                    avatar: CircleAvatar(
                                      backgroundImage: c['imageUrl'] != null
                                          ? CachedNetworkImageProvider(
                                              c['imageUrl'])
                                          : null,
                                      child: c['imageUrl'] == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                    label: Text(c['name']),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedCollaborators.remove(c);
                                      });
                                    },
                                  ))
                              .toList(),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ─── Images Section ───
                    Row(
                      children: [
                        _buildSectionLabel(
                            isArabic ? 'صور المشروع' : 'Project Images',
                            Icons.photo_library),
                        const Spacer(),
                        Text('${_existingImageUrls.length + _selectedImages.length}/$_maxImages',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: (_existingImageUrls.length + _selectedImages.length) >= _maxImages
                                    ? Colors.orange
                                    : AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_existingImageUrls.isNotEmpty || _selectedImages.isNotEmpty)
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _existingImageUrls.length + _selectedImages.length +
                              ((_existingImageUrls.length + _selectedImages.length) < _maxImages ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _existingImageUrls.length + _selectedImages.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 100,
                                  height: 110,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3),
                                        style: BorderStyle.solid),
                                  ),
                                  child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate,
                                            color: AppColors.primary, size: 28),
                                        SizedBox(height: 4),
                                        Text('+',
                                            style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold)),
                                      ]),
                                ),
                              );
                            }
                            
                            final isExisting = i < _existingImageUrls.length;
                            final imageUrl = isExisting ? _existingImageUrls[i] : null;
                            final localFile = isExisting ? null : _selectedImages[i - _existingImageUrls.length];

                            return Stack(children: [
                              Container(
                                width: 110,
                                height: 110,
                                margin: const EdgeInsets.only(left: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: isExisting
                                    ? CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                                    : Image.file(localFile!, fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isExisting) {
                                        _existingImageUrls.removeAt(i);
                                      } else {
                                        _selectedImages.removeAt(i - _existingImageUrls.length);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.85),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ]);
                          },
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          height: 130,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.25),
                                style: BorderStyle.solid),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.cloud_upload_outlined,
                                      size: 32, color: AppColors.primary),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                    isArabic
                                        ? 'اضغط لإضافة صور المشروع'
                                        : 'Tap to add project images',
                                    style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                    isArabic
                                        ? 'حد أقصى $_maxImages صور'
                                        : 'Maximum $_maxImages images',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 12)),
                              ]),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // ─── Submit Button ───
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _submitProject,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [AppColors.primary, Color(0xFF5f3dc4)]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_isLoading ? null : Icons.rocket_launch,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  isArabic ? 'نشر المشروع' : 'Publish Project',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  InputDecoration _inputDecoration(
      {required String hint, IconData? icon, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon:
          icon != null ? Icon(icon, color: AppColors.primary, size: 20) : null,
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.grey.withValues(alpha: 0.06),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
