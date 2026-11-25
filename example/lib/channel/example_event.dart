import 'package:flutter/services.dart';
import 'package:jl_ota/constant/ble_event_constants.dart';

import 'example_channel_constants.dart';

/// Example-only events: logs, download, local upgrade files, custom command.
class ExampleEvent {
  static const EventChannel _eventChannel = EventChannel('com.jieli.otasdk.example/events');
  static Stream<dynamic>? _baseStream;

  static Stream<dynamic> get baseStream {
    _baseStream ??= _eventChannel.receiveBroadcastStream();
    return _baseStream!;
  }

  static Stream<List<Map<String, String>>> get logFilesStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == ExampleChannelConstants.typeLogFiles).map((event) {
      final files = event[ExampleChannelConstants.keyFiles] as List? ?? [];
      return files.whereType<Map>().map((fileMap) => {BleEventConstants.KEY_NAME: fileMap[BleEventConstants.KEY_NAME] as String? ?? ''}).toList();
    });
  }

  static Stream<String> get logDetailFilesStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == ExampleChannelConstants.typeLogDetailFiles).map((event) {
      final files = event[ExampleChannelConstants.keyFiles] as List? ?? [];
      return files.first as String? ?? '';
    });
  }

  static Stream<Map<String, dynamic>> get downloadStatusStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == ExampleChannelConstants.typeDownloadStatus).map((event) {
      final data = event[BleEventConstants.KEY_VALUE];
      return {
        BleEventConstants.KEY_STATUS: data[BleEventConstants.KEY_STATUS],
        BleEventConstants.KEY_PROGRESS: data[BleEventConstants.KEY_PROGRESS],
        BleEventConstants.KEY_MESSAGE: data[BleEventConstants.KEY_MESSAGE],
      };
    });
  }

  static Stream<List<Map<String, String>>> get otaFileListStream {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == ExampleChannelConstants.typeOtaFileList).map((event) {
      final list = event[BleEventConstants.KEY_VALUE][BleEventConstants.KEY_LIST] as List? ?? [];
      return list
          .whereType<Map>()
          .map(
            (fileMap) => {
              BleEventConstants.KEY_NAME: fileMap[BleEventConstants.KEY_NAME] as String? ?? '',
              BleEventConstants.KEY_PATH: fileMap[BleEventConstants.KEY_PATH] as String? ?? '',
            },
          )
          .toList();
    });
  }

  static Stream<Uint8List> get customCommandData {
    return baseStream.where((event) => event is Map && event[BleEventConstants.KEY_TYPE] == ExampleChannelConstants.typeCustomCommandData).map((
      event,
    ) {
      try {
        final data = event[BleEventConstants.KEY_VALUE] as Map?;
        if (data == null) return Uint8List(0);
        final customData = data[ExampleChannelConstants.keyCustomData];
        if (customData is List<int>) return Uint8List.fromList(customData);
        if (customData is List) {
          final List<int> result = [];
          for (final element in customData) {
            if (element is int) {
              result.add(element);
            } else if (element is num) {
              result.add(element.toInt());
            } else {
              return Uint8List(0);
            }
          }
          return Uint8List.fromList(result);
        }
        return Uint8List(0);
      } catch (e) {
        return Uint8List(0);
      }
    });
  }
}
