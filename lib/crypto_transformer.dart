import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'dart:async';

class CryptoTransformer extends StreamTransformerBase<List<int>, List<int>> {
  final String key;

  CryptoTransformer(this.key);

  @override
  Stream<List<int>> bind(Stream<List<int>> stream) {
    return Stream<List<int>>.eventTransformed(
      stream,
      (sink) => _CryptoSink(sink, key),
    );
  }
}

class _CryptoSink implements EventSink<List<int>> {
  final EventSink<List<int>> _outputSink;
  final String _key;
  final List<int> _buffer = []; // Definição de _buffer

  _CryptoSink(this._outputSink, this._key);

  @override
  void add(List<int> data) {
    _buffer.addAll(data); // agora _buffer é reconhecido

    if (_buffer.length >= 20496) {
      final bytesToDecrypt = _buffer.sublist(0, 20496);
      final decryptedData = _decrypt(bytesToDecrypt, _key);
      _outputSink.add(decryptedData);

      // Manter quaisquer dados adicionais no buffer para processamento posterior
      _buffer.removeRange(0,
          20496); // atualizado para removeRange para evitar a criação de listas temporárias
      _outputSink.add(_buffer);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _outputSink.addError(error, stackTrace);
  }

  @override
  void close() {
    _outputSink.close();
  }

  List<int> _decrypt(List<int> data, String key) {
    final keyBytes =
        utf8.encode(key.substring(0, 16)); // Ajuste conforme necessário
    final ivBytes = data.sublist(0, 16);
    final contentBytes = data.sublist(16);

    final cfb =
        new pc.CFBBlockCipher(new pc.AESFastEngine(), 8); // 8 bits para CFB8
    final params = new pc.ParametersWithIV(
        pc.KeyParameter(Uint8List.fromList(keyBytes)),
        Uint8List.fromList(ivBytes));
    cfb.init(false, params); // false para decriptação

    final decrypted = _processBlocks(cfb, Uint8List.fromList(contentBytes));
    return decrypted;
  }

  Uint8List _processBlocks(pc.CFBBlockCipher cipher, Uint8List inputData) {
    final output = Uint8List(inputData.length);

    var offset = 0;
    final stopwatch = Stopwatch()..start();
    print('Total' + inputData.length.toString() + 'in ${stopwatch.elapsed}');
    while (offset < inputData.length) {
      // ajuste na condição de loop
      final len = cipher.processBlock(inputData, offset, output, offset);
      offset += len;
      print('Processed block at offset $offset in ${stopwatch.elapsed}');
      stopwatch.reset();
    }

    return output;
  }
}
