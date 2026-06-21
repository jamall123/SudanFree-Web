import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/favorites_screen.dart', 'r') as f:
    content = f.read()

# 1. Imports
imports = '''import '../../models/squad_model.dart';
import 'squad_profile_screen.dart';
'''
if 'squad_model.dart' not in content:
    content = content.replace('import \'../../models/post_model.dart\';', 'import \'../../models/post_model.dart\';\n' + imports)

# 2. Add Tab
tabs_old = '''            tabs: [
              Tab(text: locale == 'ar' ? 'الزملاء' : 'Partners'),
              Tab(text: locale == 'ar' ? 'الحسابات المحفوظة' : 'Saved Accounts'),
              Tab(text: locale == 'ar' ? 'المنشورات المحفوظة' : 'Saved Posts'),
            ],'''
tabs_new = '''            tabs: [
              Tab(text: locale == 'ar' ? 'الزملاء' : 'Partners'),
              Tab(text: locale == 'ar' ? 'الحسابات المحفوظة' : 'Saved Accounts'),
              Tab(text: locale == 'ar' ? 'المجموعات' : 'Squads'),
              Tab(text: locale == 'ar' ? 'المنشورات المحفوظة' : 'Saved Posts'),
            ],'''
content = content.replace(tabs_old, tabs_new).replace('length: 3,', 'length: 4,')

# 3. Add TabBarView children
views_old = '''          children: [
            _buildUsersList(context, user, user.partnerIds, locale, isPartnerList: true),
            _buildUsersList(context, user, user.favoriteUserIds, locale, isPartnerList: false),
            _buildProductsTab(context, user, locale),
          ],'''
views_new = '''          children: [
            _buildUsersList(context, user, user.partnerIds, locale, isPartnerList: true),
            _buildUsersList(context, user, user.favoriteUserIds, locale, isPartnerList: false),
            _buildSquadsTab(context, user, locale),
            _buildProductsTab(context, user, locale),
          ],'''
content = content.replace(views_old, views_new)

# 4. Add _buildSquadsTab method at the end before last }
squads_tab = '''
  Widget _buildSquadsTab(BuildContext context, UserModel user, String locale) {
    if (user.favoriteSquadIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              locale == 'ar' ? 'لا توجد مجموعات محفوظة بعد' : 'No saved squads yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return FutureBuilder<List<SquadModel?>>(
      future: Future.wait(user.favoriteSquadIds.map((id) async {
        try {
          final doc = await FirebaseFirestore.instance.collection('squads').doc(id).get();
          if (!doc.exists) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AuthProvider>().toggleFavoriteSquad(id);
            });
            return null;
          }
          return SquadModel.fromMap(doc.data()!, doc.id);
        } catch (e) {
          return null;
        }
      })),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(locale == 'ar' ? 'حدث خطأ' : 'An error occurred'));
        }

        final squads = snapshot.data?.whereType<SquadModel>().toList() ?? [];
        if (squads.isEmpty) {
          return Center(
            child: Text(
              locale == 'ar' ? 'لا توجد مجموعات محفوظة بعد' : 'No saved squads yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: squads.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final squad = squads[index];
            final isFavorite = user.favoriteSquadIds.contains(squad.id);
            
            return Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadProfileScreen(squad: squad))),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: squad.squadImageUrl != null ? CachedNetworkImageProvider(squad.squadImageUrl!) : null,
                  child: squad.squadImageUrl == null ? const Icon(Icons.groups, color: AppColors.primary) : null,
                ),
                title: Text(squad.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(
                  squad.category.getName(locale),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                trailing: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    context.read<AuthProvider>().toggleFavoriteSquad(squad.id);
                    setState(() {});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
'''
if '_buildSquadsTab' not in content:
    content = content.rsplit('}', 1)[0] + squads_tab

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/favorites_screen.dart', 'w') as f:
    f.write(content)

