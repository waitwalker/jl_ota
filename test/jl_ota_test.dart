// import 'package:flutter_test/flutter_test.dart';
// import 'package:jl_ota/jl_ota.dart';
// import 'package:jl_ota/jl_ota_platform_interface.dart';
// import 'package:jl_ota/jl_ota_method_channel.dart';
// import 'package:plugin_platform_interface/plugin_platform_interface.dart';
//
// class MockJlOtaPlatform
//     with MockPlatformInterfaceMixin
//     implements JlOtaPlatform {
//
//   @override
//   Future<String?> getPlatformVersion() => Future.value('42');
// }
//
// void main() {
//   final JlOtaPlatform initialPlatform = JlOtaPlatform.instance;
//
//   test('$MethodChannelJlOta is the default instance', () {
//     expect(initialPlatform, isInstanceOf<MethodChannelJlOta>());
//   });
//
//   test('getPlatformVersion', () async {
//     JlOta jlOtaPlugin = JlOta();
//     MockJlOtaPlatform fakePlatform = MockJlOtaPlatform();
//     JlOtaPlatform.instance = fakePlatform;
//
//     expect(await jlOtaPlugin.getPlatformVersion(), '42');
//   });
// }
