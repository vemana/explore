package com.vemana.common.testing;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

public interface TestAnnotations {

  /**
   * A scale of how important the missing test is.
   */
  enum Importance {
    LOW,
    MEDIUM,
    HIGH,
  }

  enum MissingTestReason {
    FEATURE_NOT_IMPLEMENTED,
    TEST_NOT_IMPLEMENTED,
  }

  @Target(ElementType.METHOD)
  @Retention(RetentionPolicy.RUNTIME)
  @interface MissingTest {
    String description() default "";

    Importance importance() default Importance.LOW;

    MissingTestReason reason();
  }

  /// Represents a test with method parameters.
  @Target(ElementType.METHOD)
  @Retention(RetentionPolicy.RUNTIME)
  @interface TestWithParameters {

  }
}
