import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/core/utils/job_titles_utils.dart', 'r') as f:
    content = f.read()

# Add a step to strip spaces and convert camel case to normal space for better matching?
# Or just ensure getLocalizedTitle is robust.

content = content.replace("final searchTitle = title.trim().toLowerCase();", """final searchTitle = title.trim().toLowerCase();
      // Handle camel case keys to match space-separated user input
      final String noSpaceSearch = searchTitle.replaceAll(' ', '').replaceAll('-', '').replaceAll('/', '');""")

content = content.replace("final Map<String, String> lowerEnToAr = enToAr.map((k, v) => MapEntry(k.toLowerCase(), v));", """final Map<String, String> lowerEnToAr = {};
        enToAr.forEach((k, v) {
          lowerEnToAr[k.toLowerCase()] = v;
          lowerEnToAr[k.toLowerCase().replaceAll(' ', '').replaceAll('-', '').replaceAll('/', '')] = v;
        });""")

content = content.replace("final Map<String, String> arToEn = {};", """final Map<String, String> arToEn = {};
        enToAr.forEach((k, v) {
          arToEn[v.trim().toLowerCase()] = k;
        });""")

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/core/utils/job_titles_utils.dart', 'w') as f:
    f.write(content)

