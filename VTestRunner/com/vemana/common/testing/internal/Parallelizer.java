package com.vemana.common.testing.internal;

import com.vemana.common.testing.ParallelTestsConfig;
import org.junit.runners.model.RunnerScheduler;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

public class Parallelizer implements RunnerScheduler {
  private final ExecutorService service;

  public Parallelizer(ParallelTestsConfig config) {
    service =
        config.useVirtualThreads()
            ? Executors.newVirtualThreadPerTaskExecutor()
            : (config.platformThreads() < 1
               ? Executors.newCachedThreadPool()
               : Executors.newFixedThreadPool(config.platformThreads()));
  }

  @Override
  public void finished() {
    try {
      service.shutdown();
      service.awaitTermination(Long.MAX_VALUE, TimeUnit.NANOSECONDS);
    } catch (InterruptedException e) {
      e.printStackTrace(System.err);
      throw new RuntimeException(e);
    }
  }

  @Override
  public void schedule(Runnable runnable) {
    service.submit(runnable);
  }
}
