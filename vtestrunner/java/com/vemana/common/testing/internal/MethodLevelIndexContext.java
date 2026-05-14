package com.vemana.common.testing.internal;

/// I help you to track your current level (i.e. number of chooseFroms seen)
public final class MethodLevelIndexContext {
  private int level;

  public void addLevel() {
    this.level++;
  }

  public int level() {
    return level;
  }
}

