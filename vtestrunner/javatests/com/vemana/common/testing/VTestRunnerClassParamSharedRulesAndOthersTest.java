package com.vemana.common.testing;

import com.google.common.collect.ImmutableList;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.BeforeClass;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.util.Collections;
import java.util.List;
import java.util.stream.Stream;

// Note: This test runs with a regex filter of "basic". See bazel rule.
/// Focus
/// - Class Parameters only
/// - Parameters are both SharedTestRules and non-TestRules
/// - Tests run in parallel
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerClassParamSharedRulesAndOthersTest {

  static Verifier verifier;

  @BeforeClass
  public static void createVerifier() {
    verifier = new Verifier();
  }

  @AfterClass
  public static void verify() {
    verifier.verify(true);
  }

  final SimpleRule b1 = ClassParam.chooseFrom(new SimpleRule("11"),
      new SimpleRule("12"));
  final Int c2 = ClassParam.chooseFrom(new Int(4), new Int(5));
  final SimpleRule b3 = ClassParam.chooseFrom(new SimpleRule("21"),
      new SimpleRule("22"), new SimpleRule("23"));

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
    verifier.registerInts(testname, c2);
    verifier.register(testname, b3);
    verifier.expectIds(testname,
        List.of("11", "12", "21", "22", "23"));
    verifier.expectInts(testname, List.of(new Int(4), new Int(5)));

    int testIndex = EvalContext.testIndex() / 2;

    var first = ImmutableList.<String>builder()
        .addAll(Collections.nCopies(6, "11"))
        .addAll(Collections.nCopies(6, "12"))
        .build();

    var second = Stream.of(4, 4, 4, 5, 5, 5, 4, 4, 4, 5, 5, 5).map(Int::new).toList();

    var third = Stream.of(21, 22, 23, 21, 22, 23, 21, 22, 23, 21, 22, 23).map(x -> "" + x).toList();

    Assert.assertEquals("Test index %s, b1".formatted(testIndex), first.get(testIndex), b1.id());
    Assert.assertEquals("Test index %s, c2".formatted(testIndex), second.get(testIndex), c2);
    Assert.assertEquals("Test index %s, b3".formatted(testIndex), third.get(testIndex), b3.id());
  }

  @Test
  public void basic2() {

  }

  @Test
  public void xyz() {

  }
}