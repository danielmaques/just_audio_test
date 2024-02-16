import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'chunk_processing.dart';
import 'decrypt.dart';
import 'dart:typed_data';

class TocaSource extends StreamAudioSource {
  final String url;
  final String key;

  int _sourceLength = 0;
  int _contentLength = 0;
  List<int> ivStream = [];
  bool _needDecrypt = true;
  Uint8List decryptedBuffer = Uint8List.fromList([]);
  TocaSource(this.url, this.key) : super(tag: 'TocaSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(url));

    final buffer = <int>[];

    if (_needDecrypt) {
      final clientCrypt = http.Client();
      final requestCrypt = http.Request('GET', Uri.parse(url));
      requestCrypt.headers['Range'] = 'bytes=0-20496';
      final streamRes = await clientCrypt.send(requestCrypt);

      final completer = Completer<void>();
      streamRes.stream.listen(
        (chunk) {
          buffer.addAll(chunk);
          if (buffer.length >= 20496) {
            // Atingido o tamanho desejado, completando a operação.
            completer.complete();
          }
        },
        onError: (e) {
          // Trate erros aqui
          completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) {
            // A stream terminou antes de atingir o tamanho desejado.
            completer.completeError(Exception('Stream ended early.'));
          }
        },
        cancelOnError: true,
      );
      await completer.future;
      decryptedBuffer = decryptAESCryptoJS(buffer.sublist(0, 20496), key);
      _needDecrypt = false;
    }

    if (start != null || end != null) {
      request.headers['Range'] = 'bytes=${start ?? ''}-${end ?? ''}';
    } else {
      request.headers['Range'] = 'bytes=20496-${end ?? ''}';
    }

    final response = await client.send(request);

    bool needDecryptChunk = start == null ? true : false;

    //final response3 = await client.send(request);
    final processedStream =
        processCrypto3(decryptedBuffer, response.stream, key, needDecryptChunk);

    if (start != null || end != null) {
      _contentLength =
          int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
    }
    String contentRangeValue = response.headers['content-range'] ?? '';
    List<String> contentRangeParts = contentRangeValue.split('/');
    if (contentRangeParts.length == 2) {
      _sourceLength = int.tryParse(contentRangeParts[1]) ?? 0;
    }

    //lastStream = processedStream;
    return StreamAudioResponse(
      sourceLength: _sourceLength,
      contentLength: _contentLength > 0 ? _contentLength : null,
      offset: start ?? 0,
      stream: processedStream,
      contentType: 'audio/m4a',
    );
  }
}
