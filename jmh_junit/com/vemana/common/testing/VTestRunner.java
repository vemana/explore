package com.vemana.common.testing;

import com.vemana.common.performance.jmh.testing.JmhJunitSupport;
import org.junit.runners.BlockJUnit4ClassRunner;
import org.junit.runners.model.FrameworkMethod;
import org.junit.runners.model.InitializationError;
import org.junit.runners.model.RunnerScheduler;
import org.junit.runners.model.Statement;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/// A JUnit4 test runner that offers test parallelization and JMH benchmarks with assertions.
///
/// How to use:
/// - Just set this class as the runner and you get default JUnit4 runner behavior
/// - Add [TestConfig#parallelize()] to the test class to run tests in parallel
/// - Any _JMH Benchmark_ methods will be run using JMH. These methods are identified using
///   standad JMH convention: specifying the [org.openjdk.jmh.annotations.Benchmark] annotation. The
///   methods can even specify [com.vemana.common.performance.jmh.testing.JmhAssert] assertions
///   which will be asserted against observed metrics evaluated by JMH.
///
/// JMH tests will run in parallel too - asking for parallelism is no different between having
/// JMH benchmark methods in the test class and otherwise.
public class VTestRunner extends BlockJUnit4ClassRunner {

  private final Set<FrameworkMethod> jmhMethods;

  public VTestRunner(Class<?> testClass) throws InitializationError {
    super(testClass);

    // parallelization
    TestConfig testConfig = testClass.getAnnotation(TestConfig.class);
    ParallelTestsConfig parallelConfig = testConfig != null ? testConfig.parallelize() : null;
    if (parallelConfig != null) {
      setScheduler(new Parallelizer(parallelConfig));
      System.setProperty("jmh.ignoreLock", "true");
    }
    
    jmhMethods = new HashSet<>(JmhJunitSupport.jmhTestMethods(getTestClass()));
  }

  @Override
  protected List<FrameworkMethod> computeTestMethods() {
    ArrayList<FrameworkMethod> methods = new ArrayList<>();
    methods.addAll(super.computeTestMethods());
    methods.addAll(JmhJunitSupport.jmhTestMethods(getTestClass()));
    return methods;
  }

  @Override
  protected Statement methodInvoker(FrameworkMethod method, Object test) {
    return jmhMethods.contains(method)
        ? JmhJunitSupport.jmhMethodInvoker(method, test, this::describeChild)
        : super.methodInvoker(method, test);
  }

  private static class Parallelizer implements RunnerScheduler {
    private final ExecutorService service;

    Parallelizer(ParallelTestsConfig config) {
      service =
          config.useVirtualThreads()
              ? Executors.newVirtualThreadPerTaskExecutor()
              : (config.platformThreads() < 1
                  ? Executors.newCachedThreadPool()
                  : Executors.newFixedThreadPool(config.platformThreads()));
    }

    @Override
    public void finished() {
      try {
        service.shutdown();
        service.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
      } catch (InterruptedException e) {
        e.printStackTrace(System.err);
        throw new RuntimeException(e);
      }
    }

    @Override
    public void schedule(Runnable runnable) {
      service.submit(runnable);
    }
  }
}
