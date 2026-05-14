package com.vemana.common.testing;

import org.junit.rules.TestRule;
import org.junit.runner.Description;
import org.junit.runners.model.Statement;

import java.util.concurrent.atomic.AtomicInteger;

public interface SharedTestRule extends TestRule {

  @Override
  default Statement apply(Statement base, Description description) {
    return this.apply(base, description, new AtomicInteger(0), new AtomicInteger(1));
  }

  /// Just like a regular [org.junit.rules.TestRule] but with one cruical difference: this rule is
  /// shareable across multiple tests which can potentially be running in parallel. Therefore,
  /// setup/teardown for this rule has a different meaning. It should setup its resource exactly
  /// once and tear it down exactly one.
  ///
  /// setup() should be run iff the setupCounter is at 1 after atomic increment teardown() should be
  /// run iff the teardownCounter is 0 after atomic decrement
  Statement apply(Statement stmt, Description desc, AtomicInteger setupCounter,
      AtomicInteger teardownCounter);


  /// Used in describing the test. So, this is what gets reported by test runner. Prefer the format
  /// `rule_name[params]`, e.g. `db[postgres_18_3]`.
  String descriptionString();
}
