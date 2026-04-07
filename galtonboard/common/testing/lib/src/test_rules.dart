import 'package:test/test.dart' as test;

typedef Callback = void Function();
typedef TearDown = void Function(Callback);
typedef SetUp = void Function(Callback);

/// An interface for some action that needs to happen before & after a test. This is a JUnit Rule
/// like interface to allow chains of rules in a particular order. See [TestRuleChain] for example.
///
/// ```dart
/// EventBus? eventBus;
/// ServerRule serverRule = ServerRule(..);
/// TempFolderRule tmpFolderRule = TempFolderRule();
/// TestRule injectRule = TestRule.from(setup: (){
///   injector = ...;
///   eventBus = injector.eventBus;
/// }, tearDown: (){
///   eventBus = null;
///   injector = null;
/// });
///
/// group(.. () {
///   TestRuleChain([serverRule]).apply(setUpAll, tearDownAll); // once per group
///   TestRuleChain([tmpFolderRule, injectRule]).apply(setUp, tearDown); // once per test
///
///   // You can also do
///   // TestRuleChain([serverRule]).applyOnce(); // once per group
///   // TestRuleChain([tmpFolderRule, injectRule]).applyToEachTest(); // once per test
///   test(.. () {
///
///   })
/// })
/// ```
abstract interface class TestRule {
  factory TestRule.from({Callback? setup, Callback? tearDown}) {
    return _TestRuleImpl(setupCallback: setup, teardownCallback: tearDown);
  }

  /// Applies the action. The action to be applied before the test should be passed to [setUp]
  /// parameter and the action to apply after the test should be passed to [tearDown].
  void apply(SetUp setUp, TearDown tearDown);
}

extension TestRuleApplier on TestRule {
  /// Applies to each test, i.e. calls setUp and tearDown.
  void applyToEachTest() {
    apply(test.setUp, test.tearDown);
  }

  /// Applies once before the first test, i.e. calls setUpAll and tearDownAll.
  void applyOnce() {
    apply(test.setUpAll, test.tearDownAll);
  }
}

class TestRuleChain implements TestRule {
  TestRuleChain({List<TestRule>? rules}) {
    _rules = (rules == null) ? [] : [for (var rule in rules) rule];
  }

  late final List<TestRule> _rules;

  void add(TestRule testRule) {
    _rules.add(testRule);
  }

  void addAll(List<TestRule> testRules) {
    _rules.addAll(testRules);
  }

  @override
  void apply(SetUp setUp, TearDown tearDown) {
    for (TestRule rule in _rules) {
      rule.apply(setUp, tearDown);
    }
  }
}

class _TestRuleImpl implements TestRule {
  _TestRuleImpl({this.setupCallback, this.teardownCallback});

  final Callback? setupCallback;
  final Callback? teardownCallback;

  @override
  void apply(SetUp setUp, TearDown tearDown) {
    if (setupCallback != null) setUp(setupCallback!);
    if (teardownCallback != null) tearDown(teardownCallback!);
  }
}
