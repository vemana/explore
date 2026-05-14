package com.vemana.common.testing;

import com.google.common.base.Preconditions;
import com.vemana.common.error.QuietCaller;
import com.vemana.common.testing.internal.*;

import java.util.concurrent.atomic.AtomicReference;

/// Support for testing using a matrix of parameters in JUnit4 tests. This lassos a few important
/// concerns in parametric testing:
/// - Duplicate tests across combinations. If we had 5 test methods and 3x4 = 12 combinations to
/// test, we want to generate 60 tests with the correct setup for each.
/// - Run a Rule exactly once for a bunch of parameter combinations. E.g. the db param can be
/// between postgres/yugabyte and the tests will be duplicated among them. But we still want only
/// one postgres instance and one yugabyte instance. Half the tests should target postgres and the
/// rest should target yugabyte.
/// - Run tests in parallel. Obviously, for combinations, parallelism is necesary for velocity.
/// - Run test rules (not tests) in parallel. This is a necessary side-effect of supporting Rules
/// that have exactly-once semantics (like the db rule mentioned above).
///
/// We introduce the notion of [SharedTestRule] for rules that can run in parallel and support
/// exactly once semantics. In other words, they are multi-thread safe and will setup their resource
/// only once in the face of parallel threads. They can run serially too (obviously). Exactly once
/// semantics is powerful for slow resource setups like creating docker database containers.
///
///
/// ```java
/// private final DbTestCase dbTestCase =  // Note the lack of static
///     SharedRules.chooseFrom(postgres(), yugabyte(), cockroach());
///
/// private final int maxConnections =
///     SharedRules.chooseFrom(1, 2);
///
/// // This will NOT RUN the myRule. If you want it to run myRule, implement the SharedTestRule
/// // interface. Otherwise, we can't assume anything about multi-thread behavior of MyRule.
/// // Another option is to choose a boolean parameter and use a traditional `@Rule` rule which
/// // is initialized to either the OldRuleImpl or NewRuleImpl based on the boolean.
/// private final MyRule myRule =
///     SharedRules.chooseFrom(new OldRuleImpl(), new NewRuleImpl());
///
/// // The rest of your @Rules and test code....
///
/// ```
///
/// This snippet runs the tests for 6 combinations of db and maxConnections. If you have 10 methods
/// in your test class, this runs 60 tests. The dbTestCase and maxConnections parameter will be set
/// for each test as you'd expect - for e.g., maxConnections will be 1 in half the tests and 2 in
/// the other half.
///
/// The implementation is an intricate web. It first identifies the number of combinations using a
/// sample instance and interpreting the `chooseFrom(..)` methods in a certain way. Once it
/// identifies the number of test methods (including combinations), it emits those test methods with
/// a separate test instance per method (per usual junit practice), but this time for each method
/// (i.e. test instance), the return value of `chooseFrom` will be chosen based on the test's
/// index.
///
/// It is crucial that the arguments to [#chooseFrom(Object\[\])] methods are all effectively
/// "constants" from the perspective of the rest of the test code. So, they shouldn't be doing any
/// real work apart from configuring themselves for later work. The same applies to the arguments of
/// [#chooseFrom(SharedTestRule\[\])]. A good rule of thumb to follow is this: Imagine all the
/// arguments to a `chooseFrom` method to be static final objects and the LHS variable that the
/// result is assigned to is an instance field. If your code would still compile, `chooseFrom`
/// behaves like you'd naturally guess. The best practice indeed is to use static final constants
/// for parameter values (but it is not enforced for convenience), like so:
/// ```
/// private static final DbTestCase pg = postgres(), yb = yugabyte();
/// private final DbTestCase dbTestCase = SharedRules.chooseFrom(pg, yb);
/// ```
///
/// Tests will be descriptively named based on their parameters. For example,
/// ```
/// int first = chooseFrom(1, 2);
/// String second = chooseFrom("a", "b");
/// SharedTestRule myRule = chooseFrom(new MySharedRule("sr1"), new MySharedRule("sr2"));
///
/// @Test
/// void testname() { }
///
/// ```
/// the first test will be named `testname_first[1]_second[a]_myRule[msr[sr1]]` assuming that
/// `MySharedRule("sr1")` implements its [SharedTestRule#descriptionString()] method to return `
/// "msr[sr1]"`. The field name is inferred (e.g. first, second) and then the either the description
/// string of the chosen value (for `SharedTestRule`s) or the `toString()` value (for the rest) is
/// used to describe the field's selected value. The contributions from each parametric field are
/// then concatenated.
///
/// The `chooseFrom` methods reject `null` arguments and empty args list.
public final class ClassParam {

  @SafeVarargs
  public static <W extends SharedTestRule> W chooseFrom(W... candidates) {
    sanityCheck(candidates);
    SharedRuleChain.Builder builder = SharedRuleChain.getBuilder(
        testIndex(),
        sanityCheckFieldNames(getFieldNames()));
    AtomicReference<W> w = new AtomicReference<>();
    builder.nextInnerShared(w::set, candidates);
    return w.get();
  }

  @SafeVarargs
  public static <W> W chooseFrom(W... candidates) {
    sanityCheck(candidates);
    SharedRuleChain.Builder builder = SharedRuleChain.getBuilder(
        testIndex(),
        sanityCheckFieldNames(getFieldNames()));
    AtomicReference<W> w = new AtomicReference<>();
    builder.nextInnerNonShared(w::set, candidates);
    return w.get();
  }

  private static FieldNames getFieldNames() {
    var testClass = testClassFromScope();
    return QuietCaller.call(() -> FieldInitAnalyzer.getInitializedFields(
            new FieldInitsRequest(testClass, ClassParam.class.getName(), "chooseFrom")))
        .orThrow(RuntimeException.class,
            "Unabled to obtain field names: testclass = %s, paramsclass = %s",
            testClass.getName(), ClassParam.class.getName());
  }

  private static <W> void sanityCheck(W[] candidates) {
    Preconditions.checkArgument(candidates.length > 0);
    for (int i = 0; i < candidates.length; i++) {
      Preconditions.checkNotNull(candidates[i], "Element at index %s is null", i);
    }
  }

  private static FieldNames sanityCheckFieldNames(FieldNames fieldNames) {
    Preconditions.checkArgument(fieldNames.staticFields().isEmpty(), """
        The result of %s.chooseFrom(...) should not be assigned to static fields.
        But, the following static fields were assigned to.
        %s
        """, ClassParam.class.getSimpleName(), String.join("\n", fieldNames.staticFields()));
    return fieldNames;
  }

  private static Class<?> testClassFromScope() {
    return EvalContext.sharedRuleContext().testClass();
  }

  private static int testIndex() {
    return EvalContext.testIndex();
  }
}
