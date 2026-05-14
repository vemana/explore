package com.vemana.common.testing.internal;

// 2. The Request Record (encapsulating the arguments)
public record FieldInitsRequest(Class<?> targetClassObj,
                                String targetMethodOwner,
                                String targetMethodName) {
  /// Helper to convert "com.my.MyClass" to "com/my/MyClass" for bytecode comparison.
  public String internalOwnerName() {
    return targetMethodOwner.replace('.', '/');
  }
}
