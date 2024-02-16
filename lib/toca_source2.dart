import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:developer';

import 'package:rxdart/rxdart.dart';

class TocaSource2 extends StreamAudioSource {
  final String url;
  final String key;
  late final http.Client client;
  int _sourceLength = 0;
  int _contentLength = 0;
  TocaSource2(this.url, this.key) : super(tag: 'TocaSource2');
  final StreamController<List<int>> _audioStream =
      StreamController<List<int>>();
  int progress = 0;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    //client.close();
    client = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    log(key);
    if (start != null || end != null) {
      request.headers['Range'] = 'bytes=${start ?? ''}-${end ?? ''}';
    }

    final response = await client.send(request);

    _audioStream.onListen = () {
      log('onListen');
    };

    _audioStream.onCancel = () {
      log('onCancel');
    };

    response.stream.listen((data) {
      progress += data.length;
      _audioStream.sink.add(data);
      //log('Request progress: ' + progress.toString());
    }, onDone: () {
      log('Done');
    }, onError: (e) {
      log('Error: $e');
    });

    _contentLength =
        int.tryParse(response.headers['content-length'] ?? '0') ?? 0;

    String contentRangeValue = response.headers['content-range'] ?? '';
    List<String> contentRangeParts = contentRangeValue.split('/');
    if (contentRangeParts.length == 2) {
      _sourceLength = int.tryParse(contentRangeParts[1]) ?? 0;
    }

    return StreamAudioResponse(
      sourceLength: _sourceLength,
      contentLength: _contentLength > 0 ? _contentLength : null,
      offset: start ?? 0,
      stream: _audioStream.stream,
      contentType: 'audio/m4a',
    );
  }
}
