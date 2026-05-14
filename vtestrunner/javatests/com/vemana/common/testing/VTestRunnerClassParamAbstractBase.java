package com.vemana.common.testing;

import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.Rule;
import org.junit.Test;

/// Focus
/// - Class Parameters only
/// - Inheritance of test methods
/// - Test naming
public abstract class VTestRunnerClassParamAbstractBase {

  @Rule public final Expect expectBase = Expect.create();
  @Rule public final ActiveTestMethod activeTestMethodBase = ActiveTestMethod.create();

  int first = ClassParam.chooseFrom(1, 2);
  SimpleRule second = ClassParam.chooseFrom(new SimpleRule("id1"), new SimpleRule("id2"));

  @Test
  public void basicBase() {
    String testName = activeTestMethodBase.activeDescription().getDisplayName();
    expectBase.that(testName).contains("basicBase");
    expectBase.that(testName).contains("_first[%s]".formatted(first));
    expectBase.that(testName).contains("[%s]".formatted(second.descriptionString()));
    int testIndex = EvalContext.testIndex();
    if (testIndex == 0) {
      expectBase.that(testName).startsWith("basicBase_first[1]_second[SR[id1]]");
    }
  }
}