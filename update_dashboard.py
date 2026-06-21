import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/dashboard_screen.dart', 'r') as f:
    content = f.read()

# 1. Add imports if missing
if 'import \'../../models/squad_model.dart\';' not in content:
    content = content.replace("import '../../models/user_model.dart';", "import '../../models/user_model.dart';\nimport '../../models/squad_model.dart';\nimport '../profile/squad_profile_screen.dart';\nimport '../squads/squads_explorer_screen.dart';")

# 2. Replace _buildQuickCategories
quick_cat_old = re.search(r'Widget _buildQuickCategories\(BuildContext context, String locale\) \{.*?(?=  Widget _buildProfessionalSection)', content, re.DOTALL)
if quick_cat_old:
    new_quick_cat = """Widget _buildQuickCategories(BuildContext context, String locale) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('squads').orderBy('rating', descending: true).limit(10).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final squads = snapshot.data!.docs.map((doc) => SquadModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 85,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: squads.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index == squads.length) {
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadsExplorerScreen())),
                  child: Container(
                    width: 95,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_forward, color: AppColors.primary, size: 28),
                        const SizedBox(height: 6),
                        Text(locale == 'ar' ? 'المزيد' : 'More', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              final squad = squads[index];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadProfileScreen(squad: squad))),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: squad.squadImageUrl != null ? CachedNetworkImageProvider(squad.squadImageUrl!) : null,
                        child: squad.squadImageUrl == null ? const Icon(Icons.groups, size: 16, color: AppColors.primary) : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        squad.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
"""
    content = content.replace(quick_cat_old.group(0), new_quick_cat + '\n')

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/dashboard_screen.dart', 'w') as f:
    f.write(content)

