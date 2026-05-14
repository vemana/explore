package com.vemana.common.testing.internal;

import org.junit.runners.model.FrameworkMethod;

public class IndexedMethod extends FrameworkMethod {
  public final TestMethod method;
  public final int comboIndex;
  private volatile int index;

  public IndexedMethod(int index, int comboIndex, TestMethod method) {
    super(method.getMethod());
    this.index = index;
    this.comboIndex = comboIndex;
    this.method = method;
  }

  public int comboIndex() {
    return comboIndex;
  }

  public int index() {
    return index;
  }

  @Override
  public String toString() {
    return "IM [%80s %4s %4s]".formatted(method, comboIndex, index);
  }

  public void updateIndex(int newIndex) {
    this.index = newIndex;
  }
}
