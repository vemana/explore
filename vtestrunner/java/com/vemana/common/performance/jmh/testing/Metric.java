package com.vemana.common.performance.jmh.testing;

sealed interface Metric permits Metric.Numeric {

  record Numeric(double value, Unit unit) implements Metric {
    static Numeric of(double value, Unit unit) {
      return new Numeric(value, unit);
    }

    static Numeric of(double value, String unit) {
      return Numeric.of(value, Unit.of(unit));
    }

    Numeric convertTo(Unit that) {
      return new Numeric(unit.convert(value, that), that);
    }
  }
}
