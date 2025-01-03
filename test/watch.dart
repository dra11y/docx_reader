// Watch mode #1093 - opened October 2019, closed February 2020 as "won't fix"
// https://github.com/dart-lang/test/issues/1093

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> runTests() async {
  print("\x1B[2J\x1B[0;0H");
  final process = await Process.start('dart', ['test']);
  unawaited(process.stdout.transform(utf8.decoder).forEach(stdout.write));
  unawaited(process.stderr.transform(utf8.decoder).forEach(stderr.write));
  await process.exitCode;
}

void main(_) async {
  await runTests();
  final srcWatcher = Directory('lib').watch(recursive: true);
  final testWatcher = Directory('test').watch(recursive: true);
  StreamSubscription? srcSub;
  StreamSubscription? testSub;

  void onData(FileSystemEvent event) async {
    print('Change detected in ${event.path}');
    await runTests();
  }

  srcSub = srcWatcher.listen(onData);
  testSub = testWatcher.listen(onData);

  ProcessSignal.sigint.watch().listen((_) async {
    await srcSub?.cancel();
    await testSub?.cancel();
    exit(0);
  });
}
