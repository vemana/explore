package com.vemana.common.testing;

import com.google.common.collect.ImmutableList;
import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.*;
import org.junit.rules.TestRule;
import org.junit.rules.TestWatcher;
import org.junit.runner.Description;
import org.junit.runner.RunWith;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.IntStream;

// Note: This test runs with a regex filter of "basic". See bazel rule.

/// Focus: Mixed Parameters only
@SuppressWarnings("ClassEscapesDefinedScope")
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerMethodParamsMixedWithClassParamTest {

  public static final int NUM_TESTS = (2 + 4 * 2 + 1 + 1 + 1 + 4);
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
    verifier.verify(true); // also verify levels this time
    Assert.assertEquals(3 * NUM_TESTS, testCounter.get());
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

  public final SimpleRule sr1 = ClassParam.chooseFrom(sr("11"), sr("12"), sr("13"));

  public final MethodParam<SimpleRule> sr2 =
      MethodParam.chooseFrom(sr("21"), sr("22"), sr("23"), sr("24"));

  public final MethodParam<Integer> i1 = MethodParam.chooseFrom(31, 32);

  @Rule public final ActiveTestMethod activeTestMethodBase = ActiveTestMethod.create();
  @Rule public Expect expect = Expect.create();
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

  @TestAnnotations.TestWithParameters
  public void basic_boxing(int i1) {
    String testname = "basic_boxing";
    verifier.registerIntegers(testname, i1);
    verifier.expectIntegers(testname, List.of(1, 2, 3));
  }

  @TestAnnotations.TestWithParameters
  public void basic_check_choices_reused(SimpleRule sr2, int i1) {
    String testnameKey = "basic_check_choices_reused";
    verifier.register(testnameKey, sr1);
    verifier.expectIds(testnameKey, List.of("11", "12", "13"));


    int mcidx = EvalContext.methodComboIndex();
    verifier.registerMethodIndexes(testnameKey, mcidx);
    verifier.expectMethodIndexes(testnameKey, IntStream.range(0, 8).boxed().toList());

    String displayname = activeTestMethodBase.activeDescription().getDisplayName();
    expect.that(displayname).contains("_sr1[%s]".formatted(sr1));
    expect.that(displayname).contains("_i1[%s]".formatted(i1));
    expect.that(displayname).contains("_sr2[%s]".formatted(sr2));
    if (mcidx == 0) {
      expect.that(displayname)
          .startsWith(
              "basic_check_choices_reused_sr1[SR[%s]]_sr2[SR[21]]_i1[31](".formatted(sr1.id()));
    }

    var second = List.of("21", "21", "22", "22", "23", "23", "24", "24");
    var third1 = List.of(31, 32);
    var third2 = ImmutableList.<Integer>builder();
    for (int i = 0; i < 4; i++)
      third2.addAll(third1);
    var third = third2.build();
    expect.that(sr2.id()).isEqualTo(second.get(mcidx));
    expect.that(i1).isEqualTo(third.get(mcidx));

    int testComboIndex = EvalContext.testIndex() / NUM_TESTS;
    var first = List.of("11", "12", "13");
    expect.that(sr1.id()).isEqualTo(first.get(testComboIndex));
  }

  @TestAnnotations.TestWithParameters
  public void basic_empty_method_parameters_should_be_fine() {
    // Check no rules are running
    seenValues.add(value.get());

    // Check unused method params are set to null
    expect.that(sr2).isNull();
    expect.that(i1).isNull();
  }

  @Test
  public void basic_regularTest() {}

  @Test
  public void basic_skippedTest() {
    Assume.assumeTrue(false);
  }

  @TestAnnotations.TestWithParameters
  public void basic_skippedTest_withMethodParamssss(SimpleRule sr2) {
    Assume.assumeTrue(false);
  }

  @Test
  public void xyz() {

  }
}