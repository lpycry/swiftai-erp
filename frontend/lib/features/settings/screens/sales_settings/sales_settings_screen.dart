import 'package:flutter/material.dart';
import 'package:swiftai_erp/core/services/auth_service.dart';
import 'package:swiftai_erp/features/settings/screens/sales_settings/order_type_config_screen.dart';
import 'package:swiftai_erp/features/settings/screens/sales_settings/delivery_block_screen.dart';
import 'package:swiftai_erp/features/settings/screens/sales_settings/carrier_service_screen.dart';

class SalesSettingsScreen extends StatefulWidget {
  final AuthService authService;
  const SalesSettingsScreen({super.key, required this.authService});
  @override State<SalesSettingsScreen> createState() => _SalesSettingsScreenState();
}

class _SalesSettingsScreenState extends State<SalesSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _otcKey = GlobalKey<OrderTypeConfigScreenState>();
  final _dbKey = GlobalKey<DeliveryBlockScreenState>();
  final _csKey = GlobalKey<CarrierServiceScreenState>();

  @override void initState() { super.initState(); _tabCtrl = TabController(length: 3, vsync: this); }
  @override void dispose() { _tabCtrl.dispose(); super.dispose(); }

  void _addCurrent() {
    switch (_tabCtrl.index) {
      case 0: _otcKey.currentState?.triggerCreate(); break;
      case 1: _dbKey.currentState?.triggerCreate(); break;
      case 2: _csKey.currentState?.triggerCreate(); break;
    }
  }

  void _refreshCurrent() {
    switch (_tabCtrl.index) {
      case 0: _otcKey.currentState?.triggerRefresh(); break;
      case 1: _dbKey.currentState?.triggerRefresh(); break;
      case 2: _csKey.currentState?.triggerRefresh(); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Settings'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addCurrent, tooltip: 'Add'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshCurrent),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Order Types', icon: Icon(Icons.category_outlined, size: 16)),
            Tab(text: 'Delivery Blocks', icon: Icon(Icons.block, size: 16)),
            Tab(text: 'Carriers', icon: Icon(Icons.local_shipping, size: 16)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          OrderTypeConfigScreen(key: _otcKey, authService: widget.authService),
          DeliveryBlockScreen(key: _dbKey, authService: widget.authService),
          CarrierServiceScreen(key: _csKey, authService: widget.authService),
        ],
      ),
    );
  }
}
