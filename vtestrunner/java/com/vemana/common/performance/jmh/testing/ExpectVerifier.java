package com.vemana.common.performance.jmh.testing;

import com.google.common.base.Preconditions;
import com.google.common.truth.Expect;
import com.vemana.common.performance.jmh.testing.JmhExpect.NumericExpect;
import com.vemana.common.performance.jmh.testing.Metric.Numeric;
import org.openjdk.jmh.results.Result;
import org.openjdk.jmh.results.RunResult;

final class ExpectVerifier {

  private final Expect expect;

  public ExpectVerifier(Expect expect) {
    this.expect = expect;
  }

  void verify(JmhExpect expect, RunResult result) {
    switch (expect) {
      case NumericExpect nex -> verifyNumericExpect(nex, result);
    }
  }

  private void verifyNumericExpect(NumericExpect nex, RunResult result) {
    if (nex.isPrimary()) {
      verifyNumericExpect(nex, result.getPrimaryResult());
    } else {
      verifyNumericExpect(nex,
          Preconditions.checkNotNull(result.getSecondaryResults().get(nex.key()),
              "Did not find key %s in results [%s]", nex.key(), result.getSecondaryResults()));
    }
  }

  private void verifyNumericExpect(NumericExpect nex, @SuppressWarnings("rawtypes") Result res) {
    double convertedValue =
        Numeric.of(res.getScore(), res.getScoreUnit()).convertTo(nex.rhs().unit()).value();

    expect.withMessage("""
            FAILED JMH ASSERTION
            --------------------
            Comparing obtained value[%s %s] against %s.
            Obtained value after unit conversion: [%s]
            """.formatted(res.getScore(), res.getScoreUnit(), nex, convertedValue))
        .that(nex.op().compare(convertedValue, nex.rhs().value()))
        .isTrue();
  }
}
