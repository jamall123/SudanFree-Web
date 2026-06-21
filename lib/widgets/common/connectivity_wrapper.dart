import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../core/constants/app_colors.dart';
import 'dart:async';
import 'dart:ui';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _hasConnection = true;
  bool _wasOffline = false;
  bool _showBanner = false;
  bool _isRestoredState = false;
  Timer? _hideTimer;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitialConnection();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results);
    });
  }

  Future<void> _checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results, isInitial: true);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results,
      {bool isInitial = false}) {
    bool hasConnection = !results.contains(ConnectivityResult.none);
    if (_hasConnection != hasConnection) {
      setState(() {
        _hasConnection = hasConnection;
        if (!hasConnection) {
          _wasOffline = true;
          _showBanner = true;
          _isRestoredState = false;
          _startHideTimer(7);
        } else if (_wasOffline && !isInitial) {
          _wasOffline = false;
          _showBanner = true;
          _isRestoredState = true;
          _startHideTimer(5);
        } else {
          _showBanner = false;
        }
      });
    }
  }

  void _startHideTimer(int seconds) {
    _hideTimer?.cancel();
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) {
        setState(() {
          _showBanner = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.watch<LocaleProvider>().isArabic
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Stack(
        children: [
          widget.child,
          if (_showBanner)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Dismissible(
                key: ValueKey('network_banner_$_isRestoredState'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) {
                  setState(() => _showBanner = false);
                  _hideTimer?.cancel();
                },
                child: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: _isRestoredState
                              ? Colors.green.withValues(alpha: 0.85)
                              : AppColors.error.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isRestoredState ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _isRestoredState
                                    ? (context.read<LocaleProvider>().isArabic
                                        ? 'تم استعادة الإنترنت'
                                        : 'Internet restored')
                                    : (context.read<LocaleProvider>().isArabic
                                        ? 'أنت غير متصل. سيتم مزامنة بياناتك وتفاعلاتك تلقائياً'
                                        : 'Offline. Your data will sync automatically when connected'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
