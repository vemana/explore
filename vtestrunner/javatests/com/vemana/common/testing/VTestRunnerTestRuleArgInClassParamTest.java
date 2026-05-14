package com.vemana.common.testing;

import org.junit.AfterClass;
import org.junit.Assert;
import org.junit.Test;
import org.junit.rules.TestRule;
import org.junit.runner.Description;
import org.junit.runner.RunWith;
import org.junit.runners.model.Statement;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;


/// Test that TestRules that are not SharedTestRules will NOT run their rules when chosen via
/// [ClassParam#chooseFrom(Object\[\])]. They are treated like regular objects. Focus
/// - Class Parameters only
/// - Parameters specify TestRules (but not SharedTestRules). These will NOT run their rule impls.
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(useVirtualThreads = true))
public class VTestRunnerTestRuleArgInClassParamTest {

  static final ThreadLocal<Integer> value = new ThreadLocal<>();
  static Set<Integer> seenValues = Collections.synchronizedSet(new HashSet<>());

  @AfterClass
  public static void verify() {
    Set<Integer> expected = new HashSet<>();
    expected.add(null);
    Assert.assertEquals("Seenvalues differed", expected, seenValues);
  }

  // This WILL NOT run the myRule; only selects between the various rules.
  // If this rule runs, `value` will get set and we verify that it doesn't
  final MyTestRule myRule = ClassParam.chooseFrom(new MyTestRule(1), new MyTestRule(2));

  @Test
  public void basic() {
    Assert.assertNull(value.get());
    seenValues.add(value.get());
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
  }
}