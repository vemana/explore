package com.vemana.common.testing;

import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.junit.runner.RunWith;

import java.util.concurrent.atomic.AtomicInteger;

// Note: This test runs with a regex filter of "basic". See bazel rule.

/// Focus
/// - Class Parameters only
/// - Inheritance of test methods (derived class)
/// - Test naming
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerClassParamDerivedTest extends VTestRunnerClassParamAbstractBase {

  static AtomicInteger testCounter = new AtomicInteger(0);

  @AfterClass
  public static void verify() {
    // 2*3 combos here, 2*2 combos in parent
    // 1 test here, 1 test in parent
    // total = 2*3*2*2*(1+1) = 48
    Assert.assertEquals(48, testCounter.get());
  }

  @Rule public final Expect expect = Expect.create();
  @Rule public final ActiveTestMethod activeTestMethod = ActiveTestMethod.create();
  @Rule public TestRule testRule = new TestWatcher() {
    @Override
    protected void starting(Description description) {
      testCounter.incrementAndGet();
    }
  };
  String third = ClassParam.chooseFrom("a", "b");
  int fourth = ClassParam.chooseFrom(5, 6, 7);

  @Test
  public void basicChild() {
    String testName = activeTestMethod.activeDescription().getDisplayName();
    expect.that(testName).contains("basicChild");
    expect.that(testName).contains("_first[%s]".formatted(first)); // from base
    expect.that(testName).contains("[%s]".formatted(second.descriptionString())); // from base
    expect.that(testName).contains("_third[%s]".formatted(third));
    expect.that(testName).contains("_fourth[%s]".formatted(fourth));
    int testIndex = EvalContext.testIndex();
    if (testIndex == 0) {
      expect.that(testName).startsWith("basicChild_first[1]_second[SR[id1]]_third[a]_fourth[5](");
    }
  }
}