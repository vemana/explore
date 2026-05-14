package com.vemana.common.performance.jmh.testing;

import com.google.common.collect.ArrayListMultimap;
import com.google.common.collect.ListMultimap;
import com.google.common.truth.Expect;
import org.junit.runner.Description;
import org.junit.runners.model.FrameworkMethod;
import org.junit.runners.model.Statement;
import org.junit.runners.model.TestClass;
import org.openjdk.jmh.annotations.Benchmark;
import org.openjdk.jmh.annotations.Group;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.function.Function;
import java.util.stream.Stream;

/// Support class for the unified test runner that can run JMH in junit tests and make assertions.
/// See [JmhAssert] for supported assertions.
public class JmhJunitSupport {

  public static Statement jmhMethodInvoker(
      FrameworkMethod method,
      Object test,
      Function<FrameworkMethod, Description> descriptionFunction) {
    Expect expect = Expect.create();
    var base = new BenchmarkStatement((BenchmarkMethod) method, test, expect);
    return expect.apply(base, descriptionFunction.apply(method));
  }

  public static List<FrameworkMethod> jmhTestMethods(TestClass testClass) {
    var allMethods = testClass.getAnnotatedMethods(Benchmark.class);
    var nonGroupMethods = new ArrayList<FrameworkMethod>();
    ListMultimap<String, Method> groups = ArrayListMultimap.create();

    for (var fm : allMethods) {
      Method m = fm.getMethod();
      var groupname = Optional.ofNullable(m.getAnnotation(Group.class)).map(Group::value);
      if (groupname.isEmpty()) {
        nonGroupMethods.add(new BenchmarkMethod(m));
      } else {
        groups.put(groupname.get(), m);
      }
    }
    return Stream.concat(
            nonGroupMethods.stream(),
            groups.keySet().stream().map(k -> new BenchmarkMethod(k, groups.get(k))))
        .toList();
  }
}
