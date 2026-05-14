package com.vemana.common.testing.internal;

/// I help you to track your current level (i.e. number of chooseFroms seen) and current position
/// that determines the class parameter assignments.
public final class ClassLevelIndexContext {
  private final int total; // total number of tests
  private int seen; // seen so far (product of numchoices so far)

  public ClassLevelIndexContext(int total) {
    this.total = total;
    this.seen = 1;
  }

  public int seen() {return seen;}

  @Override
  public String toString() {
    return "IndexContext[" +
           "seen=" + seen + ", " +
           "total=" + total + ']';
  }

  public int total() {return total;}

  void addSelect(int numCandidates) {
    this.seen *= numCandidates;
  }
}

