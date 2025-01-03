import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;
import 'dart:convert';

import 'package:xml/xml.dart';

ZipDecoder? _zipDecoder;

enum DocxAlignment {
  left,
  center,
  right,
}

enum DocxParagraphType {
  normal,
  blockquote,
  unorderedListItem,
  orderedListItem,
}

class DocxTextSpan {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;

  const DocxTextSpan({
    required this.text,
    required this.bold,
    required this.italic,
    required this.underline,
  });

  @override
  String toString() => '''\n
    DocxTextSpan(
      text: '$text',
      bold: $bold,
      italic: $italic,
      underline: $underline,
    )''';
}

class DocxParagraph {
  final List<DocxTextSpan> spans;
  final DocxAlignment alignment;
  final DocxParagraphType type;

  const DocxParagraph({
    required this.spans,
    required this.alignment,
    required this.type,
  });

  @override
  String toString() => '''
  DocxParagraph(
    alignment: $alignment,
    type: $type,
    spans: $spans,
  ),
  ''';
}

/// Reads a docx file to a List of [`Paragraph`]s.
/// Only top level numbering is supported.
List<DocxParagraph> readDocx(
  Uint8List bytes, {
  bool handleNumbering = false,
}) {
  final document = readDocxXml(bytes);

  final List<DocxParagraph> paragraphs = [];

  final paragraphNodes = document.findAllElements('w:p');

  int number = 0;
  String lastNumId = '0';

  for (final paragraphEl in paragraphNodes) {
    final pPr = paragraphEl.getElement('w:pPr');

    // Get alignment
    DocxAlignment alignment = DocxAlignment.left;
    final jc = pPr?.getElement('w:jc');
    if (jc != null) {
      final alignVal = jc.getAttribute('w:val');
      switch (alignVal) {
        case 'center':
          alignment = DocxAlignment.center;
          break;
        case 'right':
          alignment = DocxAlignment.right;
          break;
        default:
          alignment = DocxAlignment.left;
      }
    }

    // Determine paragraph type
    DocxParagraphType type = DocxParagraphType.normal;

    // Check for blockquote by checking left indent
    final xml.XmlElement? ind = pPr?.getElement('w:ind');
    if (ind != null) {
      final String? leftIndentVal = ind.getAttribute('w:left');
      if (leftIndentVal != null) {
        final int leftIndent = int.tryParse(leftIndentVal) ?? 0;
        if (leftIndent > 0) {
          type = DocxParagraphType.blockquote;
        }
      }
    }

    // Handle numbering
    if (handleNumbering) {
      XmlElement? numbering = pPr?.getElement('w:numPr');
      if (numbering != null) {
        final numId =
            numbering.getElement('w:numId')?.getAttribute('w:val') ?? '0';

        if (numId != lastNumId) {
          number = 0;
          lastNumId = numId;
        }
        number++;
        type = DocxParagraphType.orderedListItem; // Adjust based on your needs
      }
    }

    // Process runs
    final runs = paragraphEl.findAllElements('w:r');
    final spans = <DocxTextSpan>[];
    for (final run in runs) {
      final runPr = run.getElement('w:rPr');

      // Check formatting
      bool bold = runPr?.getElement('w:b') != null;
      bool italic = runPr?.getElement('w:i') != null;
      bool underline = runPr?.getElement('w:u') != null;

      // Get text
      final textNodes = run.findAllElements('w:t');
      final text = textNodes.map((node) => node.innerText).join();

      if (text.isNotEmpty) {
        spans.add(DocxTextSpan(
          text: text,
          bold: bold,
          italic: italic,
          underline: underline,
        ));
      }
    }

    if (spans.isEmpty) {
      continue;
    }

    // Create Paragraph
    final paragraph = DocxParagraph(
      spans: spans,
      alignment: alignment,
      type: type,
    );

    paragraphs.add(paragraph);
  }

  return paragraphs;
}

/// Converts a docx file to text.
/// Only top level numbering is supported.
String docxToText(
  Uint8List bytes, {
  bool handleNumbering = false,
}) {
  final document = readDocxXml(bytes);

  final List<String> list = [];

  final paragraphNodes = document.findAllElements('w:p');

  int number = 0;
  String lastNumId = '0';

  for (final paragraph in paragraphNodes) {
    final textNodes = paragraph.findAllElements('w:t');
    String text = textNodes.map((node) => node.innerText).join();

    if (handleNumbering) {
      XmlElement? numbering =
          paragraph.getElement('w:pPr')?.getElement('w:numPr');
      if (numbering != null) {
        final numId = numbering.getElement('w:numId')!.getAttribute('w:val')!;

        if (numId != lastNumId) {
          number = 0;
          lastNumId = numId;
        }
        number++;
        text = '$number. $text';
      }
    }

    list.add(text);
  }

  return list.join('\n');
}

/// Opens a docx file and returns its raw XML content.
xml.XmlDocument readDocxXml(Uint8List bytes) {
  _zipDecoder ??= ZipDecoder();

  final archive = _zipDecoder!.decodeBytes(bytes);

  final file =
      archive.where((file) => file.name == 'word/document.xml').firstOrNull;

  if (file == null) {
    throw ArgumentError('`bytes` is not a valid docx file');
  }

  final fileContent = utf8.decode(file.content);
  return xml.XmlDocument.parse(fileContent);
}
