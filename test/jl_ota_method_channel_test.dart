// import 'package:flutter/services.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:jl_ota/jl_ota_method_channel.dart';
//
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//
//   MethodChannelJlOta platform = MethodChannelJlOta();
//   const MethodChannel channel = MethodChannel('jl_ota');
//
//   setUp(() {
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
//       channel,
//       (MethodCall methodCall) async {
//         return '42';
//       },
//     );
//   });
//
//   tearDown(() {
//     TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
//   });
//
//   test('getPlatformVersion', () async {
//     expect(await platform.getPlatformVersion(), '42');
//   });
// }
