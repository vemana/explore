package com.vemana.common.testing.internal;

import com.google.common.cache.CacheBuilder;
import com.google.common.cache.CacheLoader;
import com.google.common.cache.LoadingCache;

import java.io.IOException;
import java.io.InputStream;
import java.lang.classfile.Attributes;
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.classfile.MethodModel;
import java.lang.classfile.attribute.MethodParameterInfo;
import java.lang.classfile.attribute.MethodParametersAttribute;
import java.lang.constant.MethodTypeDesc;
import java.lang.reflect.AccessFlag;
import java.util.*;

public class MethodArgParser {

  private static final LoadingCache<MethodArgsRequest, Map<String, List<String>>> methodArgNames =
      CacheBuilder
          .newBuilder()
          .build(new CacheLoader<>() {
            @Override
            public Map<String, List<String>> load(MethodArgsRequest key) throws Exception {
              return parsePublicMethodArguments(key);
            }
          });

  public static Map<String, List<String>> parsePublicMethodArguments(
      Class<?> targetClass,
      List<String> targetMethodNames) {
    return methodArgNames.getUnchecked(new MethodArgsRequest(targetClass, targetMethodNames));
  }

  private static List<String> extractArguments(MethodModel method, Class<?> currentClass,
      String methodName, MethodTypeDesc typeDesc) {
    // Handle zero-argument methods (which may not generate a MethodParameters attribute)
    if (typeDesc.parameterCount() == 0) {
      return Collections.emptyList();
    }

    // Verify -parameters presence
    Optional<MethodParametersAttribute> paramsAttr =
        method.findAttribute(Attributes.methodParameters());
    if (paramsAttr.isEmpty()) {
      throw new IllegalStateException(
          "Class not compiled with -parameters: " + currentClass.getName() +
          " (Missing MethodParameters attribute for '" + methodName + "')"
      );
    }

    List<String> argNames = new ArrayList<>();
    for (MethodParameterInfo paramInfo : paramsAttr.get().parameters()) {
      if (paramInfo.name().isEmpty()) {
        throw new IllegalStateException(
            "Synthetic/missing parameter name detected in method: '" + methodName + "'. " +
            "Ensure the code is compiled strictly with -parameters."
        );
      }
      argNames.add(paramInfo.name().get().stringValue());
    }

    return argNames;
  }

  private static boolean isProcessableMethod(MethodModel method, Set<String> targets) {
    if (!method.flags().has(AccessFlag.PUBLIC)) {
      return false;
    }
    String methodName = method.methodName().stringValue();
    if (methodName.equals("<init>") || methodName.equals("<clinit>")) {
      return false;
    }
    return targets.contains(methodName);
  }

  private static byte[] loadClassBytes(Class<?> clazz) throws IOException {
    String resourceName = clazz.getName().replace('.', '/') + ".class";
    try (InputStream is = clazz.getClassLoader().getResourceAsStream(resourceName)) {
      if (is == null) {
        throw new IOException("Unable to locate class file for: " + clazz.getName());
      }
      return is.readAllBytes();
    }
  }

  private static Map<String, List<String>> parsePublicMethodArguments(
      MethodArgsRequest request) throws Exception {
    Class<?> targetClass = request.targetClass();
    List<String> targetMethodNames = request.targetMethodNames();
    Map<String, List<String>> result = new HashMap<>();
    Map<String, String> resolvedSignatures =
        new HashMap<>(); // To distinguish overloads vs overrides
    Set<String> targets = new HashSet<>(targetMethodNames);

    Class<?> currentClass = targetClass;

    // Traverse hierarchy upwards until we hit Object
    while (currentClass != null && currentClass != Object.class) {
      processClass(currentClass, targets, result, resolvedSignatures);
      currentClass = currentClass.getSuperclass();
    }

    validateAllTargetsFound(targets, result);

    return result;
  }

  private static void processClass(Class<?> currentClass, Set<String> targets,
      Map<String, List<String>> result,
      Map<String, String> resolvedSignatures) throws IOException {
    byte[] classBytes = loadClassBytes(currentClass);
    ClassModel classModel = ClassFile.of().parse(classBytes);

    for (MethodModel method : classModel.methods()) {
      if (!isProcessableMethod(method, targets)) {
        continue;
      }
      processMethod(method, currentClass, result, resolvedSignatures);
    }
  }

  private static void processMethod(MethodModel method, Class<?> currentClass,
      Map<String, List<String>> result,
      Map<String, String> resolvedSignatures) {
    String methodName = method.methodName().stringValue();
    MethodTypeDesc typeDesc = method.methodTypeSymbol();
    String descriptor = typeDesc.descriptorString();

    if (result.containsKey(methodName)) {
      // Check for conflict: If signatures differ, it's an overload.
      // If they match, it's just an overridden method in a superclass, which we can safely ignore.
      if (!descriptor.equals(resolvedSignatures.get(methodName))) {
        throw new IllegalArgumentException(
            "Method overload conflict detected for: '" + methodName + "'"
        );
      }
      return;
    }

    List<String> argNames = extractArguments(method, currentClass, methodName, typeDesc);
    result.put(methodName, argNames);
    resolvedSignatures.put(methodName, descriptor);
  }

  private static void validateAllTargetsFound(Set<String> targets,
      Map<String, List<String>> result) {
    List<String> missing = targets.stream()
        .filter(name -> !result.containsKey(name))
        .toList();

    if (!missing.isEmpty()) {
      throw new IllegalArgumentException(
          "Missing requested public methods in class hierarchy: " + missing);
    }
  }

  record MethodArgsRequest(Class<?> targetClass, List<String> targetMethodNames) {}


}