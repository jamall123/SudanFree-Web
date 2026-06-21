import re

with open("lib/views/map/map_explorer_screen.dart", "w") as f:
    f.write("""import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/locale_provider.dart';
import '../../services/firestore_service.dart';
import '../profile/profile_screen.dart';

class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      headers: const {
        'User-Agent': 'com.sudan.free',
      },
    );
  }
}

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  final MapController _mapController = MapController();
  List<UserModel> _allMapUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  String _selectedRoleFilter = 'all'; // 'all', 'shop', 'freelancer'
  ShopCategory? _selectedShopCategoryFilter;

  // حدود السودان التقريبية
  final LatLngBounds _sudanBounds = LatLngBounds(
    const LatLng(8.65, 21.82), 
    const LatLng(22.22, 38.60), 
  );

  final LatLng _khartoumCenter = const LatLng(15.5007, 32.5599);

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // We will do the initial fetch when the map finishes rendering and calls onPositionChanged for the first time, 
    // or we can just fetch a large default bounds now.
    _fetchUsersInBounds(_sudanBounds);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUsersInBounds(LatLngBounds bounds) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final users = await FirestoreService().getUsersInMapBounds(
        bounds.south - 1.0, // Add some padding so dragging feels seamless
        bounds.north + 1.0,
        bounds.west - 1.0,
        bounds.east + 1.0,
      );
      if (mounted) {
        setState(() {
          _allMapUsers = users;
          _applyFilters(setStateOnly: false);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching map users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMapPositionChanged(MapPosition position, bool hasGesture) {
    if (!hasGesture) return; // Only fetch if user actively moved it
    if (position.bounds == null) return;
    
    // Cancel the previous timer
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    // Start a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      _fetchUsersInBounds(position.bounds!);
    });
  }

  void _applyFilters({bool setStateOnly = true}) {
    final filtered = _allMapUsers.where((user) {
      // Filter by role
      if (_selectedRoleFilter == 'shop' && user.role != UserRole.shop) return false;
      if (_selectedRoleFilter == 'freelancer' && user.role != UserRole.freelancer && user.role != UserRole.techService && user.role != UserRole.privateService) return false;

      // Filter by category (if shop and category is selected)
      if (_selectedShopCategoryFilter != null) {
        if (user.role != UserRole.shop) return false;
        if (user.shopCategory != _selectedShopCategoryFilter) return false;
      }

      return true;
    }).toList();

    if (setStateOnly) {
      setState(() {
        _filteredUsers = filtered;
      });
    } else {
      _filteredUsers = filtered;
    }
  }

  void _showUserPopup(UserModel user) {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user.profileImageUrl != null ? NetworkImage(user.profileImageUrl!) : null,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: user.profileImageUrl == null 
                        ? Icon(user.role == UserRole.shop ? Icons.store : Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        if (user.jobTitle != null)
                          Text(
                            user.jobTitle!,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${user.rating.toStringAsFixed(1)} (${user.completedJobsCount} ${isAr ? 'عمل' : 'jobs'})',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: user.id)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(isAr ? 'زيارة الملف الشخصي' : 'View Profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final locale = context.read<LocaleProvider>().locale.languageCode;
    final isAr = locale == 'ar';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'تصفية الخريطة' : 'Filter Map',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(isAr ? 'عرض:' : 'Show:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    FilterChip(
                      label: Text(isAr ? 'الكل' : 'All'),
                      selected: _selectedRoleFilter == 'all',
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() {
                            _selectedRoleFilter = 'all';
                            _selectedShopCategoryFilter = null;
                          });
                        }
                      },
                    ),
                    FilterChip(
                      label: Text(isAr ? 'المتاجر' : 'Shops'),
                      selected: _selectedRoleFilter == 'shop',
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() => _selectedRoleFilter = 'shop');
                        }
                      },
                    ),
                    FilterChip(
                      label: Text(isAr ? 'الحرفيين' : 'Freelancers'),
                      selected: _selectedRoleFilter == 'freelancer',
                      onSelected: (val) {
                        if (val) {
                          setSheetState(() {
                            _selectedRoleFilter = 'freelancer';
                            _selectedShopCategoryFilter = null;
                          });
                        }
                      },
                    ),
                  ],
                ),
                if (_selectedRoleFilter == 'shop' || _selectedRoleFilter == 'all') ...[
                  const SizedBox(height: 16),
                  Text(isAr ? 'فئة المتجر (اختياري):' : 'Shop Category (Optional):', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<ShopCategory?>(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    value: _selectedShopCategoryFilter,
                    hint: Text(isAr ? 'كل الفئات' : 'All Categories'),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(isAr ? 'كل الفئات' : 'All Categories'),
                      ),
                      ...ShopCategory.values.map((cat) {
                        final dummy = UserModel(
                          id: '', name: '', email: '', role: UserRole.shop,
                          createdAt: DateTime.now(), lastActive: DateTime.now(),
                          updatedAt: DateTime.now(),
                          shopCategory: cat
                        );
                        return DropdownMenuItem(
                          value: cat,
                          child: Text(dummy.getShopCategoryName(locale)),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setSheetState(() {
                        _selectedShopCategoryFilter = val;
                        if (val != null) _selectedRoleFilter = 'shop';
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _applyFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isAr ? 'تطبيق الفلتر' : 'Apply Filter'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.read<LocaleProvider>().locale.languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'مستكشف الخريطة' : 'Map Explorer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _khartoumCenter,
              initialZoom: 6.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              cameraConstraint: CameraConstraint.contain(bounds: _sudanBounds),
              onPositionChanged: _onMapPositionChanged,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sudan.free',
                tileProvider: CachedTileProvider(),
                retinaMode: true,
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  maxZoom: 15,
                  markers: _filteredUsers.map((user) {
                    final isShop = user.role == UserRole.shop;
                    return Marker(
                      point: LatLng(user.latitude!, user.longitude!),
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showUserPopup(user),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isShop ? Colors.amber : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: user.profileImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: user.profileImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Icon(Icons.person, color: Colors.white, size: 24),
                                    errorWidget: (context, url, error) => Icon(isShop ? Icons.store : Icons.work, color: Colors.white, size: 24),
                                  )
                                : Icon(
                                    isShop ? Icons.store : Icons.work,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          
          if (_selectedRoleFilter != 'all' || _selectedShopCategoryFilter != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.filter_alt, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'تم تطبيق الفلتر' : 'Filter applied',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRoleFilter = 'all';
                              _selectedShopCategoryFilter = null;
                              _applyFilters();
                            });
                          },
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_isLoading)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
"""
)
