package com.vemana.common.testing;

import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.Rule;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.junit.runner.RunWith;

import java.util.concurrent.atomic.AtomicInteger;

// Note: This test runs with a regex filter of "basic". See bazel rule.

/// Focus
/// - Method Parameters only
/// - Inheritance of test methods (derived class)
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerMethodParamsDerivedTest extends VTestRunnerMethodParamsAbstractBase {

  static AtomicInteger testCounter = new AtomicInteger(0);

  @AfterClass
  public static void verify() {
    Assert.assertEquals(3 * 2 + 2 * 3 * 3, testCounter.get());
  }

  @Rule public final Expect expect = Expect.create();
  @Rule public final ActiveTestMethod activeTestMethod = ActiveTestMethod.create();
  @Rule public TestRule testRule = new TestWatcher() {
    @Override
    protected void starting(Description description) {
      testCounter.incrementAndGet();
    }
  };

  public MethodParam<String> third = MethodParam.chooseFrom("a", "b");
  public MethodParam<Integer> fourth = MethodParam.chooseFrom(5, 6, 7);

  @TestAnnotations.TestWithParameters
  public void basicChild(String third, int first, int fourth) {
    String testName = activeTestMethod.activeDescription().getDisplayName();
    expect.that(testName).contains("basicChild");
    expect.that(testName).contains("_third[%s]".formatted(third));
    expect.that(testName).contains("_first[%s]".formatted(first)); // this is from base class
    expect.that(testName).contains("_fourth[%s]".formatted(fourth));
    int mcidx = EvalContext.methodComboIndex();
    expect.that(mcidx).isAtLeast(0);
    expect.that(mcidx).isAtMost(2 * 3 * 3 - 1);
    if (mcidx == 0) {
      expect.that(testName).startsWith("basicChild_third[a]_first[1]_fourth[5](");
    }
  }
}