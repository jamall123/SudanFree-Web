# Flutter Performance Best Practices Guide

**For:** SUDAN-App Development Team  
**Status:** Recommended Practices (from optimization pass)

---

## 1. Memory Management

### Dispose Pattern ✅
**Always implement `dispose()` in providers that manage resources:**

```dart
class MyProvider extends ChangeNotifier {
  StreamSubscription? _subscription;
  Timer? _timer;
  
  @override
  void dispose() {
    _subscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
```

### Image Caching ✅
**Limit image cache to prevent OOM:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set limits
  imageCache.maximumSize = 200; // max images
  imageCache.maximumSizeBytes = 100 * 1024 * 1024; // 100 MB
}
```

### Lazy Loading ✅
**Load only what's visible on screen:**

```dart
// Good: Only loads visible items
ListView.builder(
  itemBuilder: (context, index) => MyItem(data[index]),
  itemCount: data.length,
)

// Bad: Loads all items upfront
Column(children: data.map(MyItem.new).toList())
```

---

## 2. Data Fetching & Pagination

### Query Limits ✅
**Always paginate - never fetch unlimited data:**

```dart
// Good: Fetch manageable chunks
Stream<List<PostModel>> getJobs({int limit = 50}) {
  return _firestore
    .collection('jobs')
    .limit(limit)
    .snapshots();
}

// Bad: No limit - could fetch thousands of records
Stream<List<PostModel>> getJobs() {
  return _firestore.collection('jobs').snapshots();
}
```

### Safe Type Casting ✅
**Use `is` checks instead of `as` casts:**

```dart
// Good: Safe casting with error handling
final data = result['posts'];
if (data is! List<PostModel>) {
  throw TypeError();
}

// Bad: Unsafe - crashes on type mismatch
final posts = result['posts'] as List<PostModel>;
```

---

## 3. Widget Optimization

### Navigation ✅
**Use Offstage/PageView instead of IndexedStack for multiple screens:**

```dart
// Good: Only active screen rendered
Stack(
  children: [
    for (int i = 0; i < screens.length; i++)
      Offstage(
        offstage: _currentIndex != i,
        child: screens[i],
      ),
  ],
)

// Acceptable: IndexedStack (all screens in memory)
IndexedStack(
  index: _currentIndex,
  children: screens,
)
```

### Image Loading ✅
**Smart precaching - only adjacent images:**

```dart
void _precacheAdjacentImages(int currentIndex) {
  final indicesToPrecache = [
    if (currentIndex > 0) currentIndex - 1,
    currentIndex,
    if (currentIndex < total - 1) currentIndex + 1,
  ];
  
  for (final index in indicesToPrecache) {
    if (_already.contains(index)) continue;
    precacheImage(...);
  }
}
```

---

## 4. Firebase Optimization

### Firestore Settings ✅
**Configure cache size on initialization:**

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: 50 * 1024 * 1024, // 50 MB limit
);
```

### Query Optimization ✅
**Use constraints effectively:**

```dart
// Good practices:
- Filter early (where clauses)
- Order by indexed fields
- Limit results
- Use pagination
- Cache results locally

// Bad practices:
- No filters (scans all documents)
- Ordering by non-indexed fields
- Unlimited queries
- No local caching
```

---

## 5. Error Handling

### Futures & Streams ✅
**Always handle async errors:**

```dart
// Good: Proper error handling
try {
  final result = await checkForUpdate(context);
  if (result) _showUpdateDialog();
} catch (e) {
  debugPrint('Update check error: $e');
  // Silently fail - don't interrupt user
}

// Bad: Silent failures
checkForUpdate(context); // Fire and forget!
```

### Rate Limiting ✅
**Prevent request flooding:**

```dart
static const Duration _cooldown = Duration(minutes: 30);
static DateTime? _lastCheck;

Future<void> checkForUpdate(BuildContext context) async {
  if (_lastCheck != null &&
      DateTime.now().difference(_lastCheck!) < _cooldown) {
    return; // Too soon, skip
  }
  // ... perform check
  _lastCheck = DateTime.now();
}
```

---

## 6. Performance Monitoring

### Debug Logging ✅
**Strategic logging for performance tracking:**

```dart
// Good: Minimal, strategic logging
debugPrint('PostsProvider: Fetching paginated posts...');

// Bad: Excessive logging
debugPrint('Building card');
debugPrint('Image loaded');
debugPrint('Button tapped');
```

### Performance Traces ✅
**Use Firebase Performance Monitoring:**

```dart
final trace = PerformanceService().startTrace('expensive_operation');
try {
  // Do work
  trace.putAttribute('status', 'success');
} catch (e) {
  trace.putAttribute('status', 'error');
} finally {
  trace.stop();
}
```

---

## 7. Code Review Checklist

When reviewing code, check for:

- [ ] **Memory Leaks**: All streams/timers cancelled in `dispose()`?
- [ ] **Pagination**: Queries have limits?
- [ ] **Type Safety**: Using `is` checks instead of unsafe `as`?
- [ ] **Error Handling**: All futures handled with try/catch?
- [ ] **Image Loading**: Using lazy loading, not precaching all?
- [ ] **Rate Limiting**: Preventing request flooding?
- [ ] **Logging**: Strategic, not excessive?
- [ ] **Tests**: Performance tested?

---

## 8. Common Pitfalls to Avoid

### ❌ Memory Leaks
```dart
// WRONG: Stream never cancelled
class MyProvider extends ChangeNotifier {
  StreamSubscription? _sub;
  
  void fetchData() {
    _sub = _stream.listen(...); // Leak if never cancelled!
  }
  // No dispose()
}

// RIGHT: Properly cancelled
class MyProvider extends ChangeNotifier {
  StreamSubscription? _sub;
  
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
```

### ❌ Unbounded Data
```dart
// WRONG: Could fetch 10,000+ items
final jobs = await firestore
  .collection('jobs')
  .get(); // No limit!

// RIGHT: Fetched in manageable chunks
final jobs = await firestore
  .collection('jobs')
  .limit(50)
  .get();
```

### ❌ Image OOM
```dart
// WRONG: Precaches all 100 carousel images
itemBuilder: (ctx, index) {
  for (var i = 0; i < urls.length; i++) {
    precacheImage(urls[i]); // All at once!
  }
  return Image(urls[index]);
}

// RIGHT: Only cache current ±1 images
void _updatePrecache(int current) {
  if (!_cached.contains(current - 1)) precacheImage(urls[current - 1]);
  if (!_cached.contains(current)) precacheImage(urls[current]);
  if (!_cached.contains(current + 1)) precacheImage(urls[current + 1]);
}
```

---

## 9. Recommended Tools

**For Performance Profiling:**
- DevTools (Flutter Performance tab)
- Android Studio Profiler (Memory, CPU)
- Firebase Performance Monitoring
- Dart VM Service

**For Analysis:**
- `dart analyze` - Static analysis
- `flutter pub outdated` - Dependency updates
- Memory profilers - Find leaks

---

## 10. Resources

- [Flutter Performance Guide](https://flutter.dev/docs/perf)
- [Firestore Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Dart Memory Management](https://dart.dev/guides/language/effective-dart/usage)

---

## Questions?

This guide is based on the optimization pass completed May 2026.  
Refer to `OPTIMIZATION_REPORT.md` for implementation details.

**Remember:** 
> Performance is not a feature - it's a requirement.  
> A slow app is a broken app.
