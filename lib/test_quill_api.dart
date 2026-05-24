import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

void main() {
  QuillEditor.basic(
    controller: QuillController.basic(),
    config: QuillEditorConfig(
      embedBuilders: kIsWeb
          ? FlutterQuillEmbeds.editorWebBuilders()
          : FlutterQuillEmbeds.editorBuilders(),
    ),
  );
}
