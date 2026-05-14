package com.vemana.common.testing;

import com.google.common.base.Preconditions;
import com.vemana.common.error.QuietCaller;
import com.vemana.common.testing.internal.*;

/// Use me to perform parametric testing with method parameters. I am the method-level analogue of
/// the class-level [Parameters]. I offer the [#chooseFrom(Object\[\])] method which defines a
/// method parameter. You can then use it as a method parameter by declaring an argument with the
/// same name.
///
/// ```
/// String city = Parameters.chooseFrom("Denver", "NYC");
/// public MethodParam<Integer> age = MethodParam.chooseFrom(20, 40, 60);
/// public MethodParam<Integer> height = MethodParam.chooseFrom(170, 180);
/// public MethodParam<String> name = MethodParam.chooseFrom("Alice", "Bob");
///
/// @TestAnnotations.TestWithParameters
/// public void basic_my_test(int age, String name) {
/// // This will run one test each for a combination of
/// // City: "Denver", "NYC"
/// // age in [20, 40, 60]
/// // name in ["Alice", "Bob"]
///
/// // Note how the name and age share the same name as the field declaring the MethodParam
///
/// // When this test runs, the unset method parameter `height` is set to null to prevent
/// // accidental misuse - since it is not defined. This is the main reason we return
/// // MethodParam<T> instead of T from MethodParam.chooseFrom(...)
/// }
///
/// ```
///
/// Be aware of the following
/// - the method param field should be public. `public MethodParam height ...`
/// - inheritance works like you expect (again, method param fields should be public)
/// - test naming follows the class-level first then the method-level description
public class MethodParam<T> {

  @SuppressWarnings("unchecked")
  public static <T> MethodParam<T> chooseFrom(T... choices) {
    Preconditions.checkArgument(choices.length > 0, "Provide at least one choice");
    var fields = sanityCheckFieldNames(getFieldNames());
    var fieldNames = fields.fieldNames();
    MethodLevelIndexContext mlic = EvalContext.methodLevelIndexContext();
    int myLevel = mlic.level();
    mlic.addLevel();

    var paramName = fieldNames.get(myLevel);
    var mpc = EvalContext.methodParamContext();
    if (EvalContext.inAssignmentPhase()) {
      int methodIndex = EvalContext.methodIndex();
      if (methodIndex >= 0 && mpc.isEnabled(methodIndex, paramName)) {
        T resolved1 = (T) mpc.getChoice(methodIndex, paramName);
        return new MethodParam<>(resolved1);
      } else {
        return null;
      }
    } else {
      mpc.addChoices(fieldNames.get(myLevel), choices);
      return new MethodParam<>(choices[0]);
    }
  }

  private static FieldNames getFieldNames() {
    var testClass = EvalContext.sharedRuleContext().testClass();
    var fieldNames = QuietCaller.call(() -> FieldInitAnalyzer.getInitializedFields(
            new FieldInitsRequest(testClass, MethodParam.class.getName(), "chooseFrom")))
        .orThrow(RuntimeException.class,
            "Unabled to obtain field names: testclass = %s, paramsclass = %s",
            testClass.getName(), MethodParam.class.getName());
    return fieldNames;
  }

  private static FieldNames sanityCheckFieldNames(FieldNames fieldNames) {
    Preconditions.checkArgument(fieldNames.staticFields().isEmpty(), """
        The result of %s.chooseFrom(...) should not be assigned to static fields.
        But, the following static fields were assigned to.
        %s
        """, MethodParam.class.getSimpleName(), String.join("\n", fieldNames.staticFields()));
    return fieldNames;
  }

  private final T resolved;

  MethodParam(T resolved) {
    this.resolved = resolved;
  }

  public T get() {
    return resolved;
  }
}
