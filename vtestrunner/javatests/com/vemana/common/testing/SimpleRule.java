package com.vemana.common.testing;

import org.junit.rules.TestRule;
import org.junit.runner.Description;
import org.junit.runners.model.Statement;

import java.util.concurrent.atomic.AtomicInteger;

class SimpleRule implements SharedTestRule, TestRule {

  private final String id;
  private AtomicInteger level = new AtomicInteger(0);

  SimpleRule(String id) {this.id = id;}

  @Override
  public Statement apply(Statement stmt, Description desc, AtomicInteger setupCounter,
      AtomicInteger teardownCounter) {
    return new Statement() {
      @Override
      public void evaluate() throws Throwable {
        if (setupCounter.getAndIncrement() == 0) {
          level.incrementAndGet();
        }
        try {
          stmt.evaluate();
        } finally {
          if (teardownCounter.decrementAndGet() == 0) {
            level.incrementAndGet();
          }
        }
      }
    };
  }

  @Override
  public Statement apply(Statement base, Description description) {
    return apply(base, description, new AtomicInteger(0), new AtomicInteger(1));
  }

  @Override
  public String descriptionString() {
    return "SR[%s]".formatted(id);
  }

  public String id() {
    return id;
  }

  public AtomicInteger level() {
    return level;
  }

  @Override
  public String toString() {
    return descriptionString();
  }
}
