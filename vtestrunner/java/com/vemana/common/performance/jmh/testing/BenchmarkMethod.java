package com.vemana.common.performance.jmh.testing;

import com.google.common.base.Preconditions;
import org.junit.runners.model.FrameworkMethod;
import org.openjdk.jmh.annotations.Fork;
import org.openjdk.jmh.annotations.Measurement;
import org.openjdk.jmh.annotations.Warmup;

import java.lang.reflect.Method;
import java.util.*;

import static com.vemana.common.performance.jmh.testing.LogicalOp.GREATER_OR_EQUAL;
import static com.vemana.common.performance.jmh.testing.LogicalOp.LESS_OR_EQUAL;

class BenchmarkMethod extends FrameworkMethod {

  private final Optional<String> groupName;
  private final List<Method> methods;
  private final List<JmhExpect> expectations;
  private final IterationSpec warmupIterSpec;
  private final IterationSpec measurementIterSpec;
  private final Optional<Integer> forks;
  private final Set<String> profilers;

  public BenchmarkMethod(Method method) {
    this(null, List.of(method));
  }

  public BenchmarkMethod(String groupName, List<Method> methods) {
    super(methods.getLast());
    this.groupName = Optional.ofNullable(groupName);
    this.methods = List.copyOf(methods);
    this.expectations = makeExpectations();
    this.warmupIterSpec = makeWarmupIterSpec();
    this.measurementIterSpec = makeMeasurementIterSpec();
    this.forks = makeForks();
    this.profilers = makeProfilers();
  }

  public Set<String> profilers() {
    return profilers;
  }

  List<JmhExpect> expectations() {
    return expectations;
  }

  Optional<Integer> forks() {
    return forks;
  }

  IterationSpec measurementIterationSpec() {
    return measurementIterSpec;
  }

  String uniqueRegex() {
    Method m = getMethod();
    String lastpiece = isGroup() ? groupName.get() : m.getName();
    String basename = "^%s.%s$".formatted(m.getDeclaringClass().getCanonicalName(), lastpiece);
    return basename.replace(".", "\\.");
  }

  IterationSpec warmupIterationSpec() {
    return warmupIterSpec;
  }

  private boolean isGroup() {
    return groupName.isPresent();
  }

  private List<JmhExpect> makeExpectations() {
    List<JmhExpect> res = new ArrayList<>();
    for (var m : methods) {
      for (var ann : m.getAnnotationsByType(JmhAssert.class)) {
        res.addAll(makeExpectations(m, ann));
      }
    }
    return List.copyOf(res);
  }

  private List<JmhExpect> makeExpectations(Method method, JmhAssert ann) {
    var res = new ArrayList<JmhExpect>();

    if (ann.avgt_max_seconds() >= 0) {
      boolean isPrimary = !isGroup() || ann.is_group_metric();
      final JmhExpect expect;
      Metric.Numeric rhs = Metric.Numeric.of(ann.avgt_max_seconds(), Unit.sec_per_op);
      if (isPrimary) {
        expect = JmhExpect.NumericExpect.ofPrimary(LESS_OR_EQUAL, rhs);
      } else {
        expect = new JmhExpect.NumericExpect(method.getName(), LESS_OR_EQUAL, rhs);
      }
      res.add(expect);
    }

    if (ann.avgt_max_nanos() >= 0) {
      boolean isPrimary = !isGroup() || ann.is_group_metric();
      final JmhExpect expect;
      Metric.Numeric rhs = Metric.Numeric.of(ann.avgt_max_nanos(), Unit.ns_per_op);
      if (isPrimary) {
        expect = JmhExpect.NumericExpect.ofPrimary(LESS_OR_EQUAL, rhs);
      } else {
        expect = new JmhExpect.NumericExpect(method.getName(), LESS_OR_EQUAL, rhs);
      }
      res.add(expect);
    }

    if (ann.thrpt_min_ops_per_sec() >= 0) {
      boolean isPrimary = !isGroup() || ann.is_group_metric();
      final JmhExpect expect;
      Metric.Numeric rhs = Metric.Numeric.of(ann.thrpt_min_ops_per_sec(), Unit.ops_per_sec);
      if (isPrimary) {
        expect = JmhExpect.NumericExpect.ofPrimary(GREATER_OR_EQUAL, rhs);
      } else {
        expect = new JmhExpect.NumericExpect(method.getName(), GREATER_OR_EQUAL, rhs);
      }
      res.add(expect);
    }

    if (ann.thrpt_min_ops_per_ns() >= 0) {
      boolean isPrimary = !isGroup() || ann.is_group_metric();
      final JmhExpect expect;
      Metric.Numeric rhs = Metric.Numeric.of(ann.thrpt_min_ops_per_ns(), Unit.ops_per_ns);
      if (isPrimary) {
        expect = JmhExpect.NumericExpect.ofPrimary(GREATER_OR_EQUAL, rhs);
      } else {
        expect = new JmhExpect.NumericExpect(method.getName(), GREATER_OR_EQUAL, rhs);
      }
      res.add(expect);
    }

    if (ann.alloc_max_B_per_op() >= 0) {
      final JmhExpect expect;
      // This is never primary.
      String key = "·gc.alloc.rate.norm"; // middle dot
      expect = new JmhExpect.NumericExpect(key, LESS_OR_EQUAL,
          Metric.Numeric.of(ann.alloc_max_B_per_op(), Unit.B_per_op));
      res.add(expect);
    }

    return res;
  }

  private Optional<Integer> makeForks() {
    int f = -1;
    for (var m : methods) {
      var ann = m.getAnnotation(Fork.class);
      if (ann == null) continue;
      int cur = ann.value();
      if (cur <= 0) continue;
      Preconditions.checkArgument(!(f > 0 && f != cur),
          "Different @fork values were specified [%s] vs [%s]", cur, f);
      if (f <= 0) f = cur;
    }
    return f > 0 ? Optional.of(f) : Optional.empty();
  }

  private IterationSpec makeMeasurementIterSpec() {
    var warmup = IterationSpec.none();
    for (var m : methods) {
      var ann = m.getAnnotation(Measurement.class);
      if (ann == null) continue;
      warmup = warmup.merge(IterationSpec.of(ann));
    }
    return warmup;
  }

  private Set<String> makeProfilers() {
    Set<String> res = new HashSet<>();
    for (var m : methods) {
      for (var ann : m.getAnnotationsByType(JmhAssert.class)) {
        res.addAll(makeProfilers(ann));
      }
    }
    return Set.copyOf(res);
  }

  private Set<String> makeProfilers(JmhAssert ann) {
    Set<String> res = new HashSet<>();
    if (ann.alloc_max_B_per_op() >= 0) {
      res.add("gc");
    }
    return res;
  }

  private IterationSpec makeWarmupIterSpec() {
    var warmup = IterationSpec.none();
    for (var m : methods) {
      var ann = m.getAnnotation(Warmup.class);
      if (ann == null) continue;
      warmup = warmup.merge(IterationSpec.of(ann));
    }
    return warmup;
  }

}
