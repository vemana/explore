package com.vemana.common.testing;

import com.google.common.collect.ImmutableList;
import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.*;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.junit.runner.RunWith;
import org.junit.runners.model.Statement;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

// Note: This test runs with a regex filter of "basic". See bazel rule.

/// Focus
/// - Method Parameters only
/// - Parameters are all kinds
/// - Even if params are Rules, they don't run
/// - Tests run in parallel
/// - Naming
@SuppressWarnings("ClassEscapesDefinedScope")
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerMethodParamsTest {

  static final ThreadLocal<Integer> value = new ThreadLocal<>();
  static AtomicInteger testCounter = new AtomicInteger(0);
  static Verifier verifier;
  static Set<Integer> seenValues = Collections.synchronizedSet(new HashSet<>());

  @BeforeClass
  public static void createVerifier() {
    verifier = new Verifier();
  }

  @AfterClass
  public static void verify() {
    verifier.verify(false);
    // method combos = 3 for i1, 24 for sr1/sr2/sr3 and 1 for empty args
    Assert.assertEquals(3 + 3 * 4 * 2 + 1 + 3 * 2 * 2, testCounter.get());
  }

  @AfterClass
  public static void verifyThatChoicesWhichAreRulesDontRunTheirRuleImpls() {
    Set<Integer> expected = new HashSet<>();
    expected.add(null);
    Assert.assertEquals("Seenvalues differed", expected, seenValues);
  }

  static SimpleRule sr(String id) {
    return new SimpleRule(id);
  }

  public final MethodParam<SimpleRule> sr1 = MethodParam.chooseFrom(sr("11"), sr("12"), sr("13"));

  public final MethodParam<SimpleRule> sr2 =
      MethodParam.chooseFrom(sr("21"), sr("22"), sr("23"), sr("24"));

  public final MethodParam<SimpleRule> sr3 = MethodParam.chooseFrom(sr("31"), sr("32"));

  public final MethodParam<MyTestRule> mt1 = MethodParam.chooseFrom(new MyTestRule(1),
      new MyTestRule(2));

  public final MethodParam<Integer> i1 = MethodParam.chooseFrom(1, 2, 3);

  @Rule public Expect expect = Expect.create();
  @Rule public TestRule testRule = new TestWatcher() {
    @Override
    protected void starting(Description description) {
      testCounter.incrementAndGet();
    }
  };
  @Rule public final ActiveTestMethod activeTestMethodBase = ActiveTestMethod.create();

  @Test
  public void abc() {
    // Keep the ordering abc [basic*] xyz.
    // We have a test_filter arg for this java_test so that we exercise only a subset
    // of the tests. That is, we are testing indices assignment after applying filters.
  }

  @TestAnnotations.TestWithParameters
  public void basic_boxing(int i1) {
    String testname = "basic_boxing";
    verifier.registerIntegers(testname, i1);
    verifier.expectIntegers(testname, List.of(1, 2, 3));
  }

  @TestAnnotations.TestWithParameters
  public void basic_check_choices_reused(SimpleRule sr1, SimpleRule sr2, SimpleRule sr3) {
    String testname = "basic_check_choices_reused";
    verifier.register(testname, sr1);
    verifier.register(testname, sr2);
    verifier.register(testname, sr3);
    verifier.expectIds(testname,
        List.of("11", "12", "13", "21", "22", "23", "24", "31", "32"));

    int midx = EvalContext.methodComboIndex();
    verifier.registerMethodIndexes(testname, midx);
    verifier.expectMethodIndexes(testname, IntStream.range(0, 24).boxed().toList());

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

    Assert.assertEquals("Test index %s, b1".formatted(midx), first.get(midx), sr1.id());
    Assert.assertEquals("Test index %s, b2".formatted(midx), second.get(midx), sr2.id());
    Assert.assertEquals("Test index %s, b3".formatted(midx), third.get(midx), sr3.id());
  }

  @TestAnnotations.TestWithParameters
  public void basic_empty_method_parameters_should_be_fine() {
    // Check no rules are running
    seenValues.add(value.get());

    // Check unused method params are set to null
    expect.that(sr1).isNull();
    expect.that(sr2).isNull();
    expect.that(sr3).isNull();
    expect.that(mt1).isNull();
    expect.that(i1).isNull();
  }

  @TestAnnotations.TestWithParameters
  public void basic_naming(int i1, MyTestRule mt1, SimpleRule sr3) {
    String testname = activeTestMethodBase.activeDescription().getDisplayName();
    expect.that(testname).contains("basic_naming");
    expect.that(testname).contains("_i1[%s]".formatted(i1));
    expect.that(testname).contains("_mt1[%s]".formatted(mt1));
    expect.that(testname).contains("_sr3[%s]".formatted(sr3));
  }

  @Test
  public void xyz() {

  }

  private static class MyTestRule implements TestRule {
    final Integer valueToSet;

    private MyTestRule(int valueToSet) {this.valueToSet = valueToSet;}

    @Override
    public Statement apply(Statement base, Description description) {
      return new Statement() {
        @Override
        public void evaluate() throws Throwable {
          Integer current = value.get();
          value.set(valueToSet);
          try {
            base.evaluate();
          } finally {
            value.set(current);
          }
        }
      };
    }

    @Override
    public String toString() {
      return "mt[%s]".formatted(valueToSet);
    }
  }
}