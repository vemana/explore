package com.vemana.common.testing;

import com.vemana.common.error.QuietCaller;
import com.vemana.common.performance.jmh.testing.JmhAssert;
import com.vemana.common.performance.jmh.testing.JmhJunitSupport;
import com.vemana.common.testing.internal.*;
import com.vemana.common.testing.internal.TestMethod.JmhMethod;
import com.vemana.common.testing.internal.TestMethod.MethodWithParameters;
import com.vemana.common.testing.internal.TestMethod.RegularMethod;
import org.junit.runner.Description;
import org.junit.runner.manipulation.Filter;
import org.junit.runner.manipulation.NoTestsRemainException;
import org.junit.runners.BlockJUnit4ClassRunner;
import org.junit.runners.model.FrameworkMethod;
import org.junit.runners.model.InitializationError;
import org.junit.runners.model.Statement;

import java.lang.reflect.Method;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;

import static com.vemana.common.performance.jmh.testing.JmhJunitSupport.jmhMethodInvoker;

/// A JUnit4 test runner that offers test parallelization and JMH benchmarks with assertions.
///
/// How to use:
/// - Just set this class as the runner and you get default JUnit4 runner behavior
/// - Add [TestConfig#parallelize()] to the test class to run tests in parallel
/// - Any _JMH Benchmark_ methods will be run using JMH. These methods are identified using standad
/// JMH convention: specifying JMH `Benchmark` annotation. The methods can even specify [JmhAssert]
/// assertions which will be asserted against observed metrics evaluated by JMH.
///
/// JMH tests will run in parallel too - asking for parallelism is no different between having JMH
/// benchmark methods in the test class and otherwise.
///
/// Use [ClassParam#chooseFrom(SharedTestRule\[\])] to express class-level parameters. See its
/// documentation for usage. NOTE: it is invalid to have both JMH benchmark methods and class-level
/// parameters. Even if we tried to do something about it, JMH creates its own test instances and so
/// we cannot influence its behavior.
public class VTestRunner extends BlockJUnit4ClassRunner {

  private final AtomicReference<List<FrameworkMethod>> computedTestMethods;
  private final AtomicReference<SharedRuleContext> srcHolder;
  private final AtomicReference<MethodParamContext> mpcHolder;
  private final AtomicReference<List<FrameworkMethod>> activeTestMethods;

  public VTestRunner(Class<?> testClass) throws InitializationError {
    // The ones that go before superclass are init in computeTestMethods which setup calls
    this.computedTestMethods = new AtomicReference<>();
    this.srcHolder = new AtomicReference<>();
    this.activeTestMethods = new AtomicReference<>();
    this.mpcHolder = new AtomicReference<>();
    super(testClass);

    // parallelization
    TestConfig testConfig = testClass.getAnnotation(TestConfig.class);
    ParallelTestsConfig parallelConfig = testConfig != null ? testConfig.parallelize() : null;
    if (parallelConfig != null) {
      setScheduler(new Parallelizer(parallelConfig));
      System.setProperty("jmh.ignoreLock", "true");
    }
  }

  // Called after constructor but before scheduling children
  @Override
  public void filter(Filter filter) throws NoTestsRemainException {
    super.filter(filter);
    var survivingMethods = new ArrayList<FrameworkMethod>();
    // getChildren() returns the raw list (effectively what computeTestMethods() returned)
    for (FrameworkMethod method : getChildren()) {
      if (filter.shouldRun(describeChild(method))) {
        survivingMethods.add(method);
      }
    }
    activeTestMethods.set(survivingMethods);
    srcHolder.get().finishEvalStage(survivingMethods.size() / srcHolder.get().numCombos());
    var indices = survivingMethods.stream()
        .map(m -> (IndexedMethod) m)
        .map(IndexedMethod::index)
        .sorted()
        .toList();
    var imap = new HashMap<Integer, Integer>();
    for (int i = 0; i < indices.size(); i++)
      imap.put(indices.get(i), i);
    for (var smethod : survivingMethods) {
      var method = (IndexedMethod) smethod;
      method.updateIndex(imap.get(method.index()));
    }
  }

  // NOTE: Called from super.constructor.
  @Override
  protected List<FrameworkMethod> computeTestMethods() {
    if (computedTestMethods.get() != null) {
      return computedTestMethods.get();
    }
    var methods = evalSetup();
    int selectCombos = srcHolder.get().numCombos();
    int total = selectCombos * methods.size();
    ArrayList<FrameworkMethod> ret = new ArrayList<>(total);
    int midx = 0;
    for (int i = 0; i < selectCombos; i++) {
      for (var method : methods) {
        ret.add(new IndexedMethod(midx++, i, method));
      }
    }
    computedTestMethods.set(ret);
    activeTestMethods.set(ret);
    return ret;
  }

  // Flow: execution thread: methodBlock -> createTest; methodBlock.execute();
  // Called after scheduler submit - could be in parallel threads
  @Override
  protected Object createTest(FrameworkMethod inbound) throws Exception {
    FrameworkMethod method = ((IndexedMethod) inbound).method;
    return super.createTest(method);
  }

  // Called after scheduler submit - could be in parallel threads
  @Override
  protected Description describeChild(FrameworkMethod frameworkMethod) {
    IndexedMethod method = ((IndexedMethod) frameworkMethod);
    return Description.createTestDescription(getTestClass().getJavaClass(),
        testName(method)
        + srcHolder.get().describe(method.comboIndex())
        + describeMethodCombo(method.method),
        method.getAnnotations());
  }

  // Called after scheduler submit - could be in parallel threads
  @Override
  protected Statement methodBlock(FrameworkMethod inbound) {
    if (!srcHolder.get().hasParameters() && !mpcHolder.get().hasParameters()) {
      return super.methodBlock(inbound);
    }

    var testMethod = ((IndexedMethod) inbound).method;
    int tidx = ((IndexedMethod) inbound).index();
    int midx = -1, mcidx = -1;
    if (testMethod instanceof TestMethod.MethodWithParameters mwp) {
      midx = mwp.midx;
      mcidx = mwp.mcidx;
    }

    // creates the test instance and returns a statement that invokes the test on it.
    // Choices have been resolved at this stage.
    Statement fromSuper = EvalContext.newRunner()
        .withTestIndex(tidx)
        .withIndexContex(new ClassLevelIndexContext(activeTestMethods.get().size()))
        .withSharedRuleContext(srcHolder.get())
        .withMethodParamContext(mpcHolder.get())
        .withMethodIndex(midx)
        .withMethodLevelIndexContext(new MethodLevelIndexContext())
        .call(() -> super.methodBlock(inbound));

    Statement statement = fromSuper;
    if (srcHolder.get().hasParameters()) {
      statement = SharedRuleChain.sharedRuleChain(tidx).apply(statement, describeChild(inbound));
    }
    statement = wrapWithIndicesForTesting(tidx, mcidx, statement); // Required only for testing.
    statement = withInterruptIsolation(statement);
    return statement;
  }

  // Called after scheduler submit - could be in parallel threads
  @Override
  protected Statement methodInvoker(FrameworkMethod inbound, Object test) {
    TestMethod method = ((IndexedMethod) inbound).method;
    return switch (method) {
      case JmhMethod jm -> jmhMethodInvoker(jm.frameworkMethod, test, _ -> describeChild(inbound));
      case RegularMethod rm -> super.methodInvoker(rm.frameworkMethod, test);
      case MethodWithParameters mp -> mp.methodInvoker(test, obj -> ((MethodParam<?>) obj).get());
    };
  }

  private String describeMethodCombo(TestMethod method) {
    if (method instanceof TestMethod.MethodWithParameters mp) {
      int midx = mp.midx;
      return mpcHolder.get().describe(midx);
    }
    return "";
  }

  private List<TestMethod> evalSetup() {
    SharedRuleContext src = new SharedRuleContext(super.getTestClass().getJavaClass());
    MethodParamContext mpc = new MethodParamContext();

    EvalContext.newRunner()
        .withTestIndex(-1)
        .withMethodParamContext(mpc)
        .withSharedRuleContext(src)
        .withMethodLevelIndexContext(new MethodLevelIndexContext())
        .run(this::newTestInstanceForSetup);
    srcHolder.set(src);
    mpcHolder.set(mpc);

    ArrayList<TestMethod> methods = new ArrayList<>();
    // Regular methods
    methods.addAll(super.computeTestMethods().stream().map(RegularMethod::new).toList());

    // JMH methods
    List<FrameworkMethod> jmhMethods = JmhJunitSupport.jmhTestMethods(getTestClass());
    methods.addAll(jmhMethods.stream().map(JmhMethod::new).toList());

    // MethodParameter methods
    List<TestMethod> mpMethods = methodParameterMethods(mpc);
    methods.addAll(mpMethods);

    // Complete the MPC
    for (var mpMethod : mpMethods) {
      var mpm = (TestMethod.MethodWithParameters) mpMethod;
      mpc.setChoices(mpm.midx, mpm.paramChoices);
    }
    mpc.finishEvalStage();

    // Complete the SRC
    src.finishEvalStage(methods.size());
    return methods;
  }

  private void explodeMethods(MethodParamContext mpc,
      Method method,
      int level,
      AtomicInteger midxCounter,
      List<String> paramNames,
      LinkedHashMap<String, Integer> choices,
      List<TestMethod> exploded) {

    if (level == paramNames.size()) {
      int midx = midxCounter.getAndIncrement();
      int mcidx = exploded.size();
      exploded.add(new TestMethod.MethodWithParameters(
          method, midx, mcidx, super.getTestClass().getJavaClass(), new LinkedHashMap<>(choices)));
      return;
    }

    var name = paramNames.get(level);
    for (int i = 0; i < mpc.numChoices(name, method.getName()); i++) {
      choices.put(name, i);
      explodeMethods(mpc, method, level + 1, midxCounter, paramNames, choices, exploded);
    }
  }

  private List<TestMethod> methodParameterMethods(MethodParamContext mpc) {
    Class<?> testClass = super.getTestClass().getJavaClass();
    List<Method> methods = Arrays.stream(testClass.getMethods())
        .filter(m -> m.getAnnotation(TestAnnotations.TestWithParameters.class) != null)
        .toList();

    List<String> methodNames = methods.stream().map(Method::getName).toList();
    Map<String, List<String>> methodParamsByName =
        MethodArgParser.parsePublicMethodArguments(testClass, methodNames);

    AtomicInteger midxCounter = new AtomicInteger(0);
    List<TestMethod> ret = new ArrayList<>();
    for (var method : methods) {
      List<String> paramNames = methodParamsByName.get(method.getName());
      LinkedHashMap<String, Integer> choices = new LinkedHashMap<>();
      for (var p : paramNames) {
        choices.put(p, -1); // ensure the ordering
      }
      List<TestMethod> exploded = new ArrayList<>();
      explodeMethods(mpc, method, 0, midxCounter, paramNames, choices, exploded);
      ret.addAll(exploded);
    }

    return ret;
  }

  // Used only on first pass evaluation
  private Object newTestInstanceForSetup() {
    Class<?> javaClass = getTestClass().getJavaClass();
    return QuietCaller.call(() -> javaClass.getDeclaredConstructor().newInstance())
        .orThrow(RuntimeException.class, "Unable to make new instance for %s", javaClass.getName());
  }

  private Statement wrapWithIndicesForTesting(int tidx, int mcidx, Statement statement) {
    return new Statement() {
      @Override
      public void evaluate() {
        EvalContext.newRunner()
            .withTestIndex(tidx)
            .withMethodComboIndex(mcidx)
            .run(QuietCaller.of(statement::evaluate));
      }
    };
  }

}
