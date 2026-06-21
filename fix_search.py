import re

with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/providers/search_provider.dart', 'r') as f:
    content = f.read()

# Modify the searchFreelancers method to fetch from Firestore directly for search queries
search_old = """      if (query != null && query.isNotEmpty) {
        final normalizedQuery = _normalize(query);
        
        users = users.where((u) {
          // 1. Check searchKeywords first (fastest - uses pre-computed index)
          for (final keyword in u.searchKeywords) {
            if (keyword.contains(normalizedQuery) || normalizedQuery.contains(keyword)) {
              return true;
            }
          }
          
          // 2. Fallback to smart search (synonym matching, fuzzy, etc.)
          return SmartSearchService.matchesSmartSearch(
            query,
            name: u.name,
            skills: u.skills,
            jobTitle: u.jobTitle,
            bio: u.bio,
            state: u.state,
            locality: u.locality,
          );
        }).toList();"""

search_new = """      if (query != null && query.isNotEmpty) {
        final normalizedQuery = _normalize(query);
        final words = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
        
        // Fetch from Firestore to ensure we get users beyond the first 50 cached
        if (words.isNotEmpty) {
          try {
            // Firestore array-contains can only check one word, so we use the first meaningful word
            final firstWord = words.first;
            final queryResult = await _firestoreService.getCollection('users')
                .where('searchKeywords', arrayContains: firstWord)
                .where('role', whereIn: ['freelancer', 'techService', 'privateService', 'shop'])
                .limit(50)
                .get();
                
            final firestoreUsers = queryResult.docs.map((d) => UserModel.fromMap(d.data())).toList();
            
            // Merge with cached users to ensure we don't miss local fuzzy matches
            for (var u in _cachedProviders) {
               if (!firestoreUsers.any((element) => element.id == u.id)) {
                  firestoreUsers.add(u);
               }
            }
            users = firestoreUsers;
          } catch (e) {
            debugPrint("Firestore search arrayContains error: $e");
            // If index error or anything, fallback to cached users
          }
        }
        
        users = users.where((u) {
          // 1. Check searchKeywords first (fastest - uses pre-computed index)
          for (final keyword in u.searchKeywords) {
            if (keyword.contains(normalizedQuery) || normalizedQuery.contains(keyword)) {
              return true;
            }
          }
          
          // 2. Fallback to smart search (synonym matching, fuzzy, etc.)
          return SmartSearchService.matchesSmartSearch(
            query,
            name: u.name,
            skills: u.skills,
            jobTitle: u.jobTitle,
            bio: u.bio,
            state: u.state,
            locality: u.locality,
          );
        }).toList();"""

if search_old in content:
    content = content.replace(search_old, search_new)
    with open('/home/jamal/Projects/SUDAN-App/sudan_free/lib/providers/search_provider.dart', 'w') as f:
        f.write(content)
    print("Search provider updated to query Firestore arrayContains")
else:
    print("Search old block not found")
