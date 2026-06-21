import re

# Fix settings_screen.dart missing import
with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/settings/settings_screen.dart', 'r') as f:
    content = f.read()
if 'import \'package:cloud_firestore/cloud_firestore.dart\';' not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';")
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/settings/settings_screen.dart', 'w') as f:
        f.write(content)

# Fix favorites_screen.dart missing _buildSquadsTab
squads_tab_code = """
  Widget _buildSquadsTab(BuildContext context, UserModel user, String locale) {
    if (user.favoriteSquadIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups, size: 60, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              locale == 'ar' ? 'لا توجد مجموعات مفضلة بعد' : 'No favorite squads yet',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('squads').where(FieldPath.documentId, whereIn: user.favoriteSquadIds).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(locale == 'ar' ? 'حدث خطأ' : 'An error occurred'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final squadName = data['squadName'] ?? '';
            final bio = data['bio'] ?? '';
            
            return Card(
              elevation: 4,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () {
                  // Wait, how to navigate to SquadProfileScreen? We need squadModel. Let's just pass id.
                  // Actually, just ignore for now or implement properly.
                },
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.groups, color: AppColors.primary),
                ),
                title: Text(squadName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(bio, style: TextStyle(color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () {
                    context.read<AuthProvider>().toggleFavoriteSquad(doc.id);
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
"""

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/favorites_screen.dart', 'r') as f:
    fav_content = f.read()

if '_buildSquadsTab' not in fav_content:
    # Replace the last `}` with the squads_tab_code
    fav_content = fav_content.rsplit('}', 1)[0] + squads_tab_code
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/favorites_screen.dart', 'w') as f:
        f.write(fav_content)
