package com.vemana.common.performance.jmh.testing;

import com.google.common.truth.Expect;
import org.junit.runners.model.Statement;
import org.openjdk.jmh.results.RunResult;
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.RunnerException;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;

import java.util.Collection;

class BenchmarkStatement extends Statement {

  private final BenchmarkMethod bg;
  private final Object test;
  private final ExpectVerifier verifier;

  BenchmarkStatement(BenchmarkMethod bg, Object test, Expect expect) {
    this.bg = bg;
    this.test = test;
    this.verifier = new ExpectVerifier(expect);
  }

  @Override
  public void evaluate() throws Throwable {
    OptionsBuilder ob = new OptionsBuilder();
    ob.include(bg.uniqueRegex());
    addWarmupIterationSpec(ob, bg.warmupIterationSpec());
    addMeasurementIterationSpec(ob, bg.measurementIterationSpec());
    bg.forks().ifPresent(ob::forks);
    bg.profilers().forEach(ob::addProfiler);
    Options options = ob.build();
    runJmhAndVerify(options);
  }

  void runJmhAndVerify(Options options) throws RunnerException {
    Runner runner = new Runner(options);
    Collection<RunResult> results = runner.run();
    if (results.size() != 1)
      throw new RuntimeException("Unexpected size of results: %s".formatted(results.size()));
    var result = results.stream().findFirst().get();
    for (var expect : bg.expectations()) {
      verifier.verify(expect, result);
    }
  }

  private void addMeasurementIterationSpec(OptionsBuilder ob, IterationSpec iterationSpec) {
    iterationSpec.iterations().ifPresent(ob::measurementIterations);
    iterationSpec.duration().ifPresent(ob::measurementTime);
  }

  private void addWarmupIterationSpec(OptionsBuilder ob, IterationSpec iterationSpec) {
    iterationSpec.iterations().ifPresent(ob::warmupIterations);
    iterationSpec.duration().ifPresent(ob::warmupTime);
  }
}
