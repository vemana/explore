package com.vemana.common.testing;

import com.google.common.collect.ImmutableList;
import com.google.common.collect.Ordering;
import org.junit.Assert;

import java.util.*;

import static java.util.Comparator.comparing;

class Verifier {

  private final Map<String, IdentityHashSet<SimpleRule>> rulesSeen = new HashMap<>();
  private final Map<String, IdentityHashSet<Int>> intsSeen = new HashMap<>();
  private final Map<String, HashSet<Integer>> integersSeen = new HashMap<>();
  private final Map<String, HashSet<Integer>> methodIndexesSeen = new HashMap<>();

  private final Map<String, List<String>> expectations = new HashMap<>();
  private final Map<String, List<Int>> expectationsInts = new HashMap<>();
  private final Map<String, List<Integer>> expectationsIntegers = new HashMap<>();
  private final Map<String, List<Integer>> expectationsMethodIndexes = new HashMap<>();

  synchronized void expectIds(String testName, List<String> expected) {
    var list = new ArrayList<>(expected);
    list.sort(Ordering.natural());
    expectations.put(testName, ImmutableList.copyOf(list));
  }

  synchronized void expectIntegers(String testName, List<Integer> expectedIntegers) {
    var list = new ArrayList<>(expectedIntegers);
    list.sort(Comparator.naturalOrder());
    expectationsIntegers.put(testName, ImmutableList.copyOf(list));
  }

  synchronized void expectInts(String testName, List<Int> expectedInts) {
    var list = new ArrayList<>(expectedInts);
    list.sort(comparing(Int::x));
    expectationsInts.put(testName, ImmutableList.copyOf(list));
  }

  synchronized void expectMethodIndexes(String testName, List<Integer> expectedIntegers) {
    var list = new ArrayList<>(expectedIntegers);
    list.sort(Comparator.naturalOrder());
    expectationsMethodIndexes.put(testName, ImmutableList.copyOf(list));
  }

  synchronized void register(String testname, SimpleRule simpleRule) {
    var set = rulesSeen.computeIfAbsent(testname, _ -> new IdentityHashSet<>());
    set.add(simpleRule);
  }

  synchronized void registerIntegers(String testname, Integer c) {
    var set = integersSeen.computeIfAbsent(testname, _ -> new HashSet<>());
    set.add(c);
  }

  synchronized void registerInts(String testname, Int c) {
    var set = intsSeen.computeIfAbsent(testname, _ -> new IdentityHashSet<>());
    set.add(c);
  }

  synchronized void registerMethodIndexes(String testname, Integer c) {
    var set = methodIndexesSeen.computeIfAbsent(testname, _ -> new HashSet<>());
    set.add(c);
  }

  // Class level - no need for sync
  // By using identityhash{map/set} we are also verifying that selected objects are shared
  // across tests.
  void verify(boolean testLevels) {
    for (var testName : expectations.keySet()) {
      var sortedRules = rulesSeen.get(testName).stream().sorted(comparing(SimpleRule::id)).toList();
      var expectedIds = expectations.get(testName);
      var gotIds = sortedRules.stream().map(SimpleRule::id).toList();
      Assert.assertEquals("Expected ids differed for testname = %s".formatted(testName),
          expectedIds, gotIds);

      if(testLevels) {
        var expectedLevels = List.copyOf(Collections.nCopies(expectedIds.size(), 2));
        var gotLevels = sortedRules.stream().map(rule -> rule.level().get()).toList();
        Assert.assertEquals("Expected levels differeed for testname = %s".formatted(testName),
            expectedLevels, gotLevels);
      }

      var expectedInts = expectationsInts.get(testName);
      List<Int> gotInts = null;
      if (intsSeen.containsKey(testName)) {
        gotInts = intsSeen.get(testName).stream().sorted(comparing(Int::x)).toList();
      }
      Assert.assertEquals("Expected ints differed for testname = %s".formatted(testName),
          expectedInts, gotInts);

      var expectedIntegers = expectationsIntegers.get(testName);
      List<Integer> gotIntegers = null;
      if (integersSeen.containsKey(testName)) {
        gotIntegers = integersSeen.get(testName).stream().sorted().toList();
      }
      Assert.assertEquals("Expected integers differed for testname = %s".formatted(testName),
          expectedIntegers, gotIntegers);


      var expectedMethodIndexes = expectationsMethodIndexes.get(testName);
      List<Integer> gotMethodIndexes = null;
      if (methodIndexesSeen.containsKey(testName)) {
        gotMethodIndexes = methodIndexesSeen.get(testName).stream().sorted().toList();
      }
      Assert.assertEquals("Expected methodIndexes differed for testname = %s".formatted(testName),
          expectedMethodIndexes, gotMethodIndexes);
    }
  }
}
