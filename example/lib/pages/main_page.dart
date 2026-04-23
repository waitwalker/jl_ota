import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jl_ota/ble_event_stream.dart';
import 'package:jl_ota/ble_method.dart';
import 'package:jl_ota_example/pages/setting_page.dart';
import 'package:jl_ota_example/pages/update_page.dart';

import '../extensions/hex_color.dart';
import '../gen/assets.gen.dart';
import '../l10n/app_localizations.dart';
import '../utils/app_util.dart';
import '../widgets/toast_utils.dart';
import 'devices_page.dart';

enum MainPageTab { devices, update, settings }

/// Enumeration representing the different tabs available in the main page
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  MainPageState createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  MainPageTab _currentTab = MainPageTab.devices;
  DateTime? _lastClickTime;
  static const int DOUBLE_CLICK_INTERVAL = 1200; // 双击的时间阈值，单位毫秒
  StreamSubscription<bool>? _mandatoryUpgradeSubscription;

  // Constant for top padding of tab icons
  static const double tabIconTopPadding = 8.0;

  final Map<MainPageTab, Widget> _pages = {MainPageTab.devices: DevicesPage(), MainPageTab.update: UpdatePage(), MainPageTab.settings: SettingPage()};

  @override
  void initState() {
    super.initState();

    _mandatoryUpgradeSubscription = BleEventStream.mandatoryUpgradeStream.listen((isRequired) {
      if (isRequired && mounted) {
        setState(() {
          _currentTab = MainPageTab.update;
          ToastUtils.show(context, AppLocalizations.of(context)!.deviceMustMandatoryUpgrade);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = AppUtil.isAndroid;

    return isAndroid
        ? PopScope(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) async {
              if (didPop) return;

              DateTime nowTime = DateTime.now();

              if (_lastClickTime == null || nowTime.difference(_lastClickTime!) > Duration(milliseconds: DOUBLE_CLICK_INTERVAL)) {
                // 第一次点击或超过间隔时间
                _lastClickTime = nowTime;

                // 显示提示信息
                ToastUtils.show(context, AppLocalizations.of(context)!.pressAgainToExit);
              } else {
                await BleMethod.popAllActivity();
              }
            },
            child: _buildScaffold(),
          )
        : _buildScaffold();
  }

  @override
  void dispose() {
    _mandatoryUpgradeSubscription?.cancel();
    super.dispose();
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: _pages[_currentTab],
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: _currentTab.index,
        activeColor: HexColor.hexColor("#398BFF"),
        inactiveColor: HexColor.hexColor("#929598"),
        iconSize: 28,
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconBtNol2x.path, width: 30, height: 30),
            ),
            activeIcon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconBtSel2x.path, width: 30, height: 30),
            ),
            label: AppLocalizations.of(context)!.connect,
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconUpdateNol2x.path, width: 30, height: 30),
            ),
            activeIcon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconUpdateSel2x.path, width: 30, height: 30),
            ),
            label: AppLocalizations.of(context)!.update,
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconSettleNol2x.path, width: 30, height: 30),
            ),
            activeIcon: Padding(
              padding: const EdgeInsets.only(top: tabIconTopPadding),
              child: Image.asset(Assets.images.icons.tabIconSettleSel2x.path, width: 30, height: 30),
            ),
            label: AppLocalizations.of(context)!.settings,
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentTab = MainPageTab.values[index];
          });
        },
      ),
    );
  }
}
