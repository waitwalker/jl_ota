import 'package:flutter/material.dart';
import 'package:jl_ota/constant/constants.dart';
import '../l10n/app_localizations.dart';

/// Page for sharing firmware files for OTA updates.
class FileSharePage extends StatefulWidget {
  const FileSharePage({super.key});

  @override
  State<FileSharePage> createState() => _FileSharePageState();
}

class _FileSharePageState extends State<FileSharePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.fileShare,
          style: TextStyle(color: Color(0xFF242424), fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Image.asset(
            'assets/images/ic_return.png',
            width: AppConstants.returnIconSizeValue, // 设置图片宽度为28
            height: AppConstants.returnIconSizeValue, // 设置图片高度为28
          ),
          onPressed: () {
            Navigator.of(context).pop(); // 返回上一页
          },
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 24),
            Text(
              loc.shareUfwFile,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF242424)),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                loc.shareUfwFileTips,
                style: TextStyle(fontSize: 16, fontFamily: 'PingFangSC', color: Color(0xFF919191)),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset('assets/file_share.gif', fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }
}
