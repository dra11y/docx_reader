import 'dart:io';
import 'dart:typed_data';

import 'package:docx_reader/src/docx_reader.dart';
import 'package:test/test.dart';

void main() {
  group('docx_reader', () {
    late Uint8List bytes;

    setUp(() {
      final file = File('test/data/20240930-destiny-of-america.docx');
      bytes = file.readAsBytesSync();
      // Additional setup goes here.
    });

    test('Test Read Docx', () {
      final paragraphs = readDocx(bytes);
      print('paragraphs: $paragraphs');
    });
  });
}
