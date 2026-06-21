import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/user_model.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/cards/freelancer_card.dart';

enum FilterType {
  nearYou,
  topRated,
  newest,
  shops,
  categories,
  freelancersNearYou,
  shopsNearYou
}

class FilteredProvidersScreen extends StatefulWidget {
  final FilterType filterType;
  final String title;

  const FilteredProvidersScreen(
      {super.key, required this.filterType, required this.title});

  @override
  State<FilteredProvidersScreen> createState() =>
      _FilteredProvidersScreenState();
}

class _FilteredProvidersScreenState extends State<FilteredProvidersScreen> {
  final ScrollController _scrollController = ScrollController();
  List<UserModel> _displayList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _fetchMoreData();
      }
    }
  }

  Future<void> _fetchInitialData() async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = context.read<AuthProvider>().user;

    try {
      Query query;
      switch (widget.filterType) {
        case FilterType.nearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role', whereIn: [
            'freelancer',
            'shop',
            'privateService',
            'techService',
            'Freelancer',
            'Shop',
            'FREELANCER',
            'SHOP',
            'freelancer ',
            'shop '
          ]).limit(20);
          break;
        case FilterType.topRated:
          query = firestore
              .collection('users')
              .orderBy('rating', descending: true)
              .limit(20);
          break;
        case FilterType.newest:
          query = firestore
              .collection('users')
              .orderBy('createdAt', descending: true)
              .limit(20);
          break;
        case FilterType.shops:
          query = firestore
              .collection('users')
              .where('role', isEqualTo: 'shop')
              .limit(20);
          break;
        case FilterType.freelancersNearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role', whereIn: [
            'freelancer',
            'privateService',
            'techService',
            'Freelancer',
            'FREELANCER',
            'freelancer ',
            'Freelancer '
          ]).limit(20);
          break;
        case FilterType.shopsNearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role', whereIn: [
            'shop',
            'Shop',
            'SHOP',
            'shop ',
            'Shop '
          ]).limit(20);
          break;
        case FilterType.categories:
          query = firestore.collection('users').limit(20);
          break;
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == 20;

        List<UserModel> results =
            snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
        if (widget.filterType == FilterType.freelancersNearYou) {
          results = results
              .where(
                  (u) => u.role != UserRole.client && u.role != UserRole.shop)
              .toList();
        } else if (widget.filterType == FilterType.shopsNearYou) {
          results = results.where((u) => u.role == UserRole.shop).toList();
        } else if (widget.filterType != FilterType.shops) {
          results = results.where((u) => u.role != UserRole.client).toList();
        }

        if (widget.filterType == FilterType.topRated) {
          results.sort((a, b) {
            final cmp = b.totalStars.compareTo(a.totalStars);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
        }

        if (widget.filterType == FilterType.shops) {
          results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (widget.filterType == FilterType.nearYou ||
            widget.filterType == FilterType.freelancersNearYou ||
            widget.filterType == FilterType.shopsNearYou) {
          int getLocationScore(UserModel u) {
            if (currentUser?.state == null) return 0;
            int score = 0;
            if (u.state == currentUser!.state) score += 1;
            if (u.locality != null &&
                currentUser.locality != null &&
                u.locality == currentUser.locality) score += 2;
            if (u.neighborhood != null && currentUser.neighborhood != null) {
              final uNeigh = u.neighborhood!.toLowerCase().replaceAll(' ', '');
              final cNeigh =
                  currentUser.neighborhood!.toLowerCase().replaceAll(' ', '');
              if (uNeigh == cNeigh) {
                score += 5;
              } else if (uNeigh.isNotEmpty &&
                  cNeigh.isNotEmpty &&
                  (uNeigh.contains(cNeigh) || cNeigh.contains(uNeigh))) {
                score += 4;
              }
            }
            return score;
          }

          results.sort((a, b) {
            final aScore = getLocationScore(a);
            final bScore = getLocationScore(b);
            if (aScore != bScore) return bScore.compareTo(aScore);
            return b.rating.compareTo(a.rating);
          });
        }

        if (mounted) {
          setState(() {
            _displayList = results;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching real data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreData() async {
    if (_lastDoc == null || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final firestore = FirebaseFirestore.instance;
    final currentUser = context.read<AuthProvider>().user;

    try {
      Query query;
      switch (widget.filterType) {
        case FilterType.nearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role', whereIn: [
                'freelancer',
                'shop',
                'privateService',
                'techService',
                'Freelancer',
                'Shop',
                'FREELANCER',
                'SHOP',
                'freelancer ',
                'shop '
              ])
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.topRated:
          query = firestore
              .collection('users')
              .orderBy('rating', descending: true)
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.newest:
          query = firestore
              .collection('users')
              .orderBy('createdAt', descending: true)
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.shops:
          query = firestore
              .collection('users')
              .where('role', isEqualTo: 'shop')
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.freelancersNearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role', whereIn: [
                'freelancer',
                'privateService',
                'techService',
                'Freelancer',
                'FREELANCER',
                'freelancer ',
                'Freelancer '
              ])
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.shopsNearYou:
          query = firestore
              .collection('users')
              .where('state', isEqualTo: currentUser?.state ?? '')
              .where('role',
                  whereIn: ['shop', 'Shop', 'SHOP', 'shop ', 'Shop '])
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
        case FilterType.categories:
          query = firestore
              .collection('users')
              .startAfterDocument(_lastDoc!)
              .limit(20);
          break;
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastDoc = snapshot.docs.last;
        _hasMore = snapshot.docs.length == 20;

        List<UserModel> results =
            snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
        if (widget.filterType == FilterType.freelancersNearYou) {
          results = results
              .where(
                  (u) => u.role != UserRole.client && u.role != UserRole.shop)
              .toList();
        } else if (widget.filterType == FilterType.shopsNearYou) {
          results = results.where((u) => u.role == UserRole.shop).toList();
        } else if (widget.filterType != FilterType.shops) {
          results = results.where((u) => u.role != UserRole.client).toList();
        }

        if (widget.filterType == FilterType.topRated) {
          results.sort((a, b) {
            final cmp = b.totalStars.compareTo(a.totalStars);
            if (cmp != 0) return cmp;
            return b.rating.compareTo(a.rating);
          });
        }

        if (widget.filterType == FilterType.shops) {
          results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        }

        if (mounted) {
          setState(() {
            _displayList.addAll(results);
            if (widget.filterType == FilterType.nearYou ||
                widget.filterType == FilterType.freelancersNearYou ||
                widget.filterType == FilterType.shopsNearYou) {
              int getLocationScore(UserModel u) {
                if (currentUser?.state == null) return 0;
                int score = 0;
                if (u.state == currentUser!.state) score += 1;
                if (u.locality != null &&
                    currentUser.locality != null &&
                    u.locality == currentUser.locality) score += 2;
                if (u.neighborhood != null &&
                    currentUser.neighborhood != null) {
                  final uNeigh =
                      u.neighborhood!.toLowerCase().replaceAll(' ', '');
                  final cNeigh = currentUser.neighborhood!
                      .toLowerCase()
                      .replaceAll(' ', '');
                  if (uNeigh == cNeigh) {
                    score += 5;
                  } else if (uNeigh.isNotEmpty &&
                      cNeigh.isNotEmpty &&
                      (uNeigh.contains(cNeigh) || cNeigh.contains(uNeigh))) {
                    score += 4;
                  }
                }
                return score;
              }

              _displayList.sort((a, b) {
                final aScore = getLocationScore(a);
                final bScore = getLocationScore(b);
                if (aScore != bScore) return bScore.compareTo(aScore);
                return b.rating.compareTo(a.rating);
              });
            }
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching more data: $e");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale.languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _displayList.isEmpty
              ? Center(
                  child: Text(
                    locale == 'ar' ? 'لا توجد نتائج' : 'No results found',
                    style: TextStyle(color: AppColors.softGrey, fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: _displayList.length,
                        itemBuilder: (context, index) {
                          final user = _displayList[index];
                          return FreelancerCard(
                            freelancer: user,
                            locale: locale,
                            currentUserId:
                                context.read<AuthProvider>().user?.id,
                            currentUserName:
                                context.read<AuthProvider>().user?.name,
                            showContactButton: false,
                          );
                        },
                      ),
                    ),
                    if (_isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
    );
  }
}
