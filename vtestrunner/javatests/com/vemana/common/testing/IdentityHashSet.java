package com.vemana.common.testing;

import java.util.IdentityHashMap;
import java.util.stream.Stream;

class IdentityHashSet<T> {
  private final IdentityHashMap<T, Void> map = new IdentityHashMap<>();

  public Stream<T> stream() {
    return map.keySet().stream();
  }

  boolean add(T key) {
    boolean hasKey = map.containsKey(key);
    map.put(key, null);
    return !hasKey;
  }

  int size() {
    return map.size();
  }
}
