import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';

/// Premium mention overlay widget — يظهر عند كتابة @ لعرض قائمة الزملاء
class MentionOverlay extends StatelessWidget {
  final List<UserModel> partners;
  final VoidCallback? onSelectAll;
  final ValueChanged<UserModel> onSelectUser;
  final String locale;

  const MentionOverlay({
    super.key,
    required this.partners,
    this.onSelectAll,
    required this.onSelectUser,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    if (partners.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.03),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.alternate_email,
                        color: AppColors.primary, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    locale == 'ar' ? 'إشارة لزميل' : 'Mention a colleague',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${partners.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // "Mention All" button
            if (partners.length > 1 && onSelectAll != null)
              InkWell(
                onTap: onSelectAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.sudanGold.withValues(alpha: 0.08),
                        AppColors.sudanGold.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border(
                      top:
                          BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                      bottom:
                          BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.sudanGold,
                              AppColors.sudanGold.withValues(alpha: 0.7)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.groups_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locale == 'ar' ? '@الجميع' : '@Everyone',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              locale == 'ar'
                                  ? 'إشارة لجميع الزملاء (${partners.length})'
                                  : 'Mention all colleagues (${partners.length})',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: Colors.grey[400], size: 20),
                    ],
                  ),
                ),
              ),

            // Partners list
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: partners.length,
                itemBuilder: (context, index) {
                  final user = partners[index];
                  return _MentionTile(
                    user: user,
                    locale: locale,
                    onTap: () => onSelectUser(user),
                    isLast: index == partners.length - 1,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person_add_alt_1_rounded,
                color: Colors.grey[400], size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            locale == 'ar' ? 'لا يوجد زملاء' : 'No colleagues yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            locale == 'ar'
                ? 'أضف زملاء من ملفاتهم الشخصية لتتمكن من الإشارة إليهم'
                : 'Add colleagues from their profiles to mention them',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Individual mention tile with premium design
class _MentionTile extends StatelessWidget {
  final UserModel user;
  final String locale;
  final VoidCallback onTap;
  final bool isLast;

  const _MentionTile({
    required this.user,
    required this.locale,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom:
                      BorderSide(color: Colors.grey.withValues(alpha: 0.08)),
                ),
        ),
        child: Row(
          children: [
            // Avatar with gradient border
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.5),
                    AppColors.sudanGold.withValues(alpha: 0.5)
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: user.profileImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: user.profileImageUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 36,
                          height: 36,
                          color: Colors.grey[200],
                          child: const Icon(Icons.person,
                              size: 18, color: Colors.grey),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 36,
                          height: 36,
                          color: Colors.grey[200],
                          child: const Icon(Icons.person,
                              size: 18, color: Colors.grey),
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Center(
                          child: Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Name & role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.getRoleDisplayName(locale),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Subtle @ icon
            Icon(Icons.alternate_email, size: 16, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
