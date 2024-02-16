import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as pc;
import 'toca_crypt_key.dart';
import 'package:crypto_x/crypto_x.dart';

List<int> decrypt(List<int> data, String key) {
  final ivBytes = data.sublist(0, 16);
  final contentBytes = data.sublist(16);

  final generatedKey = TocaCrypty().generate(key, true);
  final keyBytes =
      utf8.encode(generatedKey); // Convertendo a chave gerada para bytes
  final params = pc.ParametersWithIV(
      pc.KeyParameter(Uint8List.fromList(keyBytes)),
      Uint8List.fromList(ivBytes));

  final cfb = pc.CFBBlockCipher(pc.AESEngine(), 8); // 8 bits para CFB8
  cfb.init(false, params);

  return processBlocks(cfb, Uint8List.fromList(contentBytes));
}

Uint8List decryptAESCryptoJS(List<int> data, String key) {
  try {
    final generatedKey = TocaCrypty().generate(key, true);
    final ivBytes = Uint8List.fromList(data.sublist(0, 16));
    final cipherKey = CipherKey.fromUTF8(generatedKey);
    final iv = CipherIV(ivBytes);
    var aes = AES(key: cipherKey, mode: AESMode.cfb8, padding: null);
    final contentBytes = Uint8List.fromList(data.sublist(16));
    CryptoBytes encrypted = CryptoBytes(contentBytes);
    CryptoBytes decrypted = aes.decrypt(encrypted, iv: iv);
    return decrypted.bytes;
  } catch (error) {
    throw error;
  }
}

class ExtendedCryptoBytes extends CryptoBytes {
  ExtendedCryptoBytes(Uint8List input) : super(Uint8List.fromList(input));
}

List<int> processBlocks(pc.CFBBlockCipher cipher, Uint8List inputData) {
  final output = Uint8List(inputData.length);

  for (var offset = 0; offset < inputData.length;) {
    final len = cipher.processBlock(inputData, offset, output, offset);
    offset += len;
  }

  return output;
}
