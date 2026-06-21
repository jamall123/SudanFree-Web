import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/squad_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/sudan_locations.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CreateSquadScreen extends StatefulWidget {
  final SquadModel? squadToEdit;

  const CreateSquadScreen({super.key, this.squadToEdit});

  @override
  State<CreateSquadScreen> createState() => _CreateSquadScreenState();
}

class _CreateSquadScreenState extends State<CreateSquadScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _skillsController;
  SquadCategory? _selectedCategory;
  String? _selectedState;
  String? _selectedLocality;
  bool _isLoading = false;
  File? _imageFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.squadToEdit?.name ?? '');
    _descController =
        TextEditingController(text: widget.squadToEdit?.description ?? '');
    _skillsController = TextEditingController(
        text: widget.squadToEdit?.combinedSkills.join('، ') ?? '');
    _selectedCategory = widget.squadToEdit?.category;
    _selectedState = widget.squadToEdit?.state;
    _selectedLocality = widget.squadToEdit?.locality;
    _currentImageUrl = widget.squadToEdit?.squadImageUrl;

    // Ensure locality is valid for the state
    if (_selectedState != null && _selectedLocality != null) {
      if (!SudanLocations.getLocalities(_selectedState!)
          .contains(_selectedLocality)) {
        _selectedLocality = null;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveSquad() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LocaleProvider>().isArabic
              ? 'الرجاء إكمال جميع الحقول واختيار الفئة'
              : 'Please fill all fields and select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().user;
      if (user == null) throw Exception('User not authenticated');

      final squadId = widget.squadToEdit?.id ?? const Uuid().v4();

      String? uploadedImageUrl = _currentImageUrl;
      if (_imageFile != null) {
        final url = await StorageService()
            .uploadImage(_imageFile!, folder: 'squads/$squadId');
        if (url != null) uploadedImageUrl = url;
      }

      final rawSkills = _skillsController.text.split(RegExp(r'[,،]'));
      final parsedSkills =
          rawSkills.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      final squad = SquadModel(
        id: squadId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        leaderId: widget.squadToEdit?.leaderId ?? user.id,
        memberIds: widget.squadToEdit?.memberIds ?? [user.id],
        category: _selectedCategory!,
        state: _selectedState,
        locality: _selectedLocality,
        createdAt: widget.squadToEdit?.createdAt ?? DateTime.now(),
        rating: widget.squadToEdit?.rating ?? 0.0,
        completedJobs: widget.squadToEdit?.completedJobs ?? 0,
        combinedSkills: parsedSkills,
        squadImageUrl: uploadedImageUrl,
      );

      if (widget.squadToEdit != null) {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(squadId)
            .update(squad.toFirestore());
      } else {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(squadId)
            .set(squad.toFirestore());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LocaleProvider>().isArabic
                ? (widget.squadToEdit != null
                    ? 'تم تحديث المجموعة بنجاح!'
                    : 'تم إنشاء المجموعة بنجاح!')
                : (widget.squadToEdit != null
                    ? 'Squad updated successfully!'
                    : 'Squad created successfully!')),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // العودة
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LocaleProvider>().isArabic
                ? 'حدث خطأ أثناء الحفظ'
                : 'Error saving squad'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';
    final isEditing = widget.squadToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isAr ? 'تعديل المجموعة' : 'Edit Squad')
            : (isAr ? 'إنشاء مجموعة عمل' : 'Create Squad')),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (_currentImageUrl != null
                                      ? CachedNetworkImageProvider(
                                          _currentImageUrl!)
                                      : null) as ImageProvider?,
                              child: (_imageFile == null &&
                                      _currentImageUrl == null)
                                  ? const Icon(Icons.groups,
                                      size: 50, color: Colors.grey)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isAr ? 'اسم المجموعة' : 'Squad Name',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: isAr
                            ? 'مثال: فريق البناء المتكامل'
                            : 'e.g., Integrated Builders Squad',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? (isAr ? 'مطلوب' : 'Required')
                          : null,
                    ),

                    const SizedBox(height: 24),

                    Text(
                      isAr ? 'وصف المجموعة' : 'Squad Description',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        hintText: isAr
                            ? 'اشرح تخصص المجموعة وأهدافها...'
                            : 'Describe the squad specialization...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 4,
                      validator: (val) => val == null || val.isEmpty
                          ? (isAr ? 'مطلوب' : 'Required')
                          : null,
                    ),

                    const SizedBox(height: 24),

                    Text(
                      isAr ? 'فئة المجموعة' : 'Squad Category',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<SquadCategory>(
                          isExpanded: true,
                          value: _selectedCategory,
                          hint: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(isAr
                                ? 'اختر التخصص الأساسي'
                                : 'Select main specialization'),
                          ),
                          items: SquadCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(cat.getName(locale)),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategory = val),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      isAr
                          ? 'الخدمات والتخصصات (اختياري)'
                          : 'Services & Specialties (Optional)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _skillsController,
                      decoration: InputDecoration(
                        hintText: isAr
                            ? 'أدخل التخصصات مفصولة بفاصلة (،) مثال: كهرباء، سباكة'
                            : 'Enter skills separated by comma (,)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? '* إذا تركتها فارغة، سيتم عرض تخصصات أعضاء المجموعة تلقائياً.'
                          : '* If left empty, members skills will be displayed automatically.',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),

                    const SizedBox(height: 24),

                    // Location Selection
                    Text(
                      isAr
                          ? 'موقع المجموعة (اختياري)'
                          : 'Squad Location (Optional)',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedState,
                                hint: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(isAr ? 'الولاية' : 'State'),
                                ),
                                items: SudanLocations.states.map((state) {
                                  return DropdownMenuItem(
                                    value: state,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: Text(SudanLocations.getStateName(
                                          state, locale)),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedState = val;
                                    _selectedLocality = null;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedLocality,
                                hint: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(isAr ? 'المحلية' : 'Locality'),
                                ),
                                items: _selectedState == null
                                    ? []
                                    : SudanLocations.getLocalities(
                                            _selectedState!)
                                        .map((loc) {
                                        return DropdownMenuItem(
                                          value: loc,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Text(
                                                SudanLocations.getLocalityName(
                                                    loc, locale)),
                                          ),
                                        );
                                      }).toList(),
                                onChanged: _selectedState == null
                                    ? null
                                    : (val) {
                                        setState(() {
                                          _selectedLocality = val;
                                        });
                                      },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveSquad,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          isEditing
                              ? (isAr ? 'حفظ التعديلات' : 'Save Changes')
                              : (isAr ? 'إنشاء واعتماد' : 'Create Squad'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
