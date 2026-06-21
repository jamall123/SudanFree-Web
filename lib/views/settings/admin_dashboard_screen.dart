import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:universal_io/io.dart';

import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_model.dart';
import '../../models/ad_model.dart';
import '../../widgets/common/loading_widget.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/sudan_locations.dart';
import '../../providers/auth_provider.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _usersCount = 0;
  int _verifiedCount = 0;
  int _postsCount = 0;
  int _jobsCount = 0;
  int _adsCount = 0;
  final int _notificationsSent = 0;
  Map<String, int> _rolesDistribution = {};
  Map<String, int> _statesDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = FirebaseFirestore.instance;
      final usersSnap = await db.collection('users').get();
      final postsSnap = await db.collection('posts').count().get();
      final jobsSnap = await db.collection('jobs').count().get();
      final adsSnap = await db
          .collection('ads')
          .where('isActive', isEqualTo: true)
          .count()
          .get();

      // Calculate distributions
      int verified = 0;
      Map<String, int> roles = {};
      Map<String, int> states = {};

      for (var doc in usersSnap.docs) {
        final data = doc.data();
        if (data['isVerified'] == true) verified++;

        final role = data['role'] ?? 'client';
        roles[role] = (roles[role] ?? 0) + 1;

        final state = data['state'] ?? 'غير محدد';
        states[state] = (states[state] ?? 0) + 1;
      }

      // Sort states
      var sortedStates = states.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      Map<String, int> topStates = Map.fromEntries(sortedStates.take(5));

      if (mounted) {
        setState(() {
          _usersCount = usersSnap.docs.length;
          _verifiedCount = verified;
          _postsCount = postsSnap.count ?? 0;
          _jobsCount = jobsSnap.count ?? 0;
          _adsCount = adsSnap.count ?? 0;
          _rolesDistribution = roles;
          _statesDistribution = topStates;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;

    if (!authProvider.isAuthenticated || currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    if (currentUser.role != UserRole.admin) {
      return Scaffold(
        appBar:
            AppBar(title: const Text('غير مصرح'), backgroundColor: Colors.red),
        body: Center(child: Text('هذه الصفحة مخصصة للمشرفين فقط')),
      );
    }

    return DefaultTabController(
      length: 8,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة تحكم المشرف',
              style: TextStyle(fontWeight: FontWeight.bold)),
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'الإحصائيات', icon: Icon(Icons.analytics)),
              Tab(text: 'المستخدمون', icon: Icon(Icons.people)),
              Tab(text: 'التنبيهات', icon: Icon(Icons.notifications_active)),
              Tab(text: 'الإعلانات', icon: Icon(Icons.campaign)),
              Tab(text: 'طلبات التوثيق', icon: Icon(Icons.verified_user)),
              Tab(text: 'العقود', icon: Icon(Icons.handshake)),
              Tab(text: 'طلبات الحذف', icon: Icon(Icons.delete_sweep)),
              Tab(text: 'إعدادات التطبيق', icon: Icon(Icons.settings)),
            ],
          ),
        ),
        body: Container(
          color: Colors.grey[50],
          child: TabBarView(
            children: [
              _buildStatistics(),
              _buildUsersManager(),
              _buildNotificationsManager(),
              _buildAdsManager(),
              _buildVerificationQueue(),
              _buildContractsLog(),
              _buildDeletionQueue(),
              _buildAppSettings(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. الإحصائيات (Statistics)
  // ==========================================
  Widget _buildStatistics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نظرة عامة على النظام',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard('إجمالي المستخدمين', _usersCount.toString(),
                  Icons.people, Colors.blue),
              _buildStatCard('الموثقين', _verifiedCount.toString(),
                  Icons.verified, Colors.green),
              _buildStatCard('المنشورات', _postsCount.toString(),
                  Icons.post_add, Colors.orange),
              _buildStatCard('المشاريع والطلبات', _jobsCount.toString(),
                  Icons.work, Colors.purple),
              _buildStatCard('الإعلانات النشطة', _adsCount.toString(),
                  Icons.campaign, Colors.teal),
            ],
          ),
          const SizedBox(height: 24),
          const Text('توزيع المستخدمين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildListTileStat('حرفيين وفنيين',
                      _rolesDistribution['freelancer'] ?? 0, Icons.engineering),
                  _buildListTileStat('تقنيين ومبرمجين',
                      _rolesDistribution['techService'] ?? 0, Icons.computer),
                  _buildListTileStat(
                      'خدمات خاصة',
                      _rolesDistribution['privateService'] ?? 0,
                      Icons.design_services),
                  _buildListTileStat('متاجر', _rolesDistribution['shop'] ?? 0,
                      Icons.storefront),
                  _buildListTileStat(
                      'عملاء', _rolesDistribution['client'] ?? 0, Icons.person),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('الولايات الأكثر نشاطاً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: _statesDistribution.entries
                    .map((e) =>
                        _buildListTileStat(e.key, e.value, Icons.location_on))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildListTileStat(String title, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(count.toString(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ==========================================
  // 2. المستخدمون (Users Management)
  // ==========================================
  String _userSearchQuery = '';
  String _userRoleFilter = 'all';

  Widget _buildUsersManager() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو الهاتف...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  onChanged: (v) =>
                      setState(() => _userSearchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _userRoleFilter,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('الكل')),
                    DropdownMenuItem(value: 'freelancer', child: Text('حرفي')),
                    DropdownMenuItem(value: 'techService', child: Text('تقني')),
                    DropdownMenuItem(value: 'shop', child: Text('متجر')),
                    DropdownMenuItem(value: 'client', child: Text('عميل')),
                  ],
                  onChanged: (v) => setState(() => _userRoleFilter = v!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .orderBy('createdAt', descending: true)
                .limit(100) // Limit to 100 for performance
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const LoadingIndicator();

              var users = snapshot.data?.docs
                      .map((d) => UserModel.fromFirestore(d))
                      .toList() ??
                  [];

              // Apply local filters
              users = users.where((u) {
                final matchRole =
                    _userRoleFilter == 'all' || u.role.name == _userRoleFilter;
                final matchSearch = _userSearchQuery.isEmpty ||
                    u.name.toLowerCase().contains(_userSearchQuery) ||
                    (u.phoneNumber != null &&
                        u.phoneNumber!.contains(_userSearchQuery));
                return matchRole && matchSearch;
              }).toList();

              if (users.isEmpty)
                return _buildEmptyState(
                    Icons.people_outline, 'لا يوجد مستخدمين');

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profileImageUrl != null
                            ? CachedNetworkImageProvider(user.profileImageUrl!)
                            : null,
                        child: user.profileImageUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                              child: Text(user.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      decoration: user.isBanned
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color:
                                          user.isBanned ? Colors.grey : null),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis)),
                          if (user.isVerified)
                            const Icon(Icons.verified,
                                color: Colors.blue, size: 16),
                          if (user.isBanned)
                            const Icon(Icons.block,
                                color: Colors.red, size: 16),
                        ],
                      ),
                      subtitle: Text(
                          '${user.getRoleDisplayName('ar')} | ${user.state ?? 'غير محدد'}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.info_outline,
                                color: Colors.blue),
                            onPressed: () => _showUserDetails(user),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUserDetails(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: user.profileImageUrl != null
                          ? CachedNetworkImageProvider(user.profileImageUrl!)
                          : null,
                      child: user.profileImageUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    if (user.isBanned)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.block,
                              color: Colors.red, size: 50),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(user.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              Center(
                child: Text(user.getRoleDisplayName('ar'),
                    style: const TextStyle(color: AppColors.primary)),
              ),
              const Divider(height: 32),
              _buildDetailRow(
                  Icons.phone, 'الهاتف', user.phoneNumber ?? 'غير محدد'),
              _buildDetailRow(Icons.email, 'البريد', user.email),
              _buildDetailRow(
                  Icons.work, 'المهنة', user.jobTitle ?? 'غير محدد'),
              _buildDetailRow(Icons.location_on, 'الموقع',
                  '${user.locality ?? ''} ${user.state ?? ''}'),
              _buildDetailRow(Icons.star, 'التقييم',
                  '${user.ratingDisplay} (${user.reviewsCount} مراجعة)'),
              _buildDetailRow(Icons.date_range, 'تاريخ التسجيل',
                  user.createdAt.toString().split(' ')[0]),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              user.isBanned ? Colors.green : Colors.red,
                          foregroundColor: Colors.white),
                      icon: Icon(
                          user.isBanned ? Icons.check_circle : Icons.block),
                      label: Text(user.isBanned
                          ? 'إلغاء حظر المستخدم'
                          : 'حظر المستخدم'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.id)
                            .update({
                          'isBanned': !user.isBanned,
                        });
                        if (mounted) {
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          scaffoldMessenger.showSnackBar(SnackBar(
                            content: Text(user.isBanned
                                ? 'تم فك حظر المستخدم'
                                : 'تم حظر المستخدم'),
                            backgroundColor:
                                user.isBanned ? Colors.green : Colors.red,
                          ));
                        }
                      },
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          SizedBox(
              width: 100,
              child: Text(title,
                  style: TextStyle(
                      color: Colors.grey[600], fontWeight: FontWeight.bold))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  // ==========================================
  // 3. التنبيهات (Advanced Notifications)
  // ==========================================
  final _notifTitleCtrl = TextEditingController();
  final _notifMsgCtrl = TextEditingController();
  String _notifTargetRole = 'all';
  String _notifTargetState = 'all';
  String _notifTargetLocality = 'all';
  bool _isSendingNotif = false;

  Widget _buildNotificationsManager() {
    List<String> localities = _notifTargetState == 'all'
        ? []
        : SudanLocations.getLocalities(_notifTargetState);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إرسال تنبيه مستهدف',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: _notifTitleCtrl,
                  decoration: const InputDecoration(
                      labelText: 'عنوان التنبيه', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notifMsgCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'نص التنبيه', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _notifTargetRole,
                        decoration: const InputDecoration(
                            labelText: 'النوع',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('الكل')),
                          DropdownMenuItem(
                              value: 'freelancer', child: Text('حرفي')),
                          DropdownMenuItem(
                              value: 'techService', child: Text('تقني')),
                          DropdownMenuItem(value: 'shop', child: Text('متجر')),
                          DropdownMenuItem(
                              value: 'client', child: Text('عميل')),
                        ],
                        onChanged: (v) => setState(() => _notifTargetRole = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _notifTargetState,
                        decoration: const InputDecoration(
                            labelText: 'الولاية',
                            border: OutlineInputBorder(),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 10)),
                        items: [
                          const DropdownMenuItem(
                              value: 'all', child: Text('الكل')),
                          ...SudanLocations.states.map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _notifTargetState = v!;
                            _notifTargetLocality = 'all';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    icon: _isSendingNotif
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(
                        _isSendingNotif
                            ? 'جاري الإرسال...'
                            : 'إرسال التنبيه الآن',
                        style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                    onPressed: _isSendingNotif ? null : _sendBulkNotification,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('سجل التنبيهات المرسلة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bulk_notifications')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const LoadingIndicator();
              final logs = snapshot.data?.docs ?? [];

              if (logs.isEmpty)
                return _buildEmptyState(Icons.history, 'لا يوجد سجل للتنبيهات');

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  final logId = logs[index].id;
                  final time = log['createdAt'] as Timestamp?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(log['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${log['message']}\\nتم الإرسال لـ ${log['fcmSent'] ?? 0} مستخدم'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteNotificationLog(logId),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _deleteNotificationLog(String id) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: const Text('سيتم حذف هذا السجل من القائمة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('bulk_notifications')
                  .doc(id)
                  .delete();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendBulkNotification() async {
    if (_notifTitleCtrl.text.isEmpty || _notifMsgCtrl.text.isEmpty) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال العنوان والنص')));
      return;
    }

    setState(() => _isSendingNotif = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('adminSendNotification');
      final result = await callable.call(<String, dynamic>{
        'title': _notifTitleCtrl.text,
        'message': _notifMsgCtrl.text,
        'targetRole': _notifTargetRole,
        'targetState': _notifTargetState,
        'targetLocality': _notifTargetLocality,
      });

      final data = result.data as Map<String, dynamic>;

      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(data['message'] ?? 'تم الإرسال بنجاح'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
        _notifTitleCtrl.clear();
        _notifMsgCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('خطأ في الإرسال: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSendingNotif = false);
    }
  }

  // ==========================================
  // 4. الإعلانات (Ads Manager)
  // ==========================================
  Widget _buildAdsManager() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ads')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const LoadingIndicator();
          final ads = snapshot.data?.docs ?? [];

          if (ads.isEmpty)
            return _buildEmptyState(
                Icons.campaign_outlined, 'لا توجد إعلانات حالياً');

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = AdModel.fromFirestore(ads[index]);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    if (ad.mediaUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: ad.mediaType == AdMediaType.video
                            ? Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.black87,
                                child: const Icon(Icons.play_circle_fill,
                                    color: Colors.white, size: 48))
                            : CachedNetworkImage(
                                imageUrl: ad.mediaUrl,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                    ListTile(
                      title: Text(ad.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${ad.targetState == 'all' ? 'كل السودان' : ad.targetState} | الدور: ${ad.targetRole == 'all' ? 'الكل' : ad.targetRole}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: ad.isValid
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(ad.isValid ? 'نشط' : 'منتهي',
                            style: TextStyle(
                                color: ad.isValid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                    const Divider(height: 1),
                    OverflowBar(
                      children: [
                        TextButton.icon(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text('حذف',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => FirebaseFirestore.instance
                                .collection('ads')
                                .doc(ad.id)
                                .delete()),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddAdDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
    );
  }

  void _showAddAdDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final mediaUrlCtrl = TextEditingController();
    String targetState = 'all';
    String targetLocality = 'all';
    String targetRole = 'all';
    AdPlacement selectedPlacement = AdPlacement.homeBanner;
    AdMediaType selectedMediaType = AdMediaType.image;
    PlatformFile? selectedVideoFile;
    bool isUploadingVideo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        List<String> localities = targetState == 'all'
            ? []
            : SudanLocations.getLocalities(targetState);

        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('إضافة إعلان جديد',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'عنوان الإعلان',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'الوصف', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdPlacement>(
                  initialValue: selectedPlacement,
                  decoration: const InputDecoration(
                      labelText: 'موقع عرض الإعلان',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: AdPlacement.homeBanner,
                        child: Text('بانر الرئيسية (أعلى)')),
                    DropdownMenuItem(
                        value: AdPlacement.communityFeed,
                        child: Text('في مجتمع المنشورات')),
                    DropdownMenuItem(
                        value: AdPlacement.featuredService,
                        child: Text('خدمة مميزة')),
                    DropdownMenuItem(
                        value: AdPlacement.featuredShop,
                        child: Text('متجر مميز')),
                  ],
                  onChanged: (val) => setState(() => selectedPlacement = val!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AdMediaType>(
                  initialValue: selectedMediaType,
                  decoration: const InputDecoration(
                      labelText: 'نوع الميديا', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: AdMediaType.image, child: Text('صورة')),
                    DropdownMenuItem(
                        value: AdMediaType.video, child: Text('فيديو (mp4)')),
                  ],
                  onChanged: (val) => setState(() {
                    selectedMediaType = val!;
                    selectedVideoFile = null;
                  }),
                ),
                const SizedBox(height: 12),
                if (selectedMediaType == AdMediaType.video) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: Text(selectedVideoFile != null
                        ? 'تم اختيار الفيديو'
                        : 'اختر فيديو (mp4)'),
                    onPressed: isUploadingVideo
                        ? null
                        : () async {
                            final result = await FilePicker.pickFiles(
                                type: FileType.video,
                                allowedExtensions: ['mp4']);
                            if (result != null && result.files.isNotEmpty) {
                              setState(
                                  () => selectedVideoFile = result.files.first);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                    controller: mediaUrlCtrl,
                    decoration: const InputDecoration(
                        labelText: 'أو ضع رابط مباشر للميديا (URL)',
                        border: OutlineInputBorder())),
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider()),
                const Text('الاستهداف',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: targetRole,
                  decoration: const InputDecoration(
                      labelText: 'الجمهور المستهدف',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('جميع المستخدمين')),
                    DropdownMenuItem(
                        value: 'freelancer',
                        child: Text('الحرفيين والفنيين فقط')),
                    DropdownMenuItem(value: 'shop', child: Text('المتاجر فقط')),
                    DropdownMenuItem(
                        value: 'client', child: Text('العملاء فقط')),
                  ],
                  onChanged: (v) => setState(() => targetRole = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: targetState,
                  decoration: const InputDecoration(
                      labelText: 'الولاية', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: 'all', child: Text('كل السودان')),
                    ...SudanLocations.states
                        .map((s) => DropdownMenuItem(value: s, child: Text(s))),
                  ],
                  onChanged: (v) => setState(() {
                    targetState = v!;
                    targetLocality = 'all';
                  }),
                ),
                const SizedBox(height: 12),
                if (targetState != 'all' && localities.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: targetLocality,
                    decoration: const InputDecoration(
                        labelText: 'المحلية', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: 'all', child: Text('كل المحليات')),
                      ...localities.map(
                          (l) => DropdownMenuItem(value: l, child: Text(l))),
                    ],
                    onChanged: (v) => setState(() => targetLocality = v!),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: isUploadingVideo
                      ? null
                      : () async {
                          if (titleCtrl.text.isEmpty) return;
                          final nav = Navigator.of(ctx);
                          String finalMediaUrl = mediaUrlCtrl.text.trim();

                          if (selectedMediaType == AdMediaType.video &&
                              selectedVideoFile != null) {
                            setState(() => isUploadingVideo = true);
                            try {
                              final storagePath =
                                  'ads/videos/${DateTime.now().millisecondsSinceEpoch}_${selectedVideoFile!.name}';
                              final ref = FirebaseStorage.instance
                                  .ref()
                                  .child(storagePath);
                              UploadTask uploadTask;
                              if (selectedVideoFile!.path != null) {
                                uploadTask =
                                    ref.putFile(File(selectedVideoFile!.path!));
                              } else {
                                uploadTask =
                                    ref.putData(selectedVideoFile!.bytes!);
                              }
                              final snapshot = await uploadTask;
                              finalMediaUrl =
                                  await snapshot.ref.getDownloadURL();
                            } catch (e) {
                              if (mounted)
                                setState(() => isUploadingVideo = false);
                              return;
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('ads')
                              .add({
                            'title': titleCtrl.text,
                            'description': descCtrl.text,
                            'mediaUrl': finalMediaUrl,
                            'mediaType': selectedMediaType.name,
                            'placement': selectedPlacement.name,
                            'targetRole': targetRole,
                            'targetState': targetState,
                            'targetLocality': targetLocality,
                            'targetRegion':
                                targetState, // For backward compatibility
                            'targetProfession':
                                targetRole, // For backward compatibility
                            'expiryDate': Timestamp.fromDate(
                                DateTime.now().add(const Duration(days: 7))),
                            'createdAt': FieldValue.serverTimestamp(),
                            'isActive': true,
                          });
                          if (mounted) nav.pop();
                        },
                  child: isUploadingVideo
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('نشر الإعلان'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ==========================================
  // 5. التوثيق (Verification Queue)
  // ==========================================
  Widget _buildVerificationQueue() {
    return StreamBuilder<List<UserModel>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('verificationStatus', isEqualTo: 'pending')
          .snapshots()
          .map((s) => s.docs.map((d) => UserModel.fromFirestore(d)).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LoadingIndicator();
        final users = snapshot.data ?? [];
        if (users.isEmpty)
          return _buildEmptyState(
              Icons.verified_user_outlined, 'لا توجد طلبات توثيق معلقة');

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                    backgroundImage: user.profileImageUrl != null
                        ? CachedNetworkImageProvider(user.profileImageUrl!)
                        : null),
                title: Text(user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text('${user.phoneNumber ?? ''}\\n${user.jobTitle ?? ''}'),
                isThreeLine: true,
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white),
                  onPressed: () => _showReviewDialog(context, user),
                  child: const Text('مراجعة'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReviewDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('توثيق: ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (user.idCardUrl != null)
              CachedNetworkImage(
                  imageUrl: user.idCardUrl!, height: 200, fit: BoxFit.cover)
            else
              const Text('لم يتم رفع هوية',
                  style: TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () =>
                _updateVerification(user.id, VerificationStatus.rejected, ctx),
            child: const Text('رفض', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () =>
                _updateVerification(user.id, VerificationStatus.verified, ctx),
            child: const Text('توثيق الحساب'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVerification(
      String userId, VerificationStatus status, BuildContext ctx) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'verificationStatus': status.name,
      'isVerified': status == VerificationStatus.verified,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    Navigator.pop(ctx);
  }

  // ==========================================
  // 6. سجل العقود (Contracts Log)
  // ==========================================
  Widget _buildContractsLog() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('type', isEqualTo: 'contract')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LoadingIndicator();
        final contracts = snapshot.data?.docs ?? [];
        if (contracts.isEmpty)
          return _buildEmptyState(
              Icons.handshake_outlined, 'لا توجد عقود مسجلة');

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: contracts.length,
          itemBuilder: (context, index) {
            final data = contracts[index].data() as Map<String, dynamic>;
            final status = data['contractStatus'] ?? 'pending';
            Color color = status == 'accepted'
                ? Colors.green
                : (status == 'rejected' ? Colors.red : Colors.orange);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.handshake, color: color)),
                title: Text(data['senderName'] ?? 'عقد عمل',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('السعر: ${data['contractPrice']} SDG'),
                trailing: Text(status,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 7. طلبات الحذف (Deletion Queue)
  // ==========================================
  Widget _buildDeletionQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('deletion_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LoadingIndicator();
        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty)
          return _buildEmptyState(
              Icons.person_remove_outlined, 'لا توجد طلبات حذف');

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final data = req.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red, size: 32),
                title: Text(data['name'] ?? 'مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('السبب: ${data['reason']}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white),
                  onPressed: () =>
                      _deleteUserAccount(req.id, data['userId'], data['name']),
                  child: const Text('حذف نهائي'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteUserAccount(
      String reqId, String userId, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف $name نهائياً؟'),
        content: const Text(
          'سيتم حذف:\n• بيانات الحساب\n• جميع المنشورات\n• التقييمات والبلاغات\n• الإشعارات\n• طلب الحذف\n\nلا يمكن التراجع عن هذه العملية.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              // نعرض مؤشر تحميل
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('جاري حذف الحساب...'),
                    duration: Duration(seconds: 60)),
              );
              try {
                final db = FirebaseFirestore.instance;
                // نحذف دفعات باستخدام WriteBatch لضمان الاتساق
                // ─── 1. حذف المنشورات ───
                final posts = await db
                    .collection('posts')
                    .where('userId', isEqualTo: userId)
                    .get();
                for (final post in posts.docs) {
                  await post.reference.delete();
                }
                // ─── 2. حذف التقييمات (كمُقيِّم أو مُقيَّم) ───
                final reviewsBy = await db
                    .collection('reviews')
                    .where('reviewerId', isEqualTo: userId)
                    .get();
                final reviewsFor = await db
                    .collection('reviews')
                    .where('freelancerId', isEqualTo: userId)
                    .get();
                for (final r in [...reviewsBy.docs, ...reviewsFor.docs]) {
                  await r.reference.delete();
                }
                // ─── 3. حذف الإشعارات ───
                final notifs = await db
                    .collection('notifications')
                    .where('userId', isEqualTo: userId)
                    .get();
                for (final n in notifs.docs) {
                  await n.reference.delete();
                }
                // ─── 4. حذف البلاغات المقدمة من المستخدم ───
                final reports = await db
                    .collection('reports')
                    .where('reporterId', isEqualTo: userId)
                    .get();
                for (final r in reports.docs) {
                  await r.reference.delete();
                }
                // ─── 5. حذف العروض (Proposals) ───
                final proposals = await db
                    .collection('proposals')
                    .where('freelancerId', isEqualTo: userId)
                    .get();
                for (final p in proposals.docs) {
                  await p.reference.delete();
                }
                // ─── 6. تحديث طلب الحذف إلى "تم التنفيذ" ───
                await db.collection('deletion_requests').doc(reqId).update({
                  'status': 'completed',
                  'completedAt': FieldValue.serverTimestamp(),
                });
                // ─── 7. حذف وثيقة المستخدم الرئيسية ───
                await db.collection('users').doc(userId).delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ تم حذف حساب $name بالكامل'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء الحذف: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 6),
                    ),
                  );
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String msg) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: Colors.grey, fontSize: 16))
    ]));
  }

  // ==========================================
  // 8. إعدادات التطبيق (App Settings)
  // ==========================================
  Widget _buildAppSettings() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('settings')
          .doc('app_settings')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const LoadingIndicator();

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final whatsappCtrl = TextEditingController(
            text: data['whatsapp'] ?? 'https://wa.me/249900578357');
        final facebookCtrl = TextEditingController(
            text: data['facebook'] ??
                'https://www.facebook.com/share/18J8UXiEDe/');
        final telegramCtrl = TextEditingController(
            text: data['telegram'] ?? 'https://t.me/JamalJhome');
        final websiteCtrl = TextEditingController(
            text: data['website'] ?? 'https://sudanfree.com/sudan-free.html/');
        final shareTextArCtrl = TextEditingController(
            text: data['share_text_ar'] ??
                'جرب تطبيق سودان فري للعثور على فرص عمل ومستقلين موثوقين! حمل التطبيق الآن: https://sudanfree.com/sudan-free.html');
        final shareTextEnCtrl = TextEditingController(
            text: data['share_text_en'] ??
                'Try SudanFree to find jobs and trusted freelancers! Download now: https://sudanfree.com/sudan-free.html');

        bool isSaving = false;

        return StatefulBuilder(builder: (context, setSettingsState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('روابط التواصل والمشاركة',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    TextField(
                      controller: whatsappCtrl,
                      decoration: const InputDecoration(
                          labelText: 'رابط واتساب',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.chat, color: Colors.green)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: facebookCtrl,
                      decoration: const InputDecoration(
                          labelText: 'رابط فيسبوك',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.facebook, color: Colors.blue)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: telegramCtrl,
                      decoration: const InputDecoration(
                          labelText: 'رابط تلجرام',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.send, color: Colors.blueAccent)),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: websiteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'الموقع الإلكتروني',
                          border: OutlineInputBorder(),
                          prefixIcon:
                              Icon(Icons.language, color: Colors.purple)),
                    ),
                    const SizedBox(height: 24),
                    const Text('نص المشاركة (دعوة الأصدقاء)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shareTextArCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'النص العربي',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: shareTextEnCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'النص الإنجليزي',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(
                            isSaving ? 'جاري الحفظ...' : 'حفظ الإعدادات',
                            style: const TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSettingsState(() => isSaving = true);
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('settings')
                                      .doc('app_settings')
                                      .set({
                                    'whatsapp': whatsappCtrl.text,
                                    'facebook': facebookCtrl.text,
                                    'telegram': telegramCtrl.text,
                                    'website': websiteCtrl.text,
                                    'share_text_ar': shareTextArCtrl.text,
                                    'share_text_en': shareTextEnCtrl.text,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('تم الحفظ بنجاح'),
                                            backgroundColor: Colors.green));
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text('حدث خطأ: $e'),
                                            backgroundColor: Colors.red));
                                  }
                                } finally {
                                  if (context.mounted)
                                    setSettingsState(() => isSaving = false);
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }
}
