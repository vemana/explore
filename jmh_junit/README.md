# What's this?

This is a Java library that exports a Junit4 Testrunner. 

---
# Why?
The Testrunner offers some useful features:
- Run JMH benchmarks as a regular test & avoid custom CI setups
- Perform assertions on the metrics obtained from those JMH benchmarks & catch regressions in perf-critical code
- Run tests in parallel and cut down on iteration time 
  - Valuable on tests that start a server and execute a ton of tests talking to the server
  - Example: If your server startsup 10 secs and 20 tests take 1 sec each, your iteration time is 30 secs. If you can spare 20 threads, your iteration time is 11 secs. **30 secs -> 10 secs** by parallelizing tests.
- You can run parallel tests either using Virtual Threads or Platform threads
  - For JMH tests, you typically want platform threads
  - For I/O bound tests (typical in integration tests), Virtual Threads will do nicely.
- Run JMH Benchmarks in parallel and cut down iteration time

Of course, I assume you know what you are doing with JMH. You shouldn't be trust JMH benchmarks unless cores are truly free from interference. So, take care when running JMH tests in parallel.

---

# FAQ

**Are there any restrictions?**

There are no known restrictions; just write your benchmarks like normal and add assertions. That is, you don't need to remember anything specific to this runner

---
**Can I extend it?**

The library written to be valuable today but extensible
- A look at the `methodInvoker` in `VTestRunner` should tell any experienced engineer how to extend it.
- Easy to add custom time units, metrics from profilers like GC etc

---
**Why are asserts done via annotations**?

Because of the guiding **principle**: If you know JMH, the additional knowledge you need to use this library should be minimal. Right now, it just requires you to remember adding `@JmhAssert(...)` assertions on `@Benchmark` method and we get to keep assertions out of the benchmark code. Besides, assertions on JMH benchmarks are easily expressible as annotations because they are simple predicates like `throughput > 10 ops/sec` or `latency < 5 secs/op`.


---
# How to use?
The Testrunner is [VTestRunner](com/vemana/common/testing/VTestRunner.java). See its javadoc and inline examples below. Note the following.
- `@TestConfig(parallelize = ...)` annotation on the class. Tests will be run in parallel.
- `@JmhAssert(..)` annotations on JMH benchmark test methods
- Note how you can mix and match regular `@Test` with JMH methods
- All the usual JUnit4 annotations like `@Rule`, `@ClassRule`, `@Test`, `@Setup`, `@TearDown` work normally (not shown here)

So, your mental model can be `Leave the testing to the Testrunner; let me focus on my tests.`

```java
@RunWith(VTestRunner.class)
@TestConfig(parallelize = @ParallelTestsConfig(platformThreads = 4))
public class JmhRunnerTest {

  @Test
  public void normalTest() {
    // You can mix and match regular tests with JMH tests.
  }

  @Benchmark
  @BenchmarkMode({Mode.AverageTime})
  @Fork(value = 1)
  @Measurement(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
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
  @Measurement(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
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
  @Measurement(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
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

```


