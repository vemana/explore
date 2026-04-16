package com.vemana.common.performance.jmh.testing;

/// Use case-aware naming of enum members since Mb and MB are different units.
enum Unit {
  sec_per_op,
  ns_per_op,
  ops_per_sec,
  ops_per_ns,
  B_per_op,
  ;

  public static Unit of(String unit) {
    return switch (unit) {
      case "s/op" -> sec_per_op;
      case "ns/op" -> ns_per_op;
      case "B/op" -> B_per_op;
      case "ops/s" -> ops_per_sec;
      case "ops/ns" -> ops_per_ns;
      default -> throw new IllegalArgumentException("Unknown unit %s".formatted(unit));
    };
  }

  private static RuntimeException invalidConversion(Unit from, Unit that) {
    throw new IllegalArgumentException("Cannot convert %s unit to %s".formatted(that, from));
  }

  public double convert(double value, Unit that) {
    return switch (this) {
      case sec_per_op -> convertFrom_SecPerOp(value, that);
      case ns_per_op -> convertFrom_SecPerOp(value * 1e-9, that);
      case B_per_op -> convertFrom_BPerOp(value, that);
      case ops_per_sec -> convertFrom_OpsPerSec(value, that);
      case ops_per_ns -> convertFrom_OpsPerSec(value * 1e9, that);
    };
  }

  private double convertFrom_BPerOp(double value, Unit that) {
    return switch (that) {
      case B_per_op -> value;
      case sec_per_op, ns_per_op, ops_per_sec, ops_per_ns -> throw invalidConversion(this, that);
    };
  }

  private double convertFrom_OpsPerSec(double value, Unit that) {
    return switch (that) {
      case ops_per_sec -> value;
      case ops_per_ns -> value * 1e-9;
      case sec_per_op, ns_per_op, B_per_op -> throw invalidConversion(this, that);
    };
  }

  private double convertFrom_SecPerOp(double value, Unit that) {
    return switch (that) {
      case sec_per_op -> value;
      case ns_per_op -> value * 1e9;
      case B_per_op, ops_per_sec, ops_per_ns -> throw invalidConversion(this, that);
    };
  }
}
