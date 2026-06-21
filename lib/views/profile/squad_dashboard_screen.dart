import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../models/squad_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/firestore_service.dart';
import '../squads/create_squad_screen.dart';
import 'create_portfolio_project_screen.dart';
import '../../core/utils/job_titles_utils.dart';

class SquadDashboardScreen extends StatefulWidget {
  final SquadModel squad;

  const SquadDashboardScreen({super.key, required this.squad});

  @override
  State<SquadDashboardScreen> createState() => _SquadDashboardScreenState();
}

class _SquadDashboardScreenState extends State<SquadDashboardScreen> {
  late SquadModel _squad;
  bool _isLoading = false;
  late Future<List<UserModel>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _squad = widget.squad;
    _membersFuture = FirestoreService().getUsersByIds(_squad.memberIds);
  }

  Future<void> _refreshSquad() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(_squad.id)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _squad = SquadModel.fromFirestore(doc);
          _membersFuture = FirestoreService().getUsersByIds(_squad.memberIds);
        });
      }
    } catch (e) {
      debugPrint('Error refreshing squad: $e');
    }
  }

  Future<void> _leaveSquad(String currentUserId) async {
    final isAr = context.read<LocaleProvider>().isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'مغادرة المجموعة' : 'Leave Squad'),
        content: Text(isAr
            ? 'هل أنت متأكد من رغبتك في المغادرة؟'
            : 'Are you sure you want to leave?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'مغادرة' : 'Leave',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(_squad.id)
            .update({
          'memberIds': FieldValue.arrayRemove([currentUserId])
        });
        if (mounted) {
          Navigator.pop(context); // Exit Dashboard
          Navigator.pop(context); // Exit Profile
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isAr ? 'حدث خطأ: $e' : 'Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _kickMember(String memberId) async {
    final isAr = context.read<LocaleProvider>().isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'طرد العضو' : 'Remove Member'),
        content: Text(isAr
            ? 'هل أنت متأكد من طرد هذا العضو من المجموعة؟'
            : 'Are you sure you want to remove this member?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'طرد' : 'Remove',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(_squad.id)
            .update({
          'memberIds': FieldValue.arrayRemove([memberId])
        });
        await _refreshSquad();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isAr ? 'حدث خطأ: $e' : 'Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _transferLeadership(String newLeaderId) async {
    final isAr = context.read<LocaleProvider>().isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تحويل القيادة' : 'Transfer Leadership'),
        content: Text(isAr
            ? 'هل أنت متأكد من رغبتك في تسليم قيادة المجموعة لهذا العضو؟ لن تتمكن من استعادتها إلا إذا قام هو بإرجاعها لك.'
            : 'Are you sure you want to transfer leadership to this member? You will lose leader privileges.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(isAr ? 'تأكيد التحويل' : 'Confirm Transfer',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(_squad.id)
            .update({'leaderId': newLeaderId});
        await _refreshSquad();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isAr ? 'حدث خطأ: $e' : 'Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _disbandSquad() async {
    final isAr = context.read<LocaleProvider>().isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تفكيك المجموعة' : 'Disband Squad'),
        content: Text(isAr
            ? 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء وسيتم حذف المجموعة نهائياً.'
            : 'Are you sure? This cannot be undone and the squad will be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(isAr ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isAr ? 'تفكيك نهائي' : 'Disband Forever',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(_squad.id)
            .delete();
        if (mounted) {
          Navigator.pop(context); // Exit Dashboard
          Navigator.pop(context); // Exit Profile
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isAr ? 'حدث خطأ: $e' : 'Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showInviteColleaguesBottomSheet() async {
    final isAr = context.read<LocaleProvider>().isArabic;
    final currentUser = context.read<AuthProvider>().user;
    if (currentUser == null) return;

    final partnerIds = currentUser.partnerIds;
    if (partnerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(isAr ? 'لا يوجد زملاء لدعوتهم' : 'No partners to invite')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              Text(isAr ? 'دعوة الزملاء للمجموعة' : 'Invite Partners to Squad',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: FutureBuilder<List<UserModel>>(
                  future: FirestoreService().getUsersByIds(partnerIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty)
                      return Center(
                          child: Text(isAr ? 'لا يوجد زملاء' : 'No partners'));

                    final partners = snapshot.data!;
                    return ListView.builder(
                      itemCount: partners.length,
                      itemBuilder: (context, index) {
                        final partner = partners[index];
                        final bool canInvite =
                            partner.role != UserRole.client &&
                                partner.role != UserRole.shop &&
                                !_squad.memberIds.contains(partner.id);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: partner.profileImageUrl != null
                                ? CachedNetworkImageProvider(
                                    partner.profileImageUrl!)
                                : null,
                            child: partner.profileImageUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(partner.name),
                          subtitle: Text(partner.jobTitle != null ? JobTitlesUtils.getLocalizedTitle(partner.jobTitle!, isAr ? 'ar' : 'en') : ''),
                          trailing: canInvite
                              ? ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _sendInvite(partner.id);
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      minimumSize: const Size(80, 36)),
                                  child: Text(isAr ? 'دعوة' : 'Invite',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                )
                              : Text(isAr ? 'غير متاح' : 'Unavailable',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendInvite(String targetUserId) async {
    final isAr = context.read<LocaleProvider>().isArabic;
    setState(() => _isLoading = true);
    try {
      final isLeaderSnap = await FirebaseFirestore.instance
          .collection('squads')
          .where('leaderId', isEqualTo: targetUserId)
          .get();
      final isMemberSnap = await FirebaseFirestore.instance
          .collection('squads')
          .where('memberIds', arrayContains: targetUserId)
          .get();
      if (isLeaderSnap.docs.isNotEmpty || isMemberSnap.docs.isNotEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isAr
                  ? 'هذا المستخدم منضم لمجموعة بالفعل.'
                  : 'User is already in a squad.'),
              backgroundColor: Colors.red));
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUserId)
          .update({
        'pendingSquadInvites': FieldValue.arrayUnion([_squad.id])
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isAr ? 'تم إرسال الدعوة بنجاح!' : 'Invite sent successfully!'),
            backgroundColor: Colors.green));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAr ? 'حدث خطأ: $e' : 'Error: $e'),
            backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<LocaleProvider>().isArabic;
    final currentUser = context.watch<AuthProvider>().user;

    if (currentUser == null) return const Scaffold();

    final isLeader = _squad.leaderId == currentUser.id;
    final isMember = _squad.memberIds.contains(currentUser.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'لوحة تحكم المجموعة' : 'Squad Dashboard'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: _squad.squadImageUrl != null
                            ? CachedNetworkImageProvider(_squad.squadImageUrl!)
                            : null,
                        child: _squad.squadImageUrl == null
                            ? const Icon(Icons.group,
                                size: 30, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_squad.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                                isLeader
                                    ? (isAr
                                        ? 'أنت قائد المجموعة'
                                        : 'You are the Leader')
                                    : (isAr
                                        ? 'أنت عضو في المجموعة'
                                        : 'You are a Member'),
                                style: TextStyle(
                                    color: isLeader
                                        ? AppColors.primary
                                        : Colors.grey[600],
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  if (isLeader) ...[
                    Text(isAr ? 'إدارة المجموعة' : 'Squad Management',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Leader Actions
                    _buildActionCard(
                      icon: Icons.edit,
                      title:
                          isAr ? 'تعديل بيانات المجموعة' : 'Edit Squad Details',
                      subtitle: isAr
                          ? 'تغيير الاسم، الوصف، أو الصورة'
                          : 'Change name, description, or image',
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        CreateSquadScreen(squadToEdit: _squad)))
                            .then((_) => _refreshSquad());
                      },
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _squad.isAvailable
                                ? Colors.green.withValues(alpha: 0.5)
                                : Colors.red.withValues(alpha: 0.5)),
                      ),
                      child: SwitchListTile(
                        title: Text(
                            isAr ? 'متاح للتعاقد' : 'Available for hire',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _squad.isAvailable
                                    ? Colors.green
                                    : Colors.red)),
                        subtitle: Text(
                          _squad.isAvailable
                              ? (isAr
                                  ? 'المجموعة متاحة لتلقي طلبات وعروض جديدة'
                                  : 'Squad is available for new requests')
                              : (isAr
                                  ? 'المجموعة مشغولة حالياً'
                                  : 'Squad is currently busy'),
                        ),
                        value: _squad.isAvailable,
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        inactiveTrackColor: Colors.red.withValues(alpha: 0.2),
                        secondary: Icon(
                            _squad.isAvailable
                                ? Icons.check_circle
                                : Icons.do_not_disturb_on,
                            color:
                                _squad.isAvailable ? Colors.green : Colors.red),
                        onChanged: (val) {
                          setState(() {
                            _squad = _squad.copyWith(isAvailable: val);
                          });
                          FirebaseFirestore.instance
                              .collection('squads')
                              .doc(_squad.id)
                              .update({
                            'isAvailable': val,
                          }).catchError((error) {
                            // Revert on error
                            if (mounted) {
                              setState(() {
                                _squad = _squad.copyWith(isAvailable: !val);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(isAr
                                          ? 'حدث خطأ'
                                          : 'An error occurred')));
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildActionCard(
                      icon: Icons.upload_file,
                      title: isAr
                          ? 'إضافة مشروع للمعرض'
                          : 'Add Project to Portfolio',
                      subtitle: isAr
                          ? 'رفع أعمال المجموعة السابقة'
                          : 'Upload previous squad works',
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CreatePortfolioProjectScreen(
                                      squadId: _squad.id,
                                      defaultCollaboratorIds: _squad.memberIds,
                                    )));
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildActionCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: isAr ? 'دعوة زملاء' : 'Invite Partners',
                      subtitle: isAr
                          ? 'دعوة زملائك للانضمام للمجموعة'
                          : 'Invite your partners to join the squad',
                      color: Colors.purple,
                      onTap: _showInviteColleaguesBottomSheet,
                    ),
                    const SizedBox(height: 32),

                    Text(
                        isAr
                            ? 'إدارة الأعضاء (${_squad.memberIds.length})'
                            : 'Manage Members (${_squad.memberIds.length})',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // Members List
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: FutureBuilder<List<UserModel>>(
                        future: _membersFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            return const Padding(
                                padding: EdgeInsets.all(20),
                                child:
                                    Center(child: CircularProgressIndicator()));
                          if (!snapshot.hasData || snapshot.data!.isEmpty)
                            return const SizedBox();

                          final members = snapshot.data!;
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: members.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final member = members[index];
                              final isThisUserLeader =
                                  member.id == _squad.leaderId;

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage:
                                      member.profileImageUrl != null
                                          ? CachedNetworkImageProvider(
                                              member.profileImageUrl!)
                                          : null,
                                  child: member.profileImageUrl == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                title: Text(member.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    isThisUserLeader
                                        ? (isAr ? 'القائد' : 'Leader')
                                        : (isAr ? 'عضو' : 'Member'),
                                    style: TextStyle(
                                        color: isThisUserLeader
                                            ? AppColors.primary
                                            : null)),
                                trailing: !isThisUserLeader
                                    ? PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'kick') {
                                            _kickMember(member.id);
                                          } else if (value == 'transfer')
                                            _transferLeadership(member.id);
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                              value: 'transfer',
                                              child: Text(isAr
                                                  ? 'تحويل القيادة'
                                                  : 'Make Leader')),
                                          PopupMenuItem(
                                              value: 'kick',
                                              child: Text(
                                                  isAr
                                                      ? 'طرد العضو'
                                                      : 'Kick Member',
                                                  style: const TextStyle(
                                                      color: Colors.red))),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),
                    _buildActionCard(
                      icon: Icons.warning_amber_rounded,
                      title: isAr ? 'تفكيك المجموعة' : 'Disband Squad',
                      subtitle: isAr
                          ? 'حذف المجموعة بشكل نهائي'
                          : 'Delete the squad permanently',
                      color: Colors.red,
                      onTap: _disbandSquad,
                    ),
                  ],

                  if (!isLeader && isMember) ...[
                    // Member View
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.1)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.info_outline,
                              size: 40, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(
                            isAr
                                ? 'هذه لوحة تحكم المجموعة. فقط قائد المجموعة يمكنه تعديل البيانات أو إدارة الأعضاء وإضافة الأعمال.'
                                : 'This is the squad dashboard. Only the leader can edit details, manage members, and add portfolio works.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  const SizedBox(height: 40),

                  // Leave Squad Button for everyone (even leader? no, leader must transfer or disband)
                  if (!isLeader && isMember)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _leaveSquad(currentUser.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          foregroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Colors.red)),
                        ),
                        icon: const Icon(Icons.exit_to_app),
                        label: Text(isAr ? 'مغادرة المجموعة' : 'Leave Squad',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildActionCard(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
