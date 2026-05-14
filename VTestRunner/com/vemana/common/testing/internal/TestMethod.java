package com.vemana.common.testing.internal;

import com.vemana.common.error.QuietCaller;
import org.junit.runners.model.FrameworkMethod;
import org.junit.runners.model.Statement;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.function.Function;

public abstract sealed class TestMethod extends FrameworkMethod
    permits TestMethod.JmhMethod, TestMethod.MethodWithParameters, TestMethod.RegularMethod {

  public TestMethod(Method method) {
    super(method);
  }

  public static final class JmhMethod extends TestMethod {

    public final FrameworkMethod frameworkMethod;

    public JmhMethod(FrameworkMethod frameworkMethod) {
      super(frameworkMethod.getMethod());
      this.frameworkMethod = frameworkMethod;
    }
  }

  public static final class MethodWithParameters extends TestMethod {

    public final int midx;
    public final int mcidx;
    public final LinkedHashMap<String, Integer> paramChoices;
    private final List<String> paramNames;
    private final Field[] fields;

    public MethodWithParameters(Method method
        , int midx
        , int mcidx
        , Class<?> testClass
        // key order matters
        , LinkedHashMap<String, Integer> paramChoices) {
      super(method);
      this.midx = midx;
      this.mcidx = mcidx;
      this.paramNames = paramChoices.keySet().stream().toList();
      this.paramChoices = new LinkedHashMap<>(paramChoices);
      this.fields = getFields(testClass);
    }

    public Statement methodInvoker(Object test, Function<Object, Object> fieldToArg) {
      return new Statement() {
        @Override
        public void evaluate() throws Throwable {
          Object[] params = new Object[fields.length];
          for (int idx = 0; idx < fields.length; idx++) {
            Field field = fields[idx];
            var fieldValue = QuietCaller.call(() -> field.get(test))
                .orThrow(RuntimeException.class
                    , "Unable to evaluate field [%s] against the test instance of type [%s]"
                    , field.getName(), test.getClass().getName());
            params[idx] = fieldToArg.apply(fieldValue);
          }
          try {
            getMethod().invoke(test, params);
          } catch (InvocationTargetException ex) {
            // Pass through the exception
            throw ex.getTargetException();
          }
        }
      };
    }

    @Override
    public String toString() {
      return "MethodWithParameters{" +
             "method=" + super.getMethod().getName() +
             ", midx=" + midx +
             ", paramChoices=" + paramChoices +
             ", paramNames=" + paramNames +
             ", fields=" + Arrays.toString(fields) +
             '}';
    }

    private Field[] getFields(Class<?> testClass) {
      int nParams = paramNames.size();
      Field[] fields = new Field[nParams];
      int fidx = 0;
      for (var fieldName : paramNames) {
        fields[fidx++] = QuietCaller.call(() -> testClass.getField(fieldName))
            .map(f -> {
              f.setAccessible(true);
              return f;
            })
            .orThrow(RuntimeException.class
                , "Unable to find PUBLIC field [%s] in class hierarchy of [%s]"
                , fieldName
                , testClass.getName());
      }
      return fields;
    }
  }

  public static final class RegularMethod extends TestMethod {
    public final FrameworkMethod frameworkMethod;

    public RegularMethod(FrameworkMethod frameworkMethod) {
      super(frameworkMethod.getMethod());
      this.frameworkMethod = frameworkMethod;
    }
  }
}
