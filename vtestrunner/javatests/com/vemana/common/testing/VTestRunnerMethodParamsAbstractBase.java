package com.vemana.common.testing;

import com.google.common.truth.Expect;
import com.vemana.common.testing.internal.EvalContext;
import org.junit.Rule;

/// Focus
/// - Class Parameters only
/// - Inheritance of test methods
/// - Test naming
@SuppressWarnings("ClassEscapesDefinedScope")
public abstract class VTestRunnerMethodParamsAbstractBase {


  @Rule public final Expect expectBase = Expect.create();
  @Rule public final ActiveTestMethod activeTestMethodBase = ActiveTestMethod.create();

  public MethodParam<Integer> first = MethodParam.chooseFrom(1, 2, 3);
  public MethodParam<SimpleRule> second =
      MethodParam.chooseFrom(new SimpleRule("id1"), new SimpleRule("id2"));

  @TestAnnotations.TestWithParameters
  public void basicBase(int first, SimpleRule second) {
    String testName = activeTestMethodBase.activeDescription().getDisplayName();
    expectBase.that(testName).contains("basicBase");
    expectBase.that(testName).contains("_first[%s]".formatted(first));
    expectBase.that(testName).contains("[%s]".formatted(second.descriptionString()));
    int midx = EvalContext.methodComboIndex();
    if (midx == 0) {
      expectBase.that(testName).startsWith("basicBase_first[1]_second[SR[id1]]");
    }
  }
}