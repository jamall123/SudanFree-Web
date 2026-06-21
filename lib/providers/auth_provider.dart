import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/device_service.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/cache_service.dart';
import 'user_provider.dart';
import 'posts_provider.dart';
import '../services/notification_service.dart';
import '../services/notification_polling_service.dart';
import '../services/network_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  String? _verificationId;
  bool _isNewUser = false;
  bool _isLoadingProfile = false;
  bool _isManualSignIn = false;
  StreamSubscription?
      _authSubscription; // Fix: track auth stream to cancel on dispose
  StreamSubscription<UserModel?>? _userSubscription;
  StreamSubscription<bool>? _networkSubscription;

  // Partners
  List<UserModel> _partners = [];

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isNewUser => _isNewUser;
  String? get userId => _authService.currentUserId;
  List<UserModel> get partners => _partners; // Added getter
  bool get isManualSignIn => _isManualSignIn; // Added for smooth UI transitions



  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    _networkSubscription?.cancel();
    super.dispose();
  }

  // Toggle Partner (Add/Remove Colleague)
  Future<void> sendPartnerRequest(String targetId) async {
    if (_user == null) return;

    // Prevent if already partner or already pending
    if (_user!.partnerIds.contains(targetId) ||
        _user!.pendingPartnerIds.contains(targetId)) {
      return;
    }

    try {
      await _firestoreService.sendPartnerRequest(
          _user!.id, _user!.name, targetId);
      // Wait for stream update instead of optimistic
    } catch (e) {
      debugPrint('Error sending partner request: $e');
    }
  }

  // Handle Partner Request (Accept/Decline)
  Future<void> handlePartnerRequest(String requesterId, bool accept,
      {UserModel? requester}) async {
    if (_user == null) return;

    try {
      await _firestoreService.handlePartnerRequest(
          _user!.id, _user!.name, requesterId, accept);

      final updatedPending = List<String>.from(_user!.pendingPartnerIds);
      updatedPending.remove(requesterId);

      final updatedPartners = List<String>.from(_user!.partnerIds);
      if (accept && !updatedPartners.contains(requesterId)) {
        updatedPartners.add(requesterId);
      }

      _user = _user!.copyWith(
        pendingPartnerIds: updatedPending,
        partnerIds: updatedPartners,
      );

      if (accept && requester != null) {
        final existing =
            _partners.where((user) => user.id == requester.id).isNotEmpty;
        if (!existing) {
          _partners.add(requester);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error handling partner request: $e');
      rethrow;
    }
  }

  // Remove Partner (Cancel Request / Remove Colleague)
  Future<void> removePartner(String targetId) async {
    if (_user == null) return;
    try {
      await _firestoreService.removePartner(_user!.id, targetId);

      final updatedPartners = List<String>.from(_user!.partnerIds);
      updatedPartners.remove(targetId);
      
      final updatedPending = List<String>.from(_user!.pendingPartnerIds);
      updatedPending.remove(targetId);

      _user = _user!.copyWith(
        partnerIds: updatedPartners,
        pendingPartnerIds: updatedPending,
      );

      _partners.removeWhere((p) => p.id == targetId);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing partner: $e');
      rethrow;
    }
  }

  // Toggle Favorite User
  Future<void> toggleFavoriteUser(String targetUserId) async {
    if (_user == null) return;
    try {
      final updatedFavorites = List<String>.from(_user!.favoriteUserIds);
      if (updatedFavorites.contains(targetUserId)) {
        updatedFavorites.remove(targetUserId);
      } else {
        updatedFavorites.add(targetUserId);
      }
      
      _user = _user!.copyWith(favoriteUserIds: updatedFavorites);
      await _firestoreService.updateUserProfile(_user!.id, {'favoriteUserIds': updatedFavorites});
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite user: $e');
      refreshUserProfile(); // rollback on error
    }
  }

  // Toggle Favorite Product
  Future<void> toggleFavoriteProduct(String productId) async {
    if (_user == null) return;
    try {
      final updatedFavorites = List<String>.from(_user!.favoriteProductIds);
      if (updatedFavorites.contains(productId)) {
        updatedFavorites.remove(productId);
      } else {
        updatedFavorites.add(productId);
      }
      
      _user = _user!.copyWith(favoriteProductIds: updatedFavorites);
      await _firestoreService.updateUserProfile(_user!.id, {'favoriteProductIds': updatedFavorites});
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite product: $e');
      refreshUserProfile(); // rollback on error
    }
  }

  // Toggle Favorite Squad
  Future<void> toggleFavoriteSquad(String squadId) async {
    if (_user == null) return;
    try {
      final updatedFavorites = List<String>.from(_user!.favoriteSquadIds);
      if (updatedFavorites.contains(squadId)) {
        updatedFavorites.remove(squadId);
      } else {
        updatedFavorites.add(squadId);
      }
      
      _user = _user!.copyWith(favoriteSquadIds: updatedFavorites);
      await _firestoreService.updateUserProfile(_user!.id, {'favoriteSquadIds': updatedFavorites});
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite squad: $e');
      refreshUserProfile(); // rollback on error
    }
  }

  // Fetch My Partners & Followed Shops
  Future<void> fetchPartners({bool forceRefresh = false}) async {
    if (_user == null) {
      _partners = [];
      notifyListeners();
      return;
    }

    // Merge partners and followed shops
    final Set<String> combinedIds = {..._user!.partnerIds, ..._user!.following};

    if (combinedIds.isEmpty) {
      _partners = [];
      notifyListeners();
      return;
    }

    if (!forceRefresh && _partners.isNotEmpty) {
      // If we already have them and it's not a forced refresh, just return
      return;
    }

    try {
      _partners = await _firestoreService.getUsersByIds(combinedIds.toList());
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching partners/following: $e');
    }
  }

  // Initialize auth state
  Future<void> initialize() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _cacheService.initialize();

      _authSubscription = _authService.authStateChanges.listen((User? user) {
        _handleAuthStateChange(user);
      }, onError: (error) {
        debugPrint('Auth provider stream error: $error');
      });

      // Listen to network changes to recover from offline app launch
      _networkSubscription = NetworkService().onConnectivityChanged.listen((isConnected) {
        if (isConnected && _authService.currentUser != null) {
          // If we had an error loading the profile (e.g. launched offline), retry loading it
          if (_status == AuthStatus.error || (_status == AuthStatus.unauthenticated && _user == null)) {
            debugPrint('Network recovered. Retrying to load user profile...');
            _handleAuthStateChange(_authService.currentUser);
          }
        }
      });
    } catch (e) {
      debugPrint('Auth provider initialization error: $e');
      _status = AuthStatus.unauthenticated;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _isNewUser = false;
      _isLoadingProfile = false;
      _userSubscription?.cancel();
      _userSubscription = null;
      notifyListeners();
      return;
    }

    // Skip if a manual sign-in method (Google/Email) is already handling state
    if (_isManualSignIn) return;

    // prevent redundant loading if already authenticated with same user
    if (_status == AuthStatus.authenticated &&
        (_user?.id == firebaseUser.uid || _isNewUser)) {
      return;
    }

    // prevent multiple concurrent loads
    if (_isLoadingProfile) return;
    _isLoadingProfile = true;

    _status = AuthStatus.loading;
    notifyListeners();
    await _loadUserData(firebaseUser.uid);
    _isLoadingProfile = false;

    // Sync FCM Token
    _syncFCMToken(firebaseUser.uid);
  }

  Future<void> _syncFCMToken(String uid) async {
    try {
      // Only sync if a profile exists in Firestore
      // (new users don't have a doc yet — createUserProfile hasn't run)
      final profileExists = await _authService.userProfileExists(uid);
      if (!profileExists) return;

      final token = await NotificationService().getToken();
      if (token != null) {
        await _authService.updateFCMToken(uid, token);
      }
    } catch (e) {
      debugPrint('AuthProvider: FCM token sync failed (non-fatal): $e');
    }
  }

  Future<void> _loadUserData(String uid) async {
    try {
      final profile = await _authService.getUserProfile(uid);
      if (profile != null) {
        if (profile.isBanned) {
          await _authService.signOut();
          _user = null;
          _status = AuthStatus.error;
          _errorMessage = 'BANNED:${profile.banReason ?? "مخالفة الشروط والأحكام"}';
          notifyListeners();
          return;
        }

        _user = profile;
        _isNewUser = false;

        // OneSignal User Tagging (modern API)
        try {
          await OneSignal.login(uid);
          await OneSignal.User.addTags({
            "state": profile.state ?? '',
            "role": profile.role.name,
          });
        } catch (e) {
          debugPrint('OneSignal tagging failed: $e');
        }

        _subscribeToUserStream(uid);
      } else {
        _isNewUser = true;
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading user data: $e');
      _status = AuthStatus.error;
      notifyListeners();
    }
  }

  void _subscribeToUserStream(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _firestoreService.getUserStream(uid).listen(
      (profile) async {
        if (profile != null) {
          if (profile.isBanned) {
            await _authService.signOut();
            _user = null;
            _status = AuthStatus.error;
            _errorMessage = 'BANNED:${profile.banReason ?? "مخالفة الشروط والأحكام"}';
            notifyListeners();
            return;
          }
          _user = profile;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('AuthProvider user stream error: $error');
      },
    );
  }

  // Sign up with email
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _isManualSignIn = true; // منع _handleAuthStateChange من التدخل
    notifyListeners();

    try {
      await _authService.signUpWithEmail(
        email: email,
        password: password,
      );
      _isNewUser = true;
      _isManualSignIn = false;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _isManualSignIn = false;
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _isManualSignIn = true;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) {
        // User cancelled
        _status = AuthStatus.unauthenticated;
        _isManualSignIn = false;
        notifyListeners();
        return false;
      }

      // Load user data directly to ensure immediate state update
      if (credential.user != null) {
        // Check device ban
        final banReason = await _deviceService.checkDeviceBan();
        if (banReason != null) {
          await _authService.signOut();
          _status = AuthStatus.error;
          _errorMessage = 'DEVICE_BANNED:$banReason';
          _isManualSignIn = false;
          notifyListeners();
          return false;
        }
        await _loadUserData(credential.user!.uid);
        _syncFCMToken(credential.user!.uid);
      }
      _isManualSignIn = false;
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      _isManualSignIn = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with Facebook
  Future<bool> signInWithFacebook() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _isManualSignIn = true;
    notifyListeners();

    try {
      final credential = await _authService.signInWithFacebook();
      if (credential == null) {
        // User cancelled
        _status = AuthStatus.unauthenticated;
        _isManualSignIn = false;
        notifyListeners();
        return false;
      }

      // Load user data directly to ensure immediate state update
      if (credential.user != null) {
        // Check device ban
        final banReason = await _deviceService.checkDeviceBan();
        if (banReason != null) {
          await _authService.signOut();
          _status = AuthStatus.error;
          _errorMessage = 'DEVICE_BANNED:$banReason';
          _isManualSignIn = false;
          notifyListeners();
          return false;
        }
        await _loadUserData(credential.user!.uid);
        _syncFCMToken(credential.user!.uid);
      }
      _isManualSignIn = false;
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      _isManualSignIn = false;
      notifyListeners();
      return false;
    }
  }

  // Sign in with email
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _isManualSignIn = true;
    notifyListeners();

    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      // Load user data directly instead of relying on _handleAuthStateChange
      if (credential.user != null) {
        // Check device ban
        final banReason = await _deviceService.checkDeviceBan();
        if (banReason != null) {
          await _authService.signOut();
          _status = AuthStatus.error;
          _errorMessage = 'DEVICE_BANNED:$banReason';
          _isManualSignIn = false;
          notifyListeners();
          return false;
        }
        await _loadUserData(credential.user!.uid);
        _syncFCMToken(credential.user!.uid);
      }
      _isManualSignIn = false;
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      _isManualSignIn = false;
      notifyListeners();
      return false;
    }
  }

  // Send phone verification
  Future<bool> sendPhoneVerification(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onVerificationCompleted: (credential) async {
          // Auto sign-in
          await _handlePhoneSignIn(credential);
        },
        onVerificationFailed: (e) {
          _status = AuthStatus.error;
          _errorMessage = e.message;
          notifyListeners();
        },
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _status = AuthStatus.unauthenticated;
          notifyListeners();
        },
        onCodeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'رمز التحقق غير موجود';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.verifyOTPAndSignIn(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      await _handlePhoneSignIn(PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      ));

      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Verify OTP and Link (For existing users verifying identity)
  Future<bool> verifyOTPAndLink(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'رمز التحقق غير موجود';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.linkPhoneCredential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );

      // Verification successful, status will be updated in Firestore by the caller
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Send WhatsApp OTP
  Future<bool> sendWhatsAppOTP(String phoneNumber) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _firestoreService.callFunction('sendWhatsAppOTP', {
        'phoneNumber': phoneNumber,
      });

      if (result['success'] == true) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] ?? 'Failed to send WhatsApp OTP';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Verify WhatsApp OTP
  Future<bool> verifyWhatsAppOTP(String phoneNumber, String otp) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _firestoreService.callFunction('verifyWhatsAppOTP', {
        'phoneNumber': phoneNumber,
        'otp': otp,
      });

      if (result['success'] == true) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.error;
        _errorMessage = result['message'] ?? 'Invalid OTP';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _handlePhoneSignIn(PhoneAuthCredential credential) async {
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final profile = await _authService.getUserProfile(userCredential.user!.uid);

    if (profile != null) {
      _user = profile;
      _isNewUser = false;
    } else {
      _isNewUser = true;
    }

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  // Create user profile
  Future<bool> createUserProfile({
    required String name,
    required UserRole role,
    String? bio,
    String? phoneNumber,
    String? state,
    String? locality,
    List<String>? skills,
    double? hourlyRate,
    ShopCategory? shopCategory,
    String? jobTitle,
    String? openingHours,
    String? closingHours,
    List<String>? shopInterests,
    List<String>? serviceInterests,
    double? latitude,
    double? longitude,
  }) async {
    // Don't set status=loading here — it triggers app.dart to rebuild
    // and show SplashScreen, which unmounts ProfileSetupScreen mid-operation.
    _errorMessage = null;

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('لم يتم تسجيل الدخول');
      }

      final now = DateTime.now();
      debugPrint(
          'AuthProvider.createUserProfile: saving role=${role.name} for uid=${currentUser.uid}');
      final user = UserModel(
        id: currentUser.uid,
        email: currentUser.email ?? '',
        phoneNumber: phoneNumber ?? currentUser.phoneNumber,
        name: name,
        role: role,
        bio: bio,
        jobTitle: jobTitle,
        skills: skills ?? [],
        hourlyRate: hourlyRate,
        state: state,
        locality: locality,
        shopCategory: shopCategory,
        openingHours: openingHours,
        closingHours: closingHours,
        whatsappNumber: phoneNumber ?? currentUser.phoneNumber,
        shopInterests: shopInterests ?? [],
        serviceInterests: serviceInterests ?? [],
        latitude: latitude,
        longitude: longitude,
        createdAt: now,
        updatedAt: now,
      );

      await _authService.createUserProfile(user);
      debugPrint(
          'AuthProvider.createUserProfile: Firestore write complete. role=${role.name}');
      await _deviceService.saveDeviceIdToUser(user.id);

      // ✅ Ensure FCM Token is saved BEFORE sending the welcome notification
      await _syncFCMToken(user.id);

      // ✅ Send Welcome Notification
      try {
        String welcomeTitle = 'مرحباً بك في سودان فري! 🎉';
        String welcomeMessage = 'شكراً لانضمامك إلينا.';

        switch (role) {
          case UserRole.client:
            welcomeMessage =
                'يمكنك الآن الوصول إلى أمهر مقدمي الخدمات وتصفح أفضل المعارض والمحلات في السودان.';
            break;
          case UserRole.freelancer:
          case UserRole.techService:
          case UserRole.privateService:
            welcomeTitle = 'مرحباً بك كمقدم خدمة! 🛠️';
            welcomeMessage =
                'الآن يمكن للعملاء الوصول إليك وطلب خدماتك بسهولة وزيادة دخلك.';
            break;
          case UserRole.shop:
            welcomeTitle = 'مرحباً بك صاحب معرض! 🏪';
            welcomeMessage =
                'يمكنك الآن البدء بعرض منتجاتك وجذب العملاء لمعرضك ومحلك التجاري.';
            break;
          case UserRole.admin:
            welcomeTitle = 'مرحباً بك كمسؤول! 🛡️';
            welcomeMessage = 'تم تسجيل دخولك كمدير للنظام.';
            break;
        }

        final notification = NotificationModel(
          id: '',
          userId: user.id,
          type: NotificationType.system,
          title: welcomeTitle,
          message: welcomeMessage,
          createdAt: Timestamp.now(),
        );

        await _firestoreService.sendNotification(notification);
      } catch (notifErr) {
        debugPrint(
            'AuthProvider: Welcome notification failed (non-fatal): $notifErr');
      }

      _user = user;
      _isNewUser = false;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      // Don't set status=error — that causes app.dart to show LoginScreen.
      // Keep authenticated status so user stays on ProfileSetupScreen.
      _errorMessage = e.toString();
      debugPrint('AuthProvider: createUserProfile failed: $e');
      notifyListeners();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    if (_user == null || userId == null) return false;

    try {
      await _authService.updateUserProfile(userId!, data);

      // Refresh user profile
      final updatedProfile = await _authService.getUserProfile(userId!);
      if (updatedProfile != null) {
        _user = updatedProfile;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Toggle User Role (Client <-> Freelancer)
  Future<bool> toggleUserRole() async {
    if (_user == null) return false;

    final newRole =
        _user!.role == UserRole.client ? UserRole.freelancer : UserRole.client;

    return await updateUserProfile({'role': newRole.name});
  }

  // Toggle Availability Status (For Freelancers)
  Future<bool> toggleAvailability() async {
    if (_user == null) return false;

    final newStatus = !_user!.isAvailable;
    return await updateUserProfile({'isAvailable': newStatus});
  }

  // Toggle Map Visibility Status (For Freelancers and Shops)
  Future<bool> toggleShowOnMap() async {
    if (_user == null) return false;

    final newStatus = !_user!.showOnMap;
    return await updateUserProfile({'showOnMap': newStatus});
  }

  // Update user's GPS Location for Map
  Future<bool> updateLocation(double lat, double lng, {String? state, String? locality}) async {
    if (_user == null) return false;
    
    final updates = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
    };
    
    if (state != null) updates['state'] = state;
    if (locality != null) updates['locality'] = locality;
    
    return await updateUserProfile(updates);
  }

  // Toggle Push Notifications
  Future<bool> togglePushNotifications(bool enabled) async {
    if (_user == null) return false;

    try {
      final updatedSettings =
          Map<String, bool>.from(_user!.notificationSettings);
      updatedSettings['pushEnabled'] = enabled;

      await updateUserProfile({'notificationSettings': updatedSettings});

      try {
        if (enabled) {
          await OneSignal.User.pushSubscription.optIn();
        } else {
          await OneSignal.User.pushSubscription.optOut();
        }
      } catch (e) {
        debugPrint('OneSignal toggle push failed: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Error toggling push notifications: $e');
      return false;
    }
  }

  // Request Account Deletion
  Future<bool> requestAccountDeletion(String reason) async {
    _errorMessage = null;

    try {
      await FirebaseFirestore.instance.collection('deletion_requests').add({
        'userId': _user!.id,
        'name': _user!.name,
        'email': _user!.email,
        'reason': reason,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Refresh user profile
  Future<void> refreshUserProfile() async {
    if (userId == null) return;

    try {
      final profile = await _authService.getUserProfile(userId!);
      if (profile != null) {
        _user = profile;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  // Reset password
  Future<bool> resetPassword(String email) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Sign out
  Future<void> signOut(BuildContext context) async {
    // Clear only registered providers (JobProvider & ChatProvider are frozen)
    try {
      context.read<UserProvider>().clear();
      context.read<PostsProvider>().clear();
    } catch (e) {
      debugPrint('AuthProvider: Error clearing providers: $e');
    }

    // Reset notification streams to prevent stale data
    NotificationPollingService().reset();

    await _authService.signOut();
    try {
      await OneSignal.logout();
    } catch (e) {
      debugPrint('OneSignal logout failed: $e');
    }
    await _cacheService.clearAllData();
    _user = null;
    _isNewUser = false;
    _partners = [];
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // Delete Account
  Future<bool> deleteAccount() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.deleteUser();
      await _cacheService.clearUserCache();
      _user = null;
      _isNewUser = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // Set error message
  void setErrorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }
}
