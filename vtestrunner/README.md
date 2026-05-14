# What's this?

`VTestRunner` is a Java library that exports a Junit4 Testrunner.

---

# Why this library and Why Junit4 (not 6+)?
Junit5+ versions use an extension mechanism which relies heavily on annotations. As anyone who's used annotation based libraries/frameworks knows, it leads to unreadable and brittle code over time. This library restores much of the goodness that extensions enable without paying for it through murky annotations.

VTestRunner offers the following features:
- Parametric testing with Class level parameters
  - No magic, plain API 
  - Define your params`public int iterations = ClassParam.chooseFrom(1, 100, 10000)`
  - Every test will run with every possible value of your params.
- Parametric testing with Method level parameters
  - No magic, plain API
  - Define your params`public MethodParam<Integer> iterations = MethodParam.chooseFrom(1,10,100);`
  - Use your params `@TestWithParameters public void test_with_params(int iterations) {...}`
- JMH support
  - Run JMH benchmarks as a regular test & avoid custom CI setups
  - Perform assertions on the metrics obtained from those JMH benchmarks & catch regressions in perf-critical code
  - Ergonomic assertions: `@JmhAssert(avgt_max_nanos = 20) @Benchmark public void my_benchmark(Blackhole bh) {}`
- Parallel tests
  - Run tests in parallel and cut down on iteration time. All the above features work with parallel threads
  - Ergomically specify parallelism `@TestConfig(parallelize = @ParallelTestsConfig(platformThreads = 4))`
  - Valuable on tests that start a server and execute a ton of tests talking to the server
  - Example: If your server startsup in 10 secs and 20 tests take 1 sec each, your iteration time is 30 secs. If you can spare 20 threads, your iteration time is 11 secs. **30 secs -> 10 secs** by parallelizing tests.
  - You can run parallel tests either using Virtual Threads or Platform threads. JMH typically wants platform threads and I/O bound ones like virtual threads. Note: you shouldn't be trust JMH benchmarks unless cores are truly free from interference. So, take care when running JMH tests in parallel.
- Efficiency
  - Class level parameters that would typically be static `ClassRule`s (e.g. Database Rules) can implement `SharedTestRule` interface and run only once even when used as a Class-level parameter, instead of once per test case
- Overall
  - The mantra is `Let the SWEs focus on tests and have them remember very little to use VTestRunner`.
  - It is designed to work like you'd guess

Obviously, `VTestRunner` cannot do everything that Junit5+ can do. By giving up the ability to (a) Accept third party code (b) Extend test running lifecycle, we can get a no-magic API that still covers perhaps 95% of usage.

---

# FAQ

**Are there any API-level restrictions?**

There are no known restrictions. That is, you don't need to remember anything specific to this runner. Perhaps the one thing worth mentioning is that if you have fields in your test class, JMH doesn't like them. So, if you plan to write any JMH test in your test class, avoid fields. This also means that JMH tests will have to use native JMH parametrization instead of `ClassParam` and `MethodParam`.

---
**Are there any environment restrictions?** What version of Java?

Yes, there are.
- It requires a stable ClassFileApi (exited preview into final in JDK 24)
- Your test class to be compiled with "-parameters"

Why?
- It uses Java's ClassFileApi to read bytecode of the test class to know the declared method and class parameter fields. This choice avoids annotations and keeps the API ergonomic. This version is tested on Java 26's ClassFileApi, but should run anywhere the ClassFileApi is stable.
- The `-parameters` javac flag preserves method argument names. The test runner matches these arg names against declared method parameter fields in the test class when invoking a test with method parameters.

---
**Can I extend it?**

The library written to be valuable today but extensible
- A look at the `methodInvoker` in `VTestRunner` should tell any experienced engineer how to extend it.
- Easy to add custom time units, metrics from profilers like GC etc

---
**Why are JMH asserts done via annotations**?

Because of the guiding **principle**: If you know JMH, the additional knowledge you need to use this library should be minimal. Right now, it just requires you to remember adding `@JmhAssert(...)` assertions on `@Benchmark` method and we get to keep assertions out of the benchmark code. Besides, assertions on JMH benchmarks are easily expressible as annotations because they are simple predicates like `throughput > 10 ops/sec` or `latency < 5 secs/op`.

---
**Where can I get the library?**

Like I explained in the top level [README](../README.md), this repo is meant to be a source code only thing. I don't provide a compiled jar because this is from my monorepo and it is somewhat difficult to extract and make a library available out of it. Most of the code required to build it (see the `BUILD.bazel`) is exported here on a best-effort basis, but there may be missing pieces.

---

# USAGE
The Testrunner is [VTestRunner](com/vemana/common/testing/VTestRunner.java). See its javadoc and inline examples below.


---
The following test demonstrates **class and method parameters**. Note the lack of annotations and clear, explicit definition of class level and method level parameters. Rules that implement the `SharedTestRule` interface (like the `DbTestCase` here) make the tests efficient by starting up only once across all combinations using it.
```java

  // Method level parameters. These have to be declared public (for now; until I get around to fixing it)
  // These are intentionally declared MethodParam<T> to avoid using them from tests that
  // don't inject them as method parameters. See example below for details.
  public final MethodParam<Integer> stressIters = MethodParam.chooseFrom(1, 100, 10000);
  public final MethodParam<String> stressType = MethodParam.chooseFrom("get", "put");
  public final MethodParam<Integer> query_timeout_ms = MethodParam.chooseFrom(500, 1000);

  // Class level parameters. 2 * 2 commbinations here.
  // Here, DbTestCase implements `SharedTestRule` which means it supports sharing its rule across parallel tests.
  // This means that DbTestCase is thread safe and only starts the Db instance once. There are only two such
  // DbTestCase instances created here - the postgres & yugabyte ones. Half the tests get Postgres & the other
  // half get the Yugabyte one. 
  private final DbTestCase dbTestCase = ClassParam.chooseFrom(DbTestCase.postgres_18_3(), DbTestCase.yugabyte_2025_140());
  private final int maxConnections = ClassParam.chooseFrom(2, 10);

  // create datasource using class level parameters
  DataSource dataSource = new MyDataSource(dbTestCase, maxConnections);

  // All standard Junit annotations work like normal: @ClassRule, @Rule, @Before etc

  // Note: stressIters argument name matches stressIters field name.
  @TestAnnotations.TestWithParameters
  public void perf_test(int stressIters, String stressType) {
    // Runs db x max_connections x stressIters x stressType combinations
    // 2 x 2 x 3 x 2 = 24

    // During execution of this method, query_timeout_ms` will be null to avoid an undeclared dependency.
    // The return type of MethodParam.chooseFrom(..) is intentionally MethodParam rather than
    // the chosen object (like with ClassParam). MethodParam instances have values only as method
    // parameters and they are null otherwise.
  }

  @Test
  public void regular_test() {
    // Runs db x max_connections combinations. All method parameters are null here.
  }
```


---
This **JMH example** demonstrates a few aspects

```java
@RunWith(VTestRunner.class) // The test runner
// Run tests in parallel using platform threads. You can also specify virtual threads.
// Leave this out run tests serially.
// Note: running Jmh tests in parallel may skew results.
@TestConfig(parallelize = @ParallelTestsConfig(platformThreads = 4))
public class JmhRunnerTest {

  // Measurement/Warmup/Fork only need to be specified on one member of the group.
  // If multiply specified, the runner verifies they are equal (JMH doesn't & picks one randomly!)
  @Benchmark
  @BenchmarkMode({Mode.AverageTime})
  @Fork(value = 1)
  @Measurement(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
  @Warmup(iterations = 3, time = 1, timeUnit = TimeUnit.SECONDS)
  @OutputTimeUnit(TimeUnit.NANOSECONDS)                       // Use standard JMH annotations
  @Group("MY_GROUP")                                          // Supports @Group methods tood
  @GroupThreads(1)
  @JmhAssert(avgt_max_nanos = 120, avgt_max_seconds = 120e-9) // Specify assertion in any units you like
  @JmhAssert(alloc_max_B_per_op = 120)                        // Specify various kinds of assertions
  @JmhAssert(is_group_metric = true, avgt_max_nanos = 70)     // Specify group-level assertions
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

  @Test
  public void normalTest() {
    // You can even have other tests. But, remember that JMH Runner doesn't like fields in the JMH class
    // So, if you mix regular tests with JMH tests, you can't use fields (like @Rule). This is a JMH
    // restriction, not VTestRunner's.
  }
}

```

