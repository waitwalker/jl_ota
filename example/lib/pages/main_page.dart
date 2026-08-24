import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota_example/pages/setting_page.dart';
import 'package:jl_ota_example/pages/update_page.dart';

import '../gen/assets.gen.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_util.dart';
import '../widgets/toast_utils.dart';
import 'devices_page.dart';

/// Enumeration representing the different tabs available in the main page
enum MainPageTab { devices, update, settings }

/// Constants for the main page
class MainPageConstants {
  /// Top padding for tab icons
  static const double tabIconTopPadding = 8.0;

  /// Size of tab icons
  static const double tabIconSize = 30.0;

  /// Size of tab bar icons
  static const double iconSize = 28.0;

  /// Active tab color
  static const Color activeColor = Color(0xFF398BFF);

  /// Inactive tab color
  static const Color inactiveColor = Color(0xFF929598);

  /// Background color of tab bar
  static const Color backgroundColor = Colors.white;

  /// Double click interval for Android back button (milliseconds)
  static const int doubleClickInterval = 1200;
}

/// Main page with bottom navigation bar
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  MainPageTab _currentTab = MainPageTab.devices;
  DateTime? _lastClickTime;
  StreamSubscription<bool>? _mandatoryUpgradeSubscription;

  final Map<MainPageTab, Widget> _pages = {
    MainPageTab.devices: const DevicesPage(),
    MainPageTab.update: const UpdatePage(),
    MainPageTab.settings: const SettingPage(),
  };

  @override
  void initState() {
    super.initState();
    _subscribeToMandatoryUpgrade();
  }

  @override
  void dispose() {
    _mandatoryUpgradeSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToMandatoryUpgrade() {
    _mandatoryUpgradeSubscription = BleEventStream.mandatoryUpgradeStream.listen((isRequired) {
      if (isRequired && mounted) {
        setState(() {
          _currentTab = MainPageTab.update;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppUtil.isAndroid ? _buildAndroidScaffold() : _buildCupertinoScaffold();
  }

  Widget _buildAndroidScaffold() {
    return PopScope(canPop: false, onPopInvokedWithResult: _handleAndroidBackPress, child: _buildScaffold());
  }

  Widget _buildCupertinoScaffold() {
    return _buildScaffold();
  }

  Future<void> _handleAndroidBackPress(bool didPop, Object? result) async {
    if (didPop) return;

    final now = DateTime.now();
    final isDoubleClick = _lastClickTime != null && now.difference(_lastClickTime!).inMilliseconds < MainPageConstants.doubleClickInterval;

    if (!isDoubleClick) {
      _lastClickTime = now;
      ToastUtils.show(context, AppLocalizations.of(context)!.pressAgainToExit);
    } else {
      await BleMethod.popAllActivity();
    }
  }

  Widget _buildScaffold() {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: _pages[_currentTab],
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentTab.index,
        activeColor: MainPageConstants.activeColor,
        inactiveColor: MainPageConstants.inactiveColor,
        iconSize: MainPageConstants.iconSize,
        backgroundColor: MainPageConstants.backgroundColor,
        items: _buildTabItems(loc),
        onTap: (index) {
          setState(() {
            _currentTab = MainPageTab.values[index];
          });
        },
      ),
    );
  }

  List<BottomNavigationBarItem> _buildTabItems(AppLocalizations loc) {
    return [
      _buildTabItem(iconAsset: Assets.images.icons.tabIconBtNol2x.path, activeIconAsset: Assets.images.icons.tabIconBtSel2x.path, label: loc.connect),
      _buildTabItem(
        iconAsset: Assets.images.icons.tabIconUpdateNol2x.path,
        activeIconAsset: Assets.images.icons.tabIconUpdateSel2x.path,
        label: loc.update,
      ),
      _buildTabItem(
        iconAsset: Assets.images.icons.tabIconSettleNol2x.path,
        activeIconAsset: Assets.images.icons.tabIconSettleSel2x.path,
        label: loc.settings,
      ),
    ];
  }

  BottomNavigationBarItem _buildTabItem({required String iconAsset, required String activeIconAsset, required String label}) {
    return BottomNavigationBarItem(icon: _buildTabIcon(iconAsset), activeIcon: _buildTabIcon(activeIconAsset), label: label);
  }

  Widget _buildTabIcon(String assetPath) {
    return Padding(
      padding: const EdgeInsets.only(top: MainPageConstants.tabIconTopPadding),
      child: Image.asset(assetPath, width: MainPageConstants.tabIconSize, height: MainPageConstants.tabIconSize),
    );
  }
}
