import 'package:flutter/material.dart';

class KeepAliveTabView extends StatefulWidget {
  final Widget child;

  const KeepAliveTabView({super.key, required this.child});

  @override
  State<KeepAliveTabView> createState() => _KeepAliveTabViewState();
}

class _KeepAliveTabViewState extends State<KeepAliveTabView>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
