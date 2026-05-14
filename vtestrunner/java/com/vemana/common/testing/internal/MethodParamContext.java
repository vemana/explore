package com.vemana.common.testing.internal;

import com.google.common.base.Preconditions;

import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;

public class MethodParamContext {

  private static final ScopedValue<MethodParamContext> contextScope = ScopedValue.newInstance();

  public static MethodParamContext get() {
    return contextScope.get();
  }

  private final List<String> paramNames = new ArrayList<>();
  private final List<Object[]> candidates = new ArrayList<>();
  private final Map<String, Integer> paramToLevel = new HashMap<>();
  private final AtomicBoolean hasParameters = new AtomicBoolean(false);
  // method idx -> param -> choice
  private final Map<Integer, LinkedHashMap<String, Object>> resolution = new HashMap<>();
  private final Map<Integer, String> descriptions = new HashMap<>();

  public <T> void addChoices(String param, T[] choices) {
    hasParameters.set(true);
    paramToLevel.put(param, paramNames.size());
    paramNames.add(param);
    candidates.add(choices);
  }

  public String describe(int midx) {
    return descriptions.get(midx);
  }

  public void finishEvalStage() {
    // Build out descriptions
    for (int midx : resolution.keySet()) {
      String description = "";
      var choices = resolution.get(midx);
      for (var param : choices.keySet()) {
        Object choice = choices.get(param);
        description = "%s_%s[%s]".formatted(description, param, String.valueOf(choice));
      }
      descriptions.put(midx, description);
    }
  }

  public Object getChoice(int midx, String param) {
    return resolution.get(midx).get(param);
  }

  public boolean hasParameters() {
    return hasParameters.get();
  }

  public boolean isEnabled(int midx, String param) {
    return resolution.get(midx).containsKey(param);
  }

  public int numChoices(String param, String methodNameForErrorContext) {
    Preconditions.checkArgument(paramToLevel.containsKey(param),
        "Param `%s` is not a valid MethodParam in method `%s`.", param, methodNameForErrorContext);
    int level = paramToLevel.get(param);
    return candidates.get(level).length;
  }

  public void setChoices(int midx, LinkedHashMap<String, Integer> paramChoices) {
    var choices = new LinkedHashMap<String, Object>();
    for (var param : paramChoices.keySet()) {
      int cidx = paramChoices.get(param);
      int level = paramToLevel.get(param);
      Object chosen = candidates.get(level)[cidx];
      choices.put(param, chosen);
    }
    resolution.put(midx, choices);
  }
}
