void assertState(bool b, String message) {
  if (!b) throw StateError(message);
}
