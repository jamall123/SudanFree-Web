import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/squads/squads_explorer_screen.dart', 'r') as f:
    content = f.read()

old_block = """              onPressed: () async {
                if (user == null) return;
            try {
              final existing = await FirebaseFirestore.instance
                  .collection('squads')
                  .where('memberIds', arrayContains: user.id)
                  .get();
              if (existing.docs.isNotEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAr 
                        ? 'عذراً، أنت بالفعل عضو في مجموعة. لا يمكنك إنشاء مجموعة أخرى.' 
                        : 'Sorry, you are already a member of a squad. You cannot create another one.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            } catch (e) {
              // Ignore error and proceed or log it
            }

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateSquadScreen()),
                );
              },"""

new_block = """              onPressed: () async {
            try {
              final existing = await FirebaseFirestore.instance
                  .collection('squads')
                  .where('memberIds', arrayContains: user.id)
                  .get();
              if (existing.docs.isNotEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isAr 
                        ? 'عذراً، أنت بالفعل عضو في مجموعة. لا يمكنك إنشاء مجموعة أخرى.' 
                        : 'Sorry, you are already a member of a squad. You cannot create another one.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
            } catch (e) {
              // Ignore error and proceed or log it
            }

                if (!context.mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateSquadScreen()),
                );
              },"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/squads/squads_explorer_screen.dart', 'w') as f:
        f.write(content)
    print("Fixed squads lint")
else:
    print("Squads lint block not found")
