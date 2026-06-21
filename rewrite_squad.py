import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/squad_profile_screen.dart', 'r') as f:
    content = f.read()

# Replace CustomScrollView
content = content.replace(
    '      body: CustomScrollView(\n        slivers: [',
    '''      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return ['''
)

# Replace SliverToBoxAdapter start with SliverPersistentHeader and TabBarView
sliver_to_box_start = '''          // 2. Squad Information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column('''

new_sliver_to_box_start = '''          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              topPadding: MediaQuery.of(context).padding.top,
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: isAr ? 'معلومات المجموعة' : 'Squad Info'),
                  Tab(text: isAr ? 'معرض الأعمال' : 'Portfolio'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Squad Info
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column('''

content = content.replace(sliver_to_box_start, new_sliver_to_box_start)

# Remove old portfolio section
old_portfolio = '''                  // Portfolio
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isAr ? 'معرض الأعمال' : 'Portfolio',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (isLeader)
                        IconButton(
                          icon: const Icon(Icons.add_a_photo, color: AppColors.primary),
                          onPressed: _uploadPortfolioImage,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_portfolioUrls.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Center(
                        child: Text(isAr ? 'لم يتم إضافة أعمال سابقة بعد' : 'No previous projects added yet', style: TextStyle(color: Colors.grey[600])),
                      ),
                    )
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _portfolioUrls.length,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(_portfolioUrls[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 32),'''

content = content.replace(old_portfolio, '')

# Replace end of CustomScrollView
end_custom_scroll = '''                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),'''

new_end_custom_scroll = '''                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Tab 2: Portfolio
          _buildProfessionalPortfolio(),
        ],
      ),
    ),'''

content = content.replace(end_custom_scroll, new_end_custom_scroll)

# Add _buildProfessionalPortfolio and _buildProjectCard and _SliverTabBarDelegate at the end of class
extra_methods = '''
  Widget _buildProfessionalPortfolio() {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    return StreamBuilder<List<PortfolioProjectModel>>(
      stream: _portfolioStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Error loading portfolio: ${snapshot.error}');
          final errorStr = snapshot.error.toString();
          if (errorStr.contains('permission-denied') || errorStr.contains('PERMISSION_DENIED')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    locale == 'ar' ? 'لا توجد مشاريع في المعرض بعد' : 'No portfolio projects yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                locale == 'ar' ? 'خطأ في تحميل المعرض المهني.' : 'Error loading portfolio.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  locale == 'ar' ? 'لا توجد مشاريع في المعرض بعد' : 'No portfolio projects yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _buildProjectCard(project, locale);
          },
        );
      },
    );
  }

  Widget _buildProjectCard(PortfolioProjectModel project, String locale) {
    final isAr = locale == 'ar';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PortfolioProjectDetailScreen(
              project: project,
              providerName: widget.squad.name,
              providerImageUrl: widget.squad.squadImageUrl,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.imageUrls.isNotEmpty)
              Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: project.imageUrls.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.grey.withValues(alpha: 0.1), child: const Center(child: CircularProgressIndicator())),
                      errorWidget: (_, __, ___) => Container(color: Colors.grey.withValues(alpha: 0.1), child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                  if (project.imageUrls.length > 1)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library, size: 14, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('${project.imageUrls.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
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

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar, {required this.topPadding});

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
          tabBar,
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || topPadding != oldDelegate.topPadding;
  }
'''

content = content.replace('}\n\n  void _showManageMembersBottomSheet', extra_methods + '\n\n  void _showManageMembersBottomSheet')

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/squad_profile_screen.dart', 'w') as f:
    f.write(content)

