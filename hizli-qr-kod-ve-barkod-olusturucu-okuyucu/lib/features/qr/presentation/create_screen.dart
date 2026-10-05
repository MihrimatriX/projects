import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_layout.dart';
import '../../../core/widgets/app_sub_tabs.dart';
import '../widgets/barcode_panel.dart';
import '../widgets/batch_panel.dart';
import 'qr_tab_content.dart';

class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({
    super.key,
    this.initialText,
    this.initialTab = 0,
    this.showBackButton = false,
  });

  final String? initialText;
  final int initialTab;
  final bool showBackButton;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      showHeader: !widget.showBackButton,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showBackButton)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          AppSubTabs(
            controller: _tabs,
            tabs: const ['QR', 'Barkod', 'Toplu'],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                QrTabContent(initialText: widget.initialText),
                const BarcodePanel(),
                const BatchPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
