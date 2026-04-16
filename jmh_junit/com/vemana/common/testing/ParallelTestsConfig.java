package com.vemana.common.testing;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import java.util.concurrent.Executors;

/// Configuration for parallel testing. By default, JUnit prescribes serial testing of test cases.
/// But [VTestRunner] can run test methods in parallel while sharing the same static setup
/// between then.
///
/// It is tricky to have parallel tests working because they will run into resource issues.
/// For example, you can quickly run out of database connections if you have 100 tests in parallel
/// and the db has a 100 connection limit. So, in that sense, more coordination is required to have
/// tests run in parallel.
///
/// Running tests in parallel does have one great advantage: it cuts down iteration time. So, it
/// is a balance and caution should be exercised in choosing this method. Test sharding in Bazel is
/// also a viable alternative except that it uses extra CPU since it repeats the test setup for each
/// shard. So, if you are running on a local workstation, it is perhaps better to iterate using this
/// runner than using Bazel shards.
///
/// When this is specified on a test class, even JMH tests will run in parallel. JMH tests are
/// generally recommended to be run in serial; but if you have enough cores that can isolate the
/// effects, using parallelism can cut down iteration time without necessarily interfering with
/// test results (assuming a decent OS scheduling).
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface ParallelTestsConfig {

  /**
   * The number of threads that methods will be parallelized into. A threadpool Executor will be
   * used to multiplex all the test methods. This value determines the size of the threadpool.
   *
   * <p>A value less than 1 specifies an unbounded threadpool.
   */
  int platformThreads() default 5;

  /**
   * Whether to use virtual threads. If set, a {@link Executors#newVirtualThreadPerTaskExecutor()}
   * will be used to run the test methods. {@link ParallelTestsConfig#platformThreads()} is
   * not meaningful when this is true.
   */
  boolean useVirtualThreads() default false;
}
