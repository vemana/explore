package com.vemana.common.performance.jmh.testing;

enum LogicalOp {
  LESS_OR_EQUAL("<"),
  GREATER_OR_EQUAL(">"),
  ;

  private final String opDisplay; // Example: < for LESS_THAN

  LogicalOp(String opDisplay) {
    this.opDisplay = opDisplay;
  }

  public boolean compare(double lhs, double rhs) {
    return switch (this) {
      case LESS_OR_EQUAL -> lhs <= rhs;
      case GREATER_OR_EQUAL -> lhs >= rhs;
    };
  }

  @Override
  public String toString() {
    return "BooleanOp[%s]".formatted(opDisplay);
  }
}
