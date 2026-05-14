package com.vemana.common.testing;

import com.google.common.collect.ImmutableList;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.*;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.junit.runner.RunWith;

import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

// Note: This test runs with a regex filter of "basic". See bazel rule.
/// Focus
/// - Class Parameters only
/// - Parameters are only SharedTestRules
/// - Tests run in parallel
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerClassParamSharedRulesOnlyTest {

  static AtomicInteger testCounter = new AtomicInteger(0);
  static Verifier verifier;

  @BeforeClass
  public static void createVerifier() {
    verifier = new Verifier();
  }

  @AfterClass
  public static void verify() {
    verifier.verify(true);
    // 24 combos * 2 tests per combo.
    Assert.assertEquals(48, testCounter.get());
  }

  final SimpleRule b1 = ClassParam.chooseFrom(new SimpleRule("11"),
      new SimpleRule("12"), new SimpleRule("13"));
  final SimpleRule b2 = ClassParam.chooseFrom(new SimpleRule("21"),
      new SimpleRule("22"), new SimpleRule("23"), new SimpleRule("24"));
  final SimpleRule b3 = ClassParam.chooseFrom(new SimpleRule("31"), new SimpleRule("32"));

  @Rule public TestRule testRule = new TestWatcher() {
    @Override
    protected void starting(Description description) {
      testCounter.incrementAndGet();
    }
  };

  @Test
  public void abc() {
    // Keep the ordering abc [basic*] xyz.
    // We have a test_filter arg for this java_test so that we exercise only a subset
    // of the tests. That is, we are testing indices assignment after applying filters.
  }

  @Test
  public void basic() {
    String testname = "basic";
    verifier.register(testname, b1);
    verifier.register(testname, b2);
    verifier.register(testname, b3);
    verifier.expectIds(testname,
        List.of("11", "12", "13", "21", "22", "23", "24", "31", "32"));

    int testIndex = EvalContext.testIndex() / 2;

    var first = ImmutableList.<String>builder()
        .addAll(Collections.nCopies(8, "11"))
        .addAll(Collections.nCopies(8, "12"))
        .addAll(Collections.nCopies(8, "13"))
        .build();

    var second1 = List.of("21", "21", "22", "22", "23", "23", "24", "24");
    var second = ImmutableList.<String>builder()
        .addAll(second1)
        .addAll(second1)
        .addAll(second1)
        .build();


    var third1 = List.of("31", "32");
    var third2 = ImmutableList.<String>builder();
    for (int i = 0; i < 12; i++)
      third2.addAll(third1);
    var third = third2.build();

    Assert.assertEquals("Test index %s, b1".formatted(testIndex), first.get(testIndex), b1.id());
    Assert.assertEquals("Test index %s, b2".formatted(testIndex), second.get(testIndex), b2.id());
    Assert.assertEquals("Test index %s, b3".formatted(testIndex), third.get(testIndex), b3.id());
  }

  @Test
  public void basic2() {
  }

  @Test
  public void xyz() {

  }
}