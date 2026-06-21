import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/providers/search_provider.dart', 'r') as f:
    content = f.read()

if 'import \'package:cloud_firestore/cloud_firestore.dart\';' not in content:
    content = content.replace("import '../services/firestore_service.dart';", "import '../services/firestore_service.dart';\nimport 'package:cloud_firestore/cloud_firestore.dart';")

content = content.replace("await _firestoreService.getCollection('users')", "await FirebaseFirestore.instance.collection('users')")

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/providers/search_provider.dart', 'w') as f:
    f.write(content)
