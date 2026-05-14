package com.vemana.common.performance.jmh.testing;

import java.lang.annotation.*;

/// Delcarattive asserts on JMH produced microbenchmark data for use in unit tests.
///
/// ```
/// @RunWith(JmhTestRunner.class)
/// public class JmhRunnerTest {
///
///   @Benchmark
///   @BenchmarkMode({Mode.AverageTime})
///   @Group("MY_GROUP")
///   @GroupThreads(1)
///   @JmhAssert(avgt_max_nanos = 120, avgt_max_seconds = 120e-9)
///   @JmhAssert(alloc_max_B_per_op = 120)
///   @JmhAssert(is_group_metric = true, avgt_max_nanos = 70)
///   public void a1_first(Blackhole bh) {
///     int x = 100;
///     for (int i = 0; i < 1000; i++) {
///       x = x * 2 + 3;
///       bh.consume(x);
///     }
///   }
///
///   @Benchmark
///   @Group("MY_GROUP")
///   @GroupThreads(1)
///   @JmhAssert(avgt_max_nanos = 20)
///   public void a1_second(Blackhole bh) {
///     int x = 100;
///     for (int i = 0; i < 100; i++) {
///       x = x * 2 + 3;
///       bh.consume(x);
///     }
///   }
/// }
///
/// ```
@Repeatable(JmhAssert.JmhAssertArray.class)
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface JmhAssert {
  /// Assert bytes allocated per op. Implies gc profiler.
  double alloc_max_B_per_op() default -1;

  double avgt_max_nanos() default -1;

  double avgt_max_seconds() default -1;

  double thrpt_min_ops_per_sec() default -1;

  double thrpt_min_ops_per_ns() default -1;

  /// Whether this expectation is for the entire group
  boolean is_group_metric() default false;

  @Retention(RetentionPolicy.RUNTIME)
  @Target(ElementType.METHOD)
  @interface JmhAssertArray {
    JmhAssert[] value();
  }
}
