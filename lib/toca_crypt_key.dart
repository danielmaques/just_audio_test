import 'dart:typed_data';
import 'dart:convert';

class TocaCrypty {
  final int squares = 9;
  final List<String> letters = [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O",
    "P",
    "Q",
    "R",
    "S",
    "T",
    "U",
    "V",
    "W",
    "X",
    "Y",
    "Z",
    "!",
    "?",
    "(",
    ")",
    "@",
    ",",
    ";",
    ":",
    "\$",
    "#",
    "[",
    "]",
    "&",
    "*",
    ".",
    "_",
    "-",
    "=",
    " ",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y",
    "z",
    "0",
    "1",
    "2",
    "3",
    "4",
    "5",
    "6",
    "7",
    "8",
    "9"
  ];
  late List<List<String>> one;
  late List<List<String>> two;

  TocaCrypty() {
    one = List.generate(squares, (_) => List.filled(squares, ''));
    two = List.generate(squares, (_) => List.filled(squares, ''));
    for (var i = 0; i < squares; i++) {
      for (var j = 0; j < squares; j++) {
        one[i][j] = letters[(i * squares) + j];
        two[i][j] =
            rot13(letters[((squares * squares) - 1) - ((i * squares) + j)]);
      }
    }
  }

  String rot13(String value) {
    List<int> array = List.from(value.codeUnits); // Cria uma nova lista mutável

    for (int i = 0; i < array.length; i++) {
      int number = array[i];

      if (number >= 'a'.codeUnitAt(0) && number <= 'z'.codeUnitAt(0)) {
        if (number > 'm'.codeUnitAt(0)) {
          number -= 13;
        } else {
          number += 13;
        }
      } else if (number >= 'A'.codeUnitAt(0) && number <= 'Z'.codeUnitAt(0)) {
        if (number > 'M'.codeUnitAt(0)) {
          number -= 13;
        } else {
          number += 13;
        }
      }
      array[i] = number;
    }
    return String.fromCharCodes(array);
  }

  String generate(String input, bool decode) {
    input = utf8.decode(base64.decode(input));
    final sizeInput = ((input.length / 2).floor()) * 2;
    final codes = <String>[];
    for (var l = 0; l < sizeInput; l += 2) {
      var symb1 = input[l];
      var symb2 = input[l + 1];
      List<int>? a1;
      List<int>? a2;
      for (var i = 0; i < squares; i++) {
        for (var j = 0; j < squares; j++) {
          if (decode) {
            if (symb1 == two[i][j]) a1 = [i, j];
            if (symb2 == one[i][j]) a2 = [i, j];
          } else {
            if (symb1 == one[i][j]) a1 = [i, j];
            if (symb2 == two[i][j]) a2 = [i, j];
          }
        }
      }
      if (a1 != null && a2 != null) {
        final symbn1 = decode ? one[a1[0]][a2[1]] : two[a1[0]][a2[1]];
        final symbn2 = decode ? two[a2[0]][a1[1]] : one[a2[0]][a1[1]];
        codes.add('$symbn1$symbn2');
      }
    }
    return codes.join();
  }

  String decodeKey(String input) {
    return generate(
        String.fromCharCodes(
            Uint8List.fromList(input.codeUnits).sublist(0, input.length)),
        true);
  }
}
