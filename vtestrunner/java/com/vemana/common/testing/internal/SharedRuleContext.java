package com.vemana.common.testing.internal;

import com.google.common.base.Preconditions;
import com.vemana.common.testing.SharedTestRule;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Function;
import java.util.stream.IntStream;

public class SharedRuleContext {

  private final AtomicBoolean hasParameters = new AtomicBoolean(false);
  private final List<Object[]> clist = new ArrayList<>();
  private final List<List<AtomicInteger>> countersList = new ArrayList<>();
  private final Class<?> testClass;
  private int numCombos = 1;
  private List<String> names = List.of("");

  public SharedRuleContext(Class<?> testClass) {this.testClass = testClass;}

  public String describe(int index) {
    Preconditions.checkArgument(index < numCombos,
        "Index %s expected to be < combos = %s", index, numCombos);
    return names.get(index);
  }

  public boolean hasParameters() {
    return hasParameters.get();
  }

  public int numCombos() {
    return numCombos;
  }

  public void finishEvalStage(int methodCount) {
    setCounterValues(methodCount);
  }

  @SafeVarargs
  final <T> void addSelect(boolean isSharedRule, String fieldNameInTest, T... candidates) {
    hasParameters.set(true);
    numCombos *= candidates.length;
    Function<T, String> func = isSharedRule
        ? c -> "%s[%s]".formatted(fieldNameInTest, ((SharedTestRule) c).descriptionString())
        : c -> "%s[%s]".formatted(fieldNameInTest, c);
    addNames(func, candidates);
    clist.add(candidates);
    countersList.add(
        IntStream.range(0, 2 * candidates.length).mapToObj(_ -> new AtomicInteger(0)).toList());
  }

  Object[] candidatesAtLevel(int index) {
    return clist.get(index);
  }

  List<AtomicInteger> getCountersAtLevel(int index) {
    return countersList.get(index);
  }

  public Class<?> testClass() {
    return testClass;
  }

  @SafeVarargs
  private <T> void addNames(Function<T, String> func, T... candidates) {
    List<String> newNames = new ArrayList<>();
    for (var name : names) {
      for (var cand : candidates) {
        newNames.add("%s_%s".formatted(name, func.apply(cand)));
      }
    }
    this.names = newNames;
  }

  private void setCounterValues(int methodCount) {
    for (var list : countersList) {
      int n = list.size() / 2;
      var sublist = list.subList(n, 2 * n);
      for (var counter : sublist)
        counter.set(numCombos * methodCount / n);
    }
  }
}
