package com.vemana.common.performance.jmh.testing;

import com.google.common.base.Preconditions;
import org.openjdk.jmh.annotations.Measurement;
import org.openjdk.jmh.annotations.Warmup;
import org.openjdk.jmh.runner.options.TimeValue;

import java.util.Optional;
import java.util.concurrent.TimeUnit;

record IterationSpec(Optional<Integer> iterations, Optional<TimeValue> duration) {

  static IterationSpec none() {
    return new IterationSpec(Optional.empty(), Optional.empty());
  }

  private static IterationSpec of(int iterations, int time, TimeUnit timeUnit) {
    Optional<TimeValue> dur = time < 0
        ? Optional.empty()
        : Optional.of(new TimeValue(time, timeUnit));

    Optional<Integer> iters = iterations < 0
        ? Optional.empty()
        : Optional.of(iterations);

    return new IterationSpec(iters, dur);
  }

  static IterationSpec of(Measurement ann) {
    return of(ann.iterations(), ann.time(), ann.timeUnit());
  }

  static IterationSpec of(Warmup ann) {
    return of(ann.iterations(), ann.time(), ann.timeUnit());
  }

  boolean hasDuration() {
    return duration.isPresent();
  }

  boolean hasIterations() {
    return iterations.isPresent();
  }

  IterationSpec merge(IterationSpec that) {
    Preconditions.checkArgument(
        !(hasIterations() && that.hasIterations() && !iterations.equals(that.iterations)),
        "@Warump.iterations argument was different across group members [%s] vs [%s]",
        this, that);
    Preconditions.checkArgument(
        !(hasDuration() && that.hasDuration() && !duration.equals(that.duration)),
        "@Warmup.duration argument was different across group members [%s] vs [%s]",
        this, that
    );

    return new IterationSpec(
        iterations.or(() -> that.iterations),
        duration.or(() -> that.duration));
  }
}
