package com.vemana.common.testing.internal;

import com.google.common.collect.ImmutableList;
import com.vemana.common.testing.SharedTestRule;
import org.junit.rules.RuleChain;
import org.junit.rules.TestRule;
import org.junit.runner.Description;
import org.junit.runners.model.Statement;

import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Consumer;

public class SharedRuleChain implements TestRule {

  private static final Map<Object, Builder> rulebuilders =
      Collections.synchronizedMap(new HashMap<>());

  public static Builder builder(FieldNames fieldNames) {
    return new Builder(fieldNames);
  }

  public static Builder getBuilder(int testIdx, FieldNames fieldNames) {
    return rulebuilders.computeIfAbsent(testIdx, _ -> builder(fieldNames));
  }

  public static TestRule sharedRuleChain(int tidx) {
    return rulebuilders.get(tidx).build();
  }

  static int select(int numCandidates) {
    var indexContext = EvalContext.indexContext();
    int idx = EvalContext.testIndex();
    int total = indexContext.total();
    int seen = indexContext.seen();
    int left = total / seen;
    int later = left / numCandidates;
    return (idx % left) / later;
  }
  private final ImmutableList<TestRule> rules;

  private SharedRuleChain(ImmutableList<TestRule> rules) {
    this.rules = rules;
  }

  @Override
  public Statement apply(Statement statement, Description description) {
    RuleChain chain = RuleChain.emptyRuleChain();
    for (var rule : rules) {
      chain = chain.around(rule);
    }
    return chain.apply(statement, description);
  }

  public static class Builder {
    private final List<TestRule> inners = new ArrayList<>();
    private final FieldNames fieldNames;
    private int curIdx = -1;

    Builder(FieldNames fieldNames) {
      this.fieldNames = fieldNames;
    }

    public SharedRuleChain build() {
      return new SharedRuleChain(ImmutableList.copyOf(inners));
    }

    @SuppressWarnings({"unchecked"})
    public final <T> Builder nextInnerNonShared(Consumer<T> consumer, T... candidates) {
      curIdx++;
      final int selectedIdx;
      if (EvalContext.inAssignmentPhase()) {
        candidates = (T[]) EvalContext.sharedRuleContext().candidatesAtLevel(curIdx);
        selectedIdx = select(candidates.length);
        EvalContext.indexContext().addSelect(candidates.length);
      } else {
        selectedIdx = 0;
        EvalContext.sharedRuleContext()
            .addSelect(false, fieldNames.fieldNames().get(curIdx), candidates);
      }
      consumer.accept(candidates[selectedIdx]);
      return this;
    }

    @SuppressWarnings("unchecked")
    public final <T extends SharedTestRule> Builder nextInnerShared(Consumer<T> consumer,
        T... candidates) {
      curIdx++;
      final int selectedIdx;
      if (EvalContext.inAssignmentPhase()) {
        candidates = (T[]) EvalContext.sharedRuleContext().candidatesAtLevel(curIdx);
        selectedIdx = select(candidates.length);
        EvalContext.indexContext().addSelect(candidates.length);
      } else {
        selectedIdx = 0;
        EvalContext.sharedRuleContext()
            .addSelect(true, fieldNames.fieldNames().get(curIdx), candidates);
      }
      consumer.accept(candidates[selectedIdx]);
      var counters = EvalContext.sharedRuleContext().getCountersAtLevel(curIdx);
      inners.add(adapt(selectedIdx, counters, candidates));
      return this;
    }

    private <T extends SharedTestRule> TestRule adapt(int selectedIdx, List<AtomicInteger> counters,
        T[] candidates) {
      var setup = counters.get(selectedIdx);
      var teardown = counters.get(selectedIdx + candidates.length);
      return new SharedRuleAdapter(candidates[selectedIdx], setup, teardown);
    }
  }
}
