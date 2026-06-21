import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/filtered_providers_screen.dart', 'r') as f:
    content = f.read()

new_content = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/job_titles_utils.dart';
import '../../services/cloudinary_service.dart';
import '../profile/profile_screen.dart';

enum FilterType { nearYou, topRated, newest, shops, categories }

class FilteredProvidersScreen extends StatefulWidget {
  final FilterType filterType;
  final String title;

  const FilteredProvidersScreen({super.key, required this.filterType, required this.title});

  @override
  State<FilteredProvidersScreen> createState() => _FilteredProvidersScreenState();
}

class _FilteredProvidersScreenState extends State<FilteredProvidersScreen> {
  late Future<List<UserModel>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchData();
  }

  Future<List<UserModel>> _fetchData() async {
    final firestore = FirebaseFirestore.instance;
    List<UserModel> results = [];
    final currentUser = context.read<AuthProvider>().user;
    
    try {
      switch (widget.filterType) {
        case FilterType.nearYou:
          if (currentUser?.state != null) {
            final query = await firestore.collection('users')
                .where('state', isEqualTo: currentUser!.state)
                .limit(100)
                .get();
            results = query.docs.map((d) => UserModel.fromMap(d.data())).where((u) => u.role != UserRole.client).toList();
          }
          break;
        case FilterType.topRated:
          final query = await firestore.collection('users')
              .orderBy('rating', descending: true)
              .limit(100)
              .get();
          results = query.docs.map((d) => UserModel.fromMap(d.data())).where((u) => u.role != UserRole.client).toList();
          // Sort accurately by totalStars locally
          results.sort((a, b) {
            final cmp = b.totalStars.compareTo(a.totalStars);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
          break;
        case FilterType.newest:
          final query = await firestore.collection('users')
              .orderBy('createdAt', descending: true)
              .limit(100)
              .get();
          results = query.docs.map((d) => UserModel.fromMap(d.data())).where((u) => u.role != UserRole.client).toList();
          break;
        case FilterType.shops:
          final query = await firestore.collection('users')
              .where('role', isEqualTo: 'shop')
              .limit(100)
              .get();
          results = query.docs.map((d) => UserModel.fromMap(d.data())).toList();
          results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case FilterType.categories:
          break;
      }
    } catch (e) {
      debugPrint("Error fetching real data: $e");
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: FutureBuilder<List<UserModel>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(locale == 'ar' ? 'حدث خطأ' : 'Error occurred'));
          }

          final displayList = snapshot.data ?? [];

          if (displayList.isEmpty) {
            return Center(
              child: Text(
                locale == 'ar' ? 'لا توجد نتائج' : 'No results found',
                style: TextStyle(color: AppColors.softGrey, fontSize: 16),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final user = displayList[index];
              final isShop = user.role == UserRole.shop;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE8ECF0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Profile image
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Container(
                          height: 110,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: isShop ? AppColors.sudanGradient : AppColors.primaryGradient,
                          ),
                          child: user.profileImageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: CloudinaryService.getOptimizedUrl(
                                    user.profileImageUrl!, width: 300, quality: 'auto'),
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  placeholder: (_, __) => Center(
                                    child: Icon(isShop ? Icons.store : Icons.person, size: 36, color: Colors.white54),
                                  ),
                                  errorWidget: (_, __, ___) => Center(
                                    child: Icon(isShop ? Icons.store : Icons.person, size: 36, color: Colors.white54),
                                  ),
                                )
                              : Center(
                                  child: Icon(isShop ? Icons.store : Icons.person, size: 36, color: Colors.white54),
                                ),
                        ),
                      ),
                      // Info
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (isShop && user.shopCategory != null)
                                Text(
                                  user.getShopCategoryName(locale),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.desertOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else if (!isShop)
                                Text(
                                  user.jobTitle?.isNotEmpty == true 
                                      ? JobTitlesUtils.getLocalizedTitle(user.jobTitle!, locale) 
                                      : (user.skills.isNotEmpty 
                                          ? user.skills.map((s) => JobTitlesUtils.getLocalizedTitle(s, locale)).join('، ') 
                                          : user.getRoleDisplayName(locale)),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.location_on, size: 12, color: AppColors.softGrey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.state ?? (locale == 'ar' ? 'غير محدد' : 'Unknown'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.softGrey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (user.bio?.isNotEmpty == true)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      user.bio!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.softGrey.withValues(alpha: 0.8),
                                        height: 1.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, size: 16, color: AppColors.sudanGold),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.rating > 0
                                        ? user.rating.toStringAsFixed(1)
                                        : (locale == 'ar' ? 'جديد' : 'New'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
"""

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/filtered_providers_screen.dart', 'w') as f:
    f.write(new_content)

