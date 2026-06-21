import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/request_model.dart';
import '../../models/offer_model.dart';
import '../../models/contact_log_model.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/locale_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/linkable_text.dart';

class RequestOffersScreen extends StatelessWidget {
  final RequestModel request;

  const RequestOffersScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'عروض المقدمين' : 'Submitted Offers'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<OfferModel>>(
        stream: FirestoreService().getOffers(request.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingIndicator());
          }
          final offers = snapshot.data ?? [];

          if (offers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      isAr
                          ? 'لم يتم تقديم عروض بعد'
                          : 'No offers submitted yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return _OfferCardDetailed(
                offer: offer,
                locale: locale,
                currentUserId: currentUser?.id,
                currentUserName: currentUser?.name,
              );
            },
          );
        },
      ),
    );
  }
}

class _OfferCardDetailed extends StatelessWidget {
  final OfferModel offer;
  final String locale;
  final String? currentUserId;
  final String? currentUserName;

  const _OfferCardDetailed(
      {required this.offer,
      required this.locale,
      this.currentUserId,
      this.currentUserName});

  bool get isAr => locale == 'ar';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider Info Row
          Row(
            children: [
              GestureDetector(
                onTap: () => _navigateToProfile(context, offer),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: offer.providerImageUrl != null
                      ? CachedNetworkImageProvider(offer.providerImageUrl!)
                      : null,
                  child: offer.providerImageUrl == null
                      ? const Icon(Icons.person,
                          color: AppColors.primary, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(context, offer),
                      child: Text(
                        offer.providerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (offer.providerJobTitle != null &&
                        offer.providerJobTitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        offer.providerJobTitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: offer.providerRole == 'shop'
                              ? Colors.amber.shade700
                              : AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Contact Button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _showContactSheet(context),
                  icon: const Icon(Icons.support_agent, size: 22),
                  color: AppColors.primary,
                  tooltip: isAr ? 'تواصل' : 'Contact',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Price & Time Row
          if ((offer.price != null && offer.price! > 0) ||
              (offer.estimatedTime != null && offer.estimatedTime!.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  if (offer.price != null && offer.price! > 0)
                    Expanded(
                      child: _buildInfoTag(
                        icon: Icons.attach_money,
                        label: isAr ? 'الميزانية المقترحة' : 'Proposed Budget',
                        value: '${offer.price} SDG',
                        color: Colors.green,
                      ),
                    ),
                  if ((offer.price != null && offer.price! > 0) &&
                      (offer.estimatedTime != null &&
                          offer.estimatedTime!.isNotEmpty))
                    const SizedBox(width: 12),
                  if (offer.estimatedTime != null &&
                      offer.estimatedTime!.isNotEmpty)
                    Expanded(
                      child: _buildInfoTag(
                        icon: Icons.timer_outlined,
                        label: isAr ? 'مدة الإنجاز' : 'Estimated Time',
                        value: offer.estimatedTime!,
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ),

          // Offer Text
          Text(
            isAr ? 'تفاصيل العرض:' : 'Offer Details:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: LinkableText(
              text: offer.text,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(
      {required IconData icon,
      required String label,
      required String value,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showContactSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'تواصل مع مقدم الخدمة' : 'Contact Provider',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF25D366),
                    child: Icon(Icons.chat, color: Colors.white)),
                title: Text(isAr ? 'واتساب' : 'WhatsApp'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final provider =
                        await FirestoreService().getUser(offer.providerId);
                    if (provider != null) {
                      if (currentUserId != null &&
                          currentUserId != offer.providerId) {
                        try {
                          final log = ContactLogModel(
                            id: '',
                            contacterId: currentUserId!,
                            contacterName: currentUserName ?? '',
                            freelancerId: offer.providerId,
                            freelancerName: offer.providerName,
                            contactType: 'whatsapp',
                            createdAt: DateTime.now(),
                          );
                          await FirestoreService().createContactLog(log);
                        } catch (e) {
                          debugPrint('Error creating contact log: $e');
                        }
                      }
                      _openWhatsApp(
                          provider.whatsappNumber ?? provider.phoneNumber);
                    }
                  } catch (e) {
                    debugPrint('Error getting provider contact details');
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: const Icon(Icons.call, color: Colors.white)),
                title: Text(isAr ? 'اتصال مباشر' : 'Direct Call'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final provider =
                        await FirestoreService().getUser(offer.providerId);
                    if (provider != null) {
                      final phone =
                          provider.phoneNumber ?? provider.whatsappNumber;
                      if (phone != null && phone.isNotEmpty) {
                        final uri = Uri.parse('tel:$phone');
                        try {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } catch (_) {}
                      }
                    }
                  } catch (e) {
                    debugPrint('Error calling provider');
                  }
                },
              ),
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade600,
                    child: const Icon(Icons.handshake, color: Colors.white)),
                title: Text(isAr
                    ? 'قبول والاتفاق (إنشاء اتفاق)'
                    : 'Accept & Agree (Create Agreement)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (currentUserId == null) return;

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                  );

                  final chatProvider = context.read<ChatProvider>();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);

                  try {
                    final chat = await chatProvider.getOrCreateChat(
                      currentUserId: currentUserId!,
                      currentUserName: currentUserName ?? '',
                      currentUserImageUrl: null,
                      otherUserId: offer.providerId,
                      otherUserName: offer.providerName,
                      otherUserImageUrl: offer.providerImageUrl,
                    );

                    navigator.pop(); // dismiss dialog

                    if (chat != null) {
                      navigator.push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              chat: chat, autoOpenContractDialog: true),
                        ),
                      );
                    } else {
                      final errorMsg = chatProvider.errorMessage ??
                          (isAr
                              ? 'حدث خطأ أثناء إنشاء المحادثة'
                              : 'Error creating chat');
                      messenger.showSnackBar(
                        SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red),
                      );
                    }
                  } catch (e) {
                    navigator.pop();
                    messenger.showSnackBar(
                      SnackBar(
                          content: Text(e.toString()),
                          backgroundColor: Colors.red),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWhatsApp(String? number) async {
    if (number == null || number.isEmpty) return;

    String cleaned = number.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.startsWith('0')) {
      cleaned = '249${cleaned.substring(1)}';
    } else if (!cleaned.startsWith('249') && cleaned.length == 9) {
      cleaned = '249$cleaned';
    }

    final message = Uri.encodeComponent(isAr
        ? 'مرحباً، أتواصل معك بخصوص العرض الذي قدمته على طلبي في منصة سودان فري.'
        : 'Hello, I am contacting you regarding the offer you submitted on my request in Sudan Free platform.');
    final url = 'https://wa.me/$cleaned?text=$message';
    try {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalNonBrowserApplication);
    } catch (_) {}
  }

  void _navigateToProfile(BuildContext context, OfferModel offer) async {
    final providerUser = await FirestoreService().getUser(offer.providerId);
    if (providerUser != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: providerUser.id),
        ),
      );
    }
  }
}
