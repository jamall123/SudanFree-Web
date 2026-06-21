import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/request_model.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/linkable_text.dart';
import 'request_offers_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class RequestDetailsScreen extends StatefulWidget {
  final RequestModel request;

  const RequestDetailsScreen({super.key, required this.request});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final _offerController = TextEditingController();
  final _priceController = TextEditingController();
  final _timeController = TextEditingController();
  bool _isApplying = false;
  late final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _offerController.dispose();
    _priceController.dispose();
    _timeController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _showOfferSheet(
      BuildContext context, UserModel currentUser, String locale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(locale == 'ar' ? 'قدم عرضك' : 'Submit your offer',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _offerController,
                      hint: locale == 'ar'
                          ? 'مرحباً، أنا مستعد لتنفيذ طلبك. لدي خبرة سابقة...'
                          : 'Hello, I am ready to fulfill your request. I have previous experience...',
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _priceController,
                      hint: locale == 'ar'
                          ? 'السعر التقديري (اختياري)'
                          : 'Estimated Price (Optional)',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.attach_money,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: _timeController,
                      hint: locale == 'ar'
                          ? 'المدة التقديرية لإنجاز العمل (اختياري)'
                          : 'Estimated time to complete (Optional)',
                      prefixIcon: Icons.timer_outlined,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isApplying
                            ? null
                            : () async {
                                if (_offerController.text.trim().isEmpty) {
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(context);
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                        content: Text(locale == 'ar'
                                            ? 'الرجاء كتابة تفاصيل العرض'
                                            : 'Please write offer details'),
                                        backgroundColor: AppColors.warning),
                                  );
                                  return;
                                }

                                setSheetState(() => _isApplying = true);
                                final nav = Navigator.of(context);
                                final messenger = ScaffoldMessenger.of(context);

                                try {
                                  // Server-side bid limit check
                                  final existingCount = await FirestoreService()
                                      .getUserOfferCount(
                                          widget.request.id, currentUser.id);
                                  if (existingCount >= 2) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(locale == 'ar'
                                            ? 'لقد قدمت الحد الأقصى من العروض (عرضين) على هذا الطلب'
                                            : 'You have reached the maximum offers (2)'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                    nav.pop();
                                    return;
                                  }

                                  final offer = OfferModel(
                                    id: '',
                                    requestId: widget.request.id,
                                    providerId: currentUser.id,
                                    providerName: currentUser.name,
                                    providerRole: currentUser.role.name,
                                    providerImageUrl:
                                        currentUser.profileImageUrl,
                                    providerJobTitle: currentUser.jobTitle ??
                                        currentUser.getShopCategoryName(locale),
                                    title: locale == 'ar'
                                        ? 'عرض جديد'
                                        : 'New Offer',
                                    text: _offerController.text.trim(),
                                    price: _priceController.text.isNotEmpty
                                        ? double.tryParse(_priceController.text)
                                        : null,
                                    estimatedTime:
                                        _timeController.text.trim().isNotEmpty
                                            ? _timeController.text.trim()
                                            : null,
                                    createdAt: DateTime.now(),
                                  );

                                  await FirestoreService().createOffer(offer);

                                  if (mounted) {
                                    _offerController.clear();
                                    _priceController.clear();
                                    _timeController.clear();
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(locale == 'ar'
                                              ? 'تم تقديم العرض بنجاح!'
                                              : 'Offer submitted successfully!'),
                                          backgroundColor: AppColors.success),
                                    );
                                    nav.pop();
                                    // Refresh the page to update bid count
                                    setState(() {});
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: Text(e.toString()),
                                          backgroundColor: Colors.red),
                                    );
                                  }
                                } finally {
                                  if (mounted)
                                    setSheetState(() => _isApplying = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isApplying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(
                                locale == 'ar' ? 'إرسال العرض' : 'Submit Offer',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final locale = context.watch<LocaleProvider>().locale.languageCode;

    final isMyRequest = currentUser?.id == widget.request.clientId;
    final canApply = currentUser != null &&
        currentUser.role != UserRole.client &&
        !isMyRequest;

    return Scaffold(
      appBar: AppBar(
        title: Text(locale == 'ar' ? 'تفاصيل الطلب' : 'Request Details'),
        actions: [
          if (isMyRequest)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      // ═══ الأزرار في الأسفل بدلاً من الزر العائم ═══
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: canApply
              ? FutureBuilder<int>(
                  future: FirestoreService()
                      .getUserOfferCount(widget.request.id, currentUser.id),
                  builder: (context, snapshot) {
                    final existingOffers = snapshot.data ?? 0;
                    if (existingOffers >= 2) {
                      return ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: Text(
                          locale == 'ar'
                              ? 'لقد تجاوزت الحد المسموح للتقديم'
                              : 'Apply limit reached',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    }
                    return ElevatedButton.icon(
                      onPressed: () =>
                          _showOfferSheet(context, currentUser, locale),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.local_offer_outlined),
                      label: Text(
                        locale == 'ar' ? 'قدم على هذا الطلب' : 'Submit Offer',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    );
                  },
                )
              : (isMyRequest
                  ? ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RequestOffersScreen(request: widget.request),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: Text(
                        locale == 'ar' ? 'عرض المقدمين' : 'View Offers',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    )
                  : const SizedBox.shrink()),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Request Header
            Container(
              padding: const EdgeInsets.all(20),
              color: Theme.of(context).cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: widget.request.clientImageUrl != null
                            ? CachedNetworkImageProvider(
                                widget.request.clientImageUrl!)
                            : null,
                        child: widget.request.clientImageUrl == null
                            ? const Icon(Icons.person, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.request.clientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            Text(
                              _formatTimeAgo(widget.request.createdAt, locale),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (widget.request.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.request.category!,
                            style: const TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinkableText(
                    text: widget.request.text,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),

                  // ═══ Voice Recording Player ═══
                  if (widget.request.audioUrl != null) ...[
                    const SizedBox(height: 16),
                    RequestAudioPlayer(
                      audioUrl: widget.request.audioUrl!,
                      duration: widget.request.audioDuration ?? 0,
                    ),
                  ],

                  // ═══ معرض الصور بالتمرير مع نقاط المؤشر ═══
                  if (widget.request.allImageUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SizedBox(
                            height: 220,
                            child: PageView.builder(
                              controller: _imagePageController,
                              itemCount: widget.request.allImageUrls.length,
                              onPageChanged: (i) =>
                                  setState(() => _currentImageIndex = i),
                              itemBuilder: (context, index) {
                                final url = widget.request.allImageUrls[index];
                                return GestureDetector(
                                  onTap: () => _showFullImage(context,
                                      widget.request.allImageUrls, index),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (_, __) => Container(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      child: const Center(
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.grey, size: 48),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          // نقاط المؤشر في الأسفل
                          if (widget.request.allImageUrls.length > 1)
                            Positioned(
                              bottom: 10,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.request.allImageUrls.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    width: _currentImageIndex == i ? 20 : 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _currentImageIndex == i
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // شارة عدد الصور في الزاوية
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.photo_library_outlined,
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentImageIndex + 1}/${widget.request.allImageUrls.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // زر التكبير
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () => _showFullImage(
                                  context,
                                  widget.request.allImageUrls,
                                  _currentImageIndex),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.fullscreen,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.request.state != null ||
                      widget.request.locality != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.request.locality ?? ''} ${widget.request.state != null ? '- ${widget.request.state}' : ''}',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Delete Reminder for Client
            if (isMyRequest)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locale == 'ar'
                            ? 'يرجى حذف الطلب من أيقونة السلة بالاعلى عند اكتفاءك وتلقي الخدمة المطلوبة.'
                            : 'Please delete the request from the trash icon above when you are satisfied and received the service.',
                        style: TextStyle(
                            color: AppColors.warning.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // تحذير الحد الأقصى من العروض (يظهر فقط للمزود إذا وصل للحد)
            if (canApply)
              FutureBuilder<int>(
                future: FirestoreService()
                    .getUserOfferCount(widget.request.id, currentUser.id),
                builder: (context, snapshot) {
                  final existingOffers = snapshot.data ?? 0;
                  if (existingOffers >= 2) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(
                            locale == 'ar'
                                ? 'لقد قدمت الحد الأقصى من العروض (عرضين) على هذا الطلب'
                                : 'You have reached the maximum offers (2) on this request',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          )),
                        ],
                      ),
                    );
                  }
                  if (existingOffers == 1) {
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                            locale == 'ar'
                                ? 'هذا آخر عرض يمكنك تقديمه على هذا الطلب'
                                : 'This is your last offer on this request',
                            style: TextStyle(
                                color: Colors.amber.shade800,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          )),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

            // List of Offers or Summary Banner
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                locale == 'ar'
                    ? 'العروض المقدمة (${widget.request.offersCount})'
                    : 'Submitted Offers (${widget.request.offersCount})',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),

            if (!isMyRequest)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.privacy_tip_outlined,
                        color: AppColors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        locale == 'ar'
                            ? 'هذا الطلب عليه ${widget.request.offersCount} عروض حالياً. كن من أوائل المتقدمين!'
                            : 'This request currently has ${widget.request.offersCount} offers. Be among the first to apply!',
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(locale == 'ar' ? 'حذف الطلب' : 'Delete Request'),
        content: Text(locale == 'ar'
            ? 'هل أنت متأكد أنك تريد حذف هذا الطلب؟ لا يمكن التراجع عن هذا الإجراء.'
            : 'Are you sure you want to delete this request? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(locale == 'ar' ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(locale == 'ar' ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await FirestoreService().deleteRequest(widget.request.id);
        if (!mounted) return;
        nav.pop(); // Go back to List
        messenger.showSnackBar(
          SnackBar(
              content: Text(
                  locale == 'ar' ? 'تم الحذف بنجاح' : 'Deleted Successfully'),
              backgroundColor: AppColors.success),
        );
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime date, String locale) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return locale == 'ar' ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return locale == 'ar'
          ? 'منذ ${diff.inHours} ساعة'
          : '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return locale == 'ar'
          ? 'منذ ${diff.inMinutes} دقيقة'
          : '${diff.inMinutes}m ago';
    } else {
      return locale == 'ar' ? 'الآن' : 'Just now';
    }
  }

  void _showFullImage(
      BuildContext context, List<String> imageUrls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(
            imageUrls: imageUrls, initialIndex: initialIndex),
      ),
    );
  }
}

// ═══ Full Screen Image Viewer ═══
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenImageViewer(
      {required this.imageUrls, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.imageUrls.length > 1
            ? Text('${_currentIndex + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(fontSize: 16))
            : null,
        elevation: 0,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.grey, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══ Request Audio Player ═══
class RequestAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;

  const RequestAudioPlayer(
      {super.key, required this.audioUrl, required this.duration});

  @override
  State<RequestAudioPlayer> createState() => _RequestAudioPlayerState();
}

class _RequestAudioPlayerState extends State<RequestAudioPlayer> {
  final _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.duration);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted && dur > Duration.zero) setState(() => _duration = dur);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted)
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isPlaying) {
                await _audioPlayer.pause();
              } else {
                await _audioPlayer.play(UrlSource(widget.audioUrl));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor:
                        AppColors.primary.withValues(alpha: 0.3),
                    thumbColor: AppColors.primary,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1,
                    value: _position.inMilliseconds
                        .toDouble()
                        .clamp(0, _duration.inMilliseconds.toDouble()),
                    onChanged: (val) async {
                      await _audioPlayer
                          .seek(Duration(milliseconds: val.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                      Text(_formatDuration(_duration),
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
