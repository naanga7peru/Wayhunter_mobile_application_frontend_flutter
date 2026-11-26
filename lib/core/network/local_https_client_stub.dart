Never createLocalHttpsClient(String _) {
  throw UnsupportedError(
    'Local debug HTTPS certificate trust requires a platform with dart:io.',
  );
}
