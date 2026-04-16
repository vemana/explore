package com.vemana.common.performance.jmh.testing;

import com.vemana.common.performance.jmh.testing.Metric.Numeric;

sealed interface JmhExpect permits JmhExpect.NumericExpect {

  /// Represents: value Op measure
  ///
  /// Example: `(avgt) < (10 nanos)`
  record NumericExpect(String key, LogicalOp op, Numeric rhs) implements JmhExpect {

    static NumericExpect ofPrimary(LogicalOp op, Numeric rhs) {
      return new NumericExpect("", op, rhs);
    }

    boolean isPrimary() {
      return key.isEmpty();
    }
  }
}
