package com.vemana.common.testing.internal;

import com.google.common.annotations.VisibleForTesting;

import java.util.List;
import java.util.function.Supplier;

public class EvalContext {

  private static final ScopedValue<EvalContext> evalContext = ScopedValue.newInstance();

  public static boolean inAssignmentPhase() {
    return evalContext.get().classLevelIndexContext != null;
  }

  public static ClassLevelIndexContext indexContext() {
    return evalContext.get().classLevelIndexContext;
  }

  @VisibleForTesting
  public static int methodComboIndex() {
    return evalContext.get().methodComboIdx;
  }

  public static int methodIndex() {
    return evalContext.get().methodIdx;
  }

  public static MethodParamContext methodParamContext() {
    return evalContext.get().methodParamContext;
  }

  public static MethodLevelIndexContext methodLevelIndexContext() {
    return evalContext.get().methodLevelIndexContext;
  }

  public static Runner newRunner() {
    return new Runner();
  }

  public static SharedRuleContext sharedRuleContext() {
    if (!evalContext.isBound()) {
      String stack = String.join("\n", (List<String>) StackWalker.getInstance()
          .walk(stream -> stream.map(StackWalker.StackFrame::toString).toList()));

      System.out.printf("STACK = \n%s\n", stack);
    }
    return evalContext.get().sharedRuleContext;
  }

  public static int testIndex() {
    return evalContext.get().testIdx;
  }

  private final SharedRuleContext sharedRuleContext;
  private final MethodParamContext methodParamContext;
  private final ClassLevelIndexContext classLevelIndexContext;
  private final MethodLevelIndexContext methodLevelIndexContext;
  private final int testIdx;
  private final int methodIdx;
  private final int methodComboIdx;

  private EvalContext(
      SharedRuleContext sharedRuleContext,
      MethodParamContext methodParamContext,
      ClassLevelIndexContext classLevelIndexContext,
      MethodLevelIndexContext methodLevelIndexContext,
      int testIdx,
      int methodIdx,
      int methodComboIndex) {
    this.sharedRuleContext = sharedRuleContext;
    this.methodParamContext = methodParamContext;
    this.classLevelIndexContext = classLevelIndexContext;
    this.methodLevelIndexContext = methodLevelIndexContext;
    this.testIdx = testIdx;
    this.methodIdx = methodIdx;
    this.methodComboIdx = methodComboIndex;
  }

  public static class Runner {
    private SharedRuleContext src = null;
    private ClassLevelIndexContext idc = null;
    private MethodParamContext mpc = null;
    private MethodLevelIndexContext mlic = null;
    private int testIndex = -1;
    private int methodIndex = -1;
    private int methodComboIndex = -1;

    public <T> T call(Supplier<T> supplier) {
      var ec = new EvalContext(src, mpc, idc, mlic, testIndex, methodIndex, methodComboIndex);
      return ScopedValue.where(evalContext, ec).call(supplier::get);
    }

    public void run(Runnable runnable) {
      var ec = new EvalContext(src, mpc, idc, mlic, testIndex, methodIndex, methodComboIndex);
      ScopedValue.where(evalContext, ec).run(runnable);
    }

    public Runner withIndexContex(ClassLevelIndexContext idc) {
      this.idc = idc;
      return this;
    }

    public Runner withMethodComboIndex(int mcidx) {
      this.methodComboIndex = mcidx;
      return this;
    }

    public Runner withMethodIndex(int midx) {
      this.methodIndex = midx;
      return this;
    }

    public Runner withMethodLevelIndexContext(MethodLevelIndexContext mlic) {
      this.mlic = mlic;
      return this;
    }

    public Runner withMethodParamContext(MethodParamContext mpc) {
      this.mpc = mpc;
      return this;
    }

    public Runner withSharedRuleContext(SharedRuleContext src) {
      this.src = src;
      return this;
    }

    public Runner withTestIndex(int tidx) {
      this.testIndex = tidx;
      return this;
    }
  }
}
