package com.vemana.common.testing.internal;

import com.vemana.common.testing.SharedTestRule;
import org.junit.rules.TestRule;
import org.junit.runner.Description;
import org.junit.runners.model.Statement;

import java.util.concurrent.atomic.AtomicInteger;

class SharedRuleAdapter implements TestRule {
  private final SharedTestRule sharedTestRule;
  private final AtomicInteger setupCounter;
  private final AtomicInteger teardownCounter;

  SharedRuleAdapter(SharedTestRule sharedTestRule, AtomicInteger setupCounter,
      AtomicInteger teardownCounter) {
    this.sharedTestRule = sharedTestRule;
    this.setupCounter = setupCounter;
    this.teardownCounter = teardownCounter;
  }

  @Override
  public Statement apply(Statement base, Description description) {
    return sharedTestRule.apply(base, description, setupCounter, teardownCounter);
  }
}
