package com.vemana.common.testing;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/// Configuration for the [VTestRunner] runner.
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface TestConfig {
  ParallelTestsConfig parallelize() default @ParallelTestsConfig;
}
