import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jl_ota/model/scan_device.dart';
import 'package:jl_ota_example/extensions/hex_color.dart';
import 'package:jl_ota_example/l10n/app_localizations.dart';
import 'connect_list_item.dart';

/// This widget is designed to show a list of [ScanDevice] objects.
class ConnectListView extends StatelessWidget {
  final List<ScanDevice> devices;
  final Function(ScanDevice) onTap;
  final bool isShowLoading;

  const ConnectListView({required this.devices, required this.isShowLoading, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 标题部分
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.deviceList,
                style: TextStyle(fontSize: 15, color: HexColor.hexColor("#838383"), fontFamily: 'PingFangSC-Medium'),
              ),
              const SizedBox(width: 10),
              if (isShowLoading) const CupertinoActivityIndicator(color: Colors.grey),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true, // 重要：允许嵌套在ListView中
          physics: const NeverScrollableScrollPhysics(), // 禁止内部滚动
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return ConnectListItem(device: device, onTap: onTap);
          },
        ),
      ],
    );
  }
}
