import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'decrypt.dart';

Stream<List<T>> bufferChunkedStream<T>(
  Stream<List<T>> input, {
  int bufferSize = 16 * 1024,
}) async* {
  if (bufferSize <= 0) {
    throw ArgumentError.value(
        bufferSize, 'bufferSize', 'bufferSize must be positive');
  }
  int initialBufferSize = bufferSize;

  late final StreamController<List<T>> c;
  StreamSubscription? sub;

  List<T> breakBuffer = [];
  c = StreamController(
    onListen: () {
      sub = input.listen((chunk) {
        bufferSize -= chunk.length;
        c.add(chunk);

        final currentSub = sub;
        if (bufferSize <= 0 && currentSub != null && !currentSub.isPaused) {
          currentSub.pause();
        }
      }, onDone: () {
        c.close();
      }, onError: (e, st) {
        c.addError(e, st);
      });
    },
    onCancel: () => sub!.cancel(),
  );

  await for (final chunk in c.stream) {
    yield* breakChunk(chunk, initialBufferSize);
    bufferSize += chunk.length;

    final currentSub = sub;
    if (bufferSize > 0 && currentSub != null && currentSub.isPaused) {
      currentSub.resume();
    }
  }
}

Stream<List<T>> breakChunk<T>(List<T> chunk, int bufferSize) async* {
  late final StreamController<List<T>> c;
  c = StreamController();
  List<T> internalChunk = chunk;
  while (internalChunk.length > bufferSize) {
    List<T> partialChunk = chunk.sublist(0, bufferSize);
    internalChunk.removeRange(0, bufferSize);
    final Future<List<T>> partialStream = Future<List<T>>(() => partialChunk);
    c.addStream(Stream.fromFuture(partialStream));
  }
  //c.add(internalChunk);

  await for (final chunk in c.stream) {
    yield chunk;
  }
}

Stream<List<int>> processCrypto<T>(Stream<List<int>> input, String key) async* {
  bool decrypted = false;

  late final StreamController<List<int>> c;
  StreamSubscription? sub;

  List<int> buffer = [];
  int dSize = 0;

  c = StreamController(
    onListen: () {
      sub = input.listen((chunk) {
        c.add(chunk);
      }, onDone: () {
        c.close();
      }, onError: (e, st) {
        c.addError(e, st);
      });
    },
    onCancel: () => sub!.cancel(),
  );

  await for (final chunk in c.stream) {
    buffer.addAll(chunk);
    dSize += chunk.length;
    final transformer = createCryptoTransformer(key, decrypted);
    yield* processCryptoInternal(chunk, buffer, key, decrypted)
        .transform(transformer);
    if (decrypted == true) yield chunk;
    if (dSize >= 20496 && decrypted == false) decrypted = true;
  }
}

Stream<List<int>> processCryptoInternal<int>(
    List<int> chunk, List<int> buffer, String key, bool decrypted) async* {
  if (buffer.length < 20496 && decrypted == false) {
    List<int> blank = [];
    yield blank;
  } else if (buffer.length > 20496 && decrypted == false) {
    yield buffer;
  }
}

StreamTransformer<List<int>, List<int>> createCryptoTransformer(
    String key, bool decrypted) {
  return StreamTransformer.fromHandlers(
    handleData: (List<int> chunk, EventSink<List<int>> sink) async {
      if (chunk.length >= 20496) {
        final bytesToDecrypt = chunk.sublist(0, 20496);
        List<int> content = decrypt(bytesToDecrypt, key);
        int chunkSize = 4 * 1024;
        while (content.length > chunkSize) {
          List<int> partialChunk = chunk.sublist(0, chunkSize);
          sink.add(partialChunk);
          partialChunk.removeRange(0, chunkSize);
        }
        if (chunk.length >= 20496) {
          List<int> buffer = chunk;
          buffer.removeRange(0, 20496);
          sink.add(content);
        }
      }
    },
  );
}

Stream<List<int>> processCrypto2<T>(
    Stream<List<int>> input, String key) async* {
  bool decrypted = false;

  late final StreamController<List<int>> c;
  StreamSubscription? sub;

  List<int> ivStream = [];
  int previousStreamSize = 0;

  c = StreamController(
      onListen: () {
        sub = input.listen((chunk) {
          c.add(chunk);
        }, onDone: () {
          c.close();
        }, onError: (e, st) {
          c.addError(e, st);
        });
      },
      onCancel: () => sub!.cancel(),
      onPause: () => sub!.pause(),
      onResume: () => sub!.resume());

  await for (final chunk in c.stream) {
    final transformer = DecryptTransformer(key, ivStream, previousStreamSize);
    yield* processCryptoInternal2(chunk).transform(transformer);
    ivStream = chunk.sublist(0, 16);
    previousStreamSize += chunk.length;
  }
}

Stream<List<int>> processCryptoInternal2<int>(List<int> chunk) async* {
  yield chunk;
}

StreamTransformer<List<int>, List<int>> DecryptTransformer(
    String key, List<int> ivStream, int previousStreamSize) {
  return StreamTransformer.fromHandlers(
    handleData: (List<int> chunk, EventSink<List<int>> sink) async {
      if (previousStreamSize < 20496) {
        final buffer = chunk;
        pc.CFBBlockCipher? cipher;
        final currentBufferSize = buffer.length;
        final newSize = previousStreamSize + currentBufferSize;
        int limitChars = currentBufferSize;
        if (newSize > 20496) {
          limitChars = 20496 - previousStreamSize;
        }
        List<int> bufferDecrypt = buffer.sublist(0, limitChars);
        List<int> bufferNoDecrypt = [];
        if (limitChars < currentBufferSize) {
          bufferNoDecrypt.sublist(limitChars - 1);
        }

        int decryptProcessed = 0;
        if (ivStream.isEmpty && currentBufferSize >= 16) {
          // Inicialize o cipher uma vez que o IV foi recebido
          final iv = buffer.sublist(0, 16);
          decryptProcessed += 1;
          final keyBytes = utf8.encode(key.substring(0, 16));
          final params = pc.ParametersWithIV(
              pc.KeyParameter(Uint8List.fromList(keyBytes)),
              Uint8List.fromList(iv));
          cipher = pc.CFBBlockCipher(pc.AESFastEngine(), 8); // 8 bits para CFB8
          cipher.init(false, params); // false para decriptação
        } else {
          final keyBytes = utf8.encode(key.substring(0, 16));
          final params = pc.ParametersWithIV(
              pc.KeyParameter(Uint8List.fromList(keyBytes)),
              Uint8List.fromList(ivStream));
          cipher = pc.CFBBlockCipher(pc.AESFastEngine(), 8); // 8 bits para CFB8
          cipher.init(false, params); // false para decriptação
        }

        while (decryptProcessed <= limitChars) {
          decryptProcessed += 16;
          // Descriptografe os dados um byte de cada vez
          final block = bufferDecrypt.sublist(
              0, 16); // Ajuste o tamanho do bloco conforme necessário
          final outputBlock = decryptBlock(cipher!, block);
          sink.add(outputBlock);
        }
        if (bufferNoDecrypt.isNotEmpty) {
          sink.add(bufferNoDecrypt);
        }
      } else {
        sink.add(chunk);
      }
    },
  );
}

List<int> decryptBlock(pc.CFBBlockCipher cipher, List<int> block) {
  final input = Uint8List.fromList(block);
  final output = Uint8List(block.length);
  cipher.processBlock(input, 0, output, 0);
  return output;
}

Stream<List<int>> processCrypto3<T>(Uint8List crypto, Stream<List<int>> input,
    String key, bool needCrypt) async* {
  late final StreamController<List<int>> c;
  StreamSubscription? sub;

  bool decryted = false;

  c = StreamController(
      onListen: () {
        sub = input.listen((chunk) {
          if (!decryted && needCrypt == true) {
            decryted = true;
            c.add(crypto);
          }
          c.add(chunk);
        }, onDone: () {
          c.close();
        }, onError: (e, st) {
          c.addError(e, st);
        });
      },
      onCancel: () {
        sub!.cancel();
      },
      onPause: () => sub!.pause(),
      onResume: () => sub!.resume());

  await for (final chunk in c.stream) {
    yield chunk;
  }
}
