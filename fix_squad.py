import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/squad_profile_screen.dart', 'r') as f:
    content = f.read()

# Fix 1: Move `_showManageMembersBottomSheet` into the class
# First, find the `_showManageMembersBottomSheet` function block at the end
method_start = '  void _showManageMembersBottomSheet(BuildContext context, bool isAr) {'

# Split the content
if method_start in content:
    method_content = content[content.find(method_start):]
    content = content[:content.find(method_start)]

    # Now `method_content` has the function and the extra `}` at the end.
    # The end of `method_content` is probably `  }\n}\n` or something similar.
    # We will insert it before `class _SliverTabBarDelegate`.
    
    # We need to drop the extra `}` at the very end of the file.
    method_content = method_content.rstrip()
    if method_content.endswith('}'):
        method_content = method_content[:-1].rstrip() # Remove the last `}`

    insert_target = '}\n\nclass _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {'
    replacement = method_content + '\n}\n\nclass _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {'
    
    content = content.replace(insert_target, replacement)
    
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/views/profile/squad_profile_screen.dart', 'w') as f:
        f.write(content)
