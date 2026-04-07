class LastEntryCache<K, V> {
  K? lastKey;
  V? lastValue;

  // More efficient by taking a (K) parameter. In hot loops, we don't need func to be
  // an anonymous lambda (which creates an object).
  V putIfAbsent(K key, V Function(K) func) {
    if (lastKey == key) return lastValue!;
    lastKey = key;
    lastValue = func(key);
    return lastValue!;
  }
}

class LastEntryCache2<K1, K2, V> {
  K1? key1;
  K2? key2;
  V? lastValue;

  // More efficient by taking a (K1, K2) parameter. In hot loops, we don't need func to be
  // an anonymous lambda (which creates an object).
  V putIfAbsent(K1 k1, K2 k2, V Function(K1, K2) func) {
    if (key1 == k1 && key2 == k2) return lastValue!;
    key1 = k1;
    key2 = k2;
    lastValue = func(k1, k2);
    return lastValue!;
  }
}
