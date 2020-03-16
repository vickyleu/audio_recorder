import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class AudioRecorder {
  static const MethodChannel _channel = const MethodChannel('audio_recorder');

  /// use [LocalFileSystem] to permit widget testing
  static LocalFileSystem fs = LocalFileSystem();

  static StreamController<int> _streamController = StreamController.broadcast();
  static StreamController<double> _streamController2 = StreamController
      .broadcast();

  static Stream<int> amplitudeStream = _streamController.stream;
  static Stream<double> durationStream = _streamController2.stream;

  static Future start(
      {String path, AudioOutputFormat audioOutputFormat}) async {
    String extension;
    if (path != null) {
      if (audioOutputFormat != null) {
        if (_convertStringInAudioOutputFormat(p.extension(path)) !=
            audioOutputFormat) {
          extension = _convertAudioOutputFormatInString(audioOutputFormat);
          path += extension;
        } else {
          extension = p.extension(path);
        }
      } else {
        if (_isAudioOutputFormat(p.extension(path))) {
          extension = p.extension(path);
        } else {
          extension = ".m4a"; // default value
          path += extension;
        }
      }
      File file = fs.file(path);
      if (await file.exists()) {
        throw new Exception("A file already exists at the path :" + path);
      } else if (!await file.parent.exists()) {
        throw new Exception("The specified parent directory does not exist");
      }
    } else {
      extension = ".m4a"; // default value
    }
    _channel.setMethodCallHandler((call) {
      print("setMethodCallHandler==>${call.method}");
      switch (call.method) {
        case "onAmplitude":
          Map<dynamic, dynamic> arg = Map.of(call.arguments);
          int amplitude = arg["amplitude"];
          print("setMethodCallHandler==>${amplitude}");
          _streamController.add(amplitude);
          break;
        case "onDuration":
          Map<dynamic, dynamic> arg = Map.of(call.arguments);
          double duration = arg["duration"];
          print("setMethodCallHandler==>${duration}");
          _streamController2.add(duration);
          break;
      }
    });
    return _channel
        .invokeMethod('start', {"path": path, "extension": extension});
  }

  static Future<Recording> stop() async {
    Map<String, Object> response =
    Map.from(await _channel.invokeMethod('stop'));
    Recording recording = new Recording(
        duration: new Duration(milliseconds: response['duration']),
        path: response['path'],
        audioOutputFormat:
        _convertStringInAudioOutputFormat(response['audioOutputFormat']),
        extension: response['audioOutputFormat']);
    _channel.setMethodCallHandler(null);
    return recording;
  }

  static Future<bool> get isRecording async {
    bool isRecording = await _channel.invokeMethod('isRecording');
    return isRecording;
  }

  static Future<bool> get hasPermissions async {
    bool hasPermission = await _channel.invokeMethod('hasPermissions');
    return hasPermission;
  }

  static AudioOutputFormat _convertStringInAudioOutputFormat(String extension) {
    switch (extension) {
      case ".wav":
        return AudioOutputFormat.WAV;
      case ".mp4":
      case ".aac":
      case ".m4a":
        return AudioOutputFormat.AAC;
      default:
        return null;
    }
  }

  static bool _isAudioOutputFormat(String extension) {
    switch (extension) {
      case ".wav":
      case ".mp4":
      case ".aac":
      case ".m4a":
        return true;
      default:
        return false;
    }
  }

  static String _convertAudioOutputFormatInString(
      AudioOutputFormat outputFormat) {
    switch (outputFormat) {
      case AudioOutputFormat.WAV:
        return ".wav";
      case AudioOutputFormat.AAC:
        return ".m4a";
      default:
        return ".m4a";
    }
  }
}

enum AudioOutputFormat { AAC, WAV }

class Recording {
  // File path
  String path;

  // File extension
  String extension;

  // Audio duration in milliseconds
  Duration duration;

  // Audio output format
  AudioOutputFormat audioOutputFormat;

  Recording({this.duration, this.path, this.audioOutputFormat, this.extension});
}