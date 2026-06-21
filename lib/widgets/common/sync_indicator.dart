import 'package:flutter/material.dart';

import '../../services/network_service.dart';

/// مؤشر لحالة المزامنة والاتصال بالإنترنت
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkService().onConnectivityChanged,
      initialData: NetworkService().isConnected,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isOnline ? 0 : 28,
          color: Colors.orange.shade800,
          alignment: Alignment.center,
          child: isOnline
              ? const SizedBox.shrink()
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 14),
                    SizedBox(width: 8),
                    Text(
                      'أنت في وضع عدم الاتصال. سيتم مزامنة بياناتك لاحقاً.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
