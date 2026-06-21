import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../../core/constants/app_colors.dart';
import 'create_product_screen.dart';

class ShopDashboardScreen extends StatelessWidget {
  final UserModel shop;

  const ShopDashboardScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Header Background
          Container(
            height: 250,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  top: 8, left: 16, right: 16, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BackButton(color: Colors.white),
                      Text(
                        l10n.localeName == 'ar'
                            ? 'مرحباً ${shop.name}'
                            : 'Welcome ${shop.name}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildShopInfoCard(context, isDark),
                  const SizedBox(height: 24),

                  // "Publish New Offer" Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateProductScreen())),
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      label: Text(
                        l10n.localeName == 'ar'
                            ? '+ نشر عرض جديد'
                            : '+ Publish New Offer',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    l10n.localeName == 'ar'
                        ? 'إدارة المتجر'
                        : 'Store Management',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatsGrid(l10n, isDark),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.localeName == 'ar'
                            ? 'معرض المتجر'
                            : 'Shop Gallery',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: () => _manageGallery(context),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(l10n.localeName == 'ar'
                            ? 'إدارة الصور'
                            : 'Manage Images'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGalleryPreview(context),
                  const SizedBox(height: 24),

                  Text(
                    l10n.localeName == 'ar'
                        ? 'إحصائيات المنتجات'
                        : 'Products Insights',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildProductsList(l10n, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryPreview(BuildContext context) {
    if (shop.shopImages.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
              style: BorderStyle.solid),
        ),
        child: Center(
          child: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'لا توجد صور في المعرض'
                : 'No gallery images',
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: shop.shopImages.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: CachedNetworkImageProvider(shop.shopImages[index]),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  void _manageGallery(BuildContext context) {
    // Navigate to a dedicated screen or open a bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ManageShopGalleryScreen(shop: shop)),
    );
  }

  Widget _buildShopInfoCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            backgroundImage: shop.profileImageUrl != null
                ? CachedNetworkImageProvider(shop.profileImageUrl!)
                : null,
            child: shop.profileImageUrl == null
                ? const Icon(Icons.store, size: 30, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shop.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        shop.isPremium
                            ? Icons.workspace_premium
                            : Icons.workspace_premium_outlined,
                        color: shop.isPremium
                            ? const Color(0xFFD4AF37)
                            : Colors.grey,
                        size: 28,
                      ),
                      onPressed: () {
                        if (!shop.isPremium) {
                          _showPremiumUpgradeBottomSheet(
                              context, AppLocalizations.of(context)!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                          .localeName ==
                                      'ar'
                                  ? 'أنت تستمتع بكافة الميزات الملكية 👑'
                                  : 'You are enjoying all royal features 👑')));
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  shop.getShopCategoryName(
                      AppLocalizations.of(context)!.localeName),
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(AppLocalizations l10n, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          icon: Icons.people_alt,
          color: Colors.blue,
          value: shop.followers.length.toString(),
          title: l10n.localeName == 'ar' ? 'المتابعين' : 'Followers',
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.auto_graph_rounded,
          color: Colors.teal,
          value: shop.dailyProfileViews.toString(),
          title: l10n.localeName == 'ar' ? 'الزيارات اليومية' : 'Daily Visits',
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.remove_red_eye,
          color: Colors.purple,
          value: shop.profileViews.toString(),
          title: l10n.localeName == 'ar' ? 'إجمالي الزيارات' : 'Total Visits',
          isDark: isDark,
        ),
        _buildStatCard(
          icon: Icons.star_rounded,
          color: Colors.amber,
          value: shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '--',
          title: l10n.localeName == 'ar' ? 'التقييم' : 'Rating',
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildPremiumPromotionCard(
      BuildContext context, AppLocalizations l10n, bool isDark) {
    if (shop.isPremium) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4AF37), Color(0xFFF9E596)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.star, color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.localeName == 'ar'
                        ? 'متجرك مميز! 👑'
                        : 'Premium Store! 👑',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.localeName == 'ar'
                        ? 'أنت تستمتع الآن بكافة الميزات الملكية'
                        : 'You are enjoying all royal features',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: Color(0xFFD4AF37), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.localeName == 'ar'
                      ? 'قم بترقية متجرك (Premium)'
                      : 'Upgrade to Premium Store',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.localeName == 'ar'
                ? 'احصل على الشارة الذهبية، مظهر ملكي، وظهور دائم في أعلى نتائج البحث!'
                : 'Get the gold badge, royal UI, and always rank first in search results!',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _showPremiumUpgradeBottomSheet(context, l10n);
              },
              child:
                  Text(l10n.localeName == 'ar' ? 'ترقية الآن' : 'Upgrade Now'),
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumUpgradeBottomSheet(
      BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Icon(Icons.workspace_premium,
                      color: Color(0xFFD4AF37), size: 32),
                  const SizedBox(width: 12),
                  Text(
                    l10n.localeName == 'ar'
                        ? 'الترقية للمتجر المميز'
                        : 'Upgrade to Premium',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFeatureRow(
                  Icons.check_circle,
                  l10n.localeName == 'ar'
                      ? 'شارة التوثيق الذهبية الملكية'
                      : 'Royal Golden Verification Badge'),
              const SizedBox(height: 12),
              _buildFeatureRow(
                  Icons.check_circle,
                  l10n.localeName == 'ar'
                      ? 'أولوية الظهور في نتائج البحث والتصفية'
                      : 'Priority ranking in search and filters'),
              const SizedBox(height: 12),
              _buildFeatureRow(
                  Icons.check_circle,
                  l10n.localeName == 'ar'
                      ? 'مظهر متجر مخصص وجذاب للعملاء'
                      : 'Customized and attractive store UI'),
              const SizedBox(height: 12),
              _buildFeatureRow(
                  Icons.check_circle,
                  l10n.localeName == 'ar'
                      ? 'تثبيت منتجاتك المميزة في الأعلى'
                      : 'Pin your best products at the top'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l10n.localeName == 'ar'
                            ? 'نحن نعمل على بناء هذه الميزة 🛠️'
                            : 'We are working on building this feature 🛠️')));
                  },
                  child: Text(
                    l10n.localeName == 'ar'
                        ? 'اشترك الآن بـ 5000 ج.س/شهرياً'
                        : 'Subscribe Now for 5000 SDG/month',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
      ],
    );
  }

  Widget _buildStatCard(
      {required IconData icon,
      required Color color,
      required String value,
      required String title,
      required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProductsList(AppLocalizations l10n, bool isDark) {
    return StreamBuilder<List<PostModel>>(
      stream: FirestoreService().getDashboardUserPosts(shop.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator()));
        }

        // لوحة التحكم تعرض كل المنتجات (المرئية والمخفية معاً)
        final products = snapshot.data ?? [];

        // Sort by viewsCount descending, then by date
        final sorted = List<PostModel>.from(products);
        sorted.sort((a, b) {
          if (a.viewsCount != b.viewsCount)
            return b.viewsCount.compareTo(a.viewsCount);
          return b.createdAt.compareTo(a.createdAt);
        });

        if (sorted.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                l10n.localeName == 'ar'
                    ? 'لا توجد منتجات بعد'
                    : 'No products yet.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final product = sorted[index];
            return _buildProductManagementTile(context, product, isDark, l10n);
          },
        );
      },
    );
  }

  Widget _buildProductManagementTile(BuildContext context, PostModel product,
      bool isDark, AppLocalizations l10n) {
    final isAr = l10n.localeName == 'ar';
    final imageUrl =
        product.allImageUrls.isNotEmpty ? product.allImageUrls.first : null;
    final title =
        (product.caption ?? (isAr ? 'منتج بدون وصف' : 'No description'))
            .split('\n')
            .first;
    final isHidden = !product.showInProfile;

    return Opacity(
      opacity: isHidden ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isHidden
              ? Border.all(
                  color: Colors.orange.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            // ── الصف العلوي: صورة + معلومات + شارة المشاهدات ──
            Row(
              children: [
                // صورة المنتج
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              color: Colors.grey[200], width: 90, height: 90),
                          errorWidget: (_, __, ___) => Container(
                              color: Colors.grey[200],
                              width: 90,
                              height: 90,
                              child: const Icon(Icons.broken_image)),
                        )
                      : Container(
                          width: 90,
                          height: 90,
                          color: Colors.grey[200],
                          child: const Center(
                              child: Icon(Icons.image, color: Colors.grey)),
                        ),
                ),
                const SizedBox(width: 12),
                // معلومات المنتج
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // شارة المخفي إن وجدت
                      if (isHidden)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.visibility_off,
                                  size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                isAr
                                    ? 'مخفي من المتجر والمفضلة'
                                    : 'Hidden from store & favorites',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      if (product.price != null)
                        Text(
                          '${product.price} SDG',
                          style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                    ],
                  ),
                ),
                // شارة المشاهدات
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.remove_red_eye_rounded,
                          color: Colors.purple, size: 18),
                      const SizedBox(height: 4),
                      Text(
                        '${product.viewsCount}',
                        style: const TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── شريط أزرار التحكم ──
            Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.grey[800] : Colors.grey[50]),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // زر إخفاء / إظهار
                  Expanded(
                    child: _DashboardActionButton(
                      icon: isHidden ? Icons.visibility : Icons.visibility_off,
                      label: isHidden
                          ? (isAr ? 'إظهار' : 'Show')
                          : (isAr ? 'إخفاء' : 'Hide'),
                      color: isHidden ? AppColors.success : Colors.orange,
                      onTap: () async {
                        await FirestoreService().updatePost(product.id,
                            {'showInProfile': !product.showInProfile});
                      },
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  // زر التعديل
                  Expanded(
                    child: _DashboardActionButton(
                      icon: Icons.edit_outlined,
                      label: isAr ? 'تعديل' : 'Edit',
                      color: AppColors.primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CreateProductScreen(product: product)),
                      ),
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 36,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  // زر الحذف
                  Expanded(
                    child: _DashboardActionButton(
                      icon: Icons.delete_outline,
                      label: isAr ? 'حذف' : 'Delete',
                      color: Colors.redAccent,
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(isAr ? 'حذف المنتج' : 'Delete Product'),
                            content: Text(isAr
                                ? 'هل أنت متأكد من حذف هذا المنتج؟'
                                : 'Are you sure?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(isAr ? 'تراجع' : 'Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(isAr ? 'حذف' : 'Delete',
                                      style:
                                          const TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirestoreService().deletePost(product.id);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// زر التحكم في لوحة إدارة المنتجات
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashboardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageShopGalleryScreen extends StatefulWidget {
  final UserModel shop;
  const _ManageShopGalleryScreen({required this.shop});

  @override
  State<_ManageShopGalleryScreen> createState() =>
      _ManageShopGalleryScreenState();
}

class _ManageShopGalleryScreenState extends State<_ManageShopGalleryScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _uploadImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    setState(() => _isLoading = true);
    try {
      final url = await CloudinaryService()
          .uploadImage(File(image.path), folder: 'shop_galleries');
      if (url != null) {
        final newImages = List<String>.from(widget.shop.shopImages)..add(url);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.shop.id)
            .update({
          'shopImages': newImages,
        });
        setState(() {
          widget.shop.shopImages.add(url);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Image uploaded successfully'),
              backgroundColor: Colors.green));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to upload image'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteImage(String url, int index) async {
    setState(() => _isLoading = true);
    try {
      final newImages = List<String>.from(widget.shop.shopImages)
        ..removeAt(index);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.shop.id)
          .update({
        'shopImages': newImages,
      });
      setState(() {
        widget.shop.shopImages.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image deleted successfully'),
            backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to delete image'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isAr = l10n.localeName == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إدارة معرض المتجر' : 'Manage Shop Gallery'),
      ),
      body: Stack(
        children: [
          if (widget.shop.shopImages.isEmpty)
            Center(
              child: Text(
                isAr
                    ? 'المعرض فارغ. أضف بعض الصور.'
                    : 'Gallery is empty. Add some images.',
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          else
            GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.shop.shopImages.length,
              itemBuilder: (context, index) {
                final url = widget.shop.shopImages[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _deleteImage(url, index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          if (_isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _uploadImage,
        icon: const Icon(Icons.add_photo_alternate),
        label: Text(isAr ? 'إضافة صورة' : 'Add Image'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
