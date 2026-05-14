package com.vemana.common.performance.jmh;

import com.vemana.common.performance.jmh.testing.JmhAssert;
import com.vemana.common.testing.ParallelTestsConfig;
import com.vemana.common.testing.TestConfig;
import com.vemana.common.testing.VTestRunner;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

import java.util.concurrent.TimeUnit;

@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(platformThreads = 4))
public class JmhRunnerTest {

  @Test
  public void normalTest() {

  }

  @Benchmark
  @BenchmarkMode({Mode.AverageTime})
  @Fork(value = 1)
  @Measurement(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @OutputTimeUnit(TimeUnit.NANOSECONDS)
  @Group("MY_GROUP")
  @GroupThreads(1)
  @JmhAssert(avgt_max_nanos = 120, avgt_max_seconds = 120e-9)
  @JmhAssert(alloc_max_B_per_op = 120)
  @JmhAssert(is_group_metric = true, avgt_max_nanos = 70)
  public void a1_first(Blackhole bh) {
    int x = 100;
    for (int i = 0; i < 1000; i++) {
      x = x * 2 + 3;
      bh.consume(x);
    }
  }

  @Benchmark
  @Group("MY_GROUP")
  @GroupThreads(1)
  @JmhAssert(avgt_max_nanos = 20)
  public void a1_second(Blackhole bh) {
    int x = 100;
    for (int i = 0; i < 100; i++) {
      x = x * 2 + 3;
      bh.consume(x);
    }
  }

  @Benchmark
  @BenchmarkMode(Mode.Throughput)
  @Fork(value = 1)
  @Measurement(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @JmhAssert(thrpt_min_ops_per_ns = 0.05)
  @OutputTimeUnit(TimeUnit.NANOSECONDS)
  public void simple_addition_test_thrpt_per_ns(Blackhole bh) {
    int x = 100;
    for (int i = 0; i < 100; i++) {
      x = x * 2 + 3;
      bh.consume(x);
    }
  }

  @Benchmark
  @BenchmarkMode(Mode.Throughput)
  @Fork(value = 1)
  @Measurement(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 1, time = 1, timeUnit = TimeUnit.SECONDS)
  @JmhAssert(thrpt_min_ops_per_sec = 5e7)
  @OutputTimeUnit(TimeUnit.NANOSECONDS)
  public void simple_addition_test_thrpt_per_sec(Blackhole bh) {
    int x = 100;
    for (int i = 0; i < 100; i++) {
      x = x * 2 + 3;
      bh.consume(x);
    }
  }
}
