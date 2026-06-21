import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/dashboard_screen.dart', 'r') as f:
    content = f.read()

old_categories = """      {
        'title': locale == 'ar' ? 'الفئات' : 'Categories',
        'icon': Icons.category,
        // Categories can still navigate to search/tab 1 if preferred, or open a special sheet
        // but for consistency, we'll route it to the filtered screen for now
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => FilteredProvidersScreen(filterType: FilterType.categories, title: locale == 'ar' ? 'كل الفئات' : 'All Categories'))),
      },"""

new_categories = """      {
        'title': locale == 'ar' ? 'المجموعات' : 'Squads',
        'icon': Icons.groups,
        'action': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SquadsExplorerScreen())),
      },"""

if old_categories in content:
    content = content.replace(old_categories, new_categories)
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/home/dashboard_screen.dart', 'w') as f:
        f.write(content)
    print("Replaced categories with squads")
else:
    print("Old categories not found")
