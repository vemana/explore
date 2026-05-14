package com.vemana.common.testing.internal;

import com.google.common.base.Preconditions;
import com.google.common.cache.CacheBuilder;
import com.google.common.cache.CacheLoader;
import com.google.common.cache.LoadingCache;
import com.google.common.collect.ImmutableList;
import com.google.common.collect.ImmutableSet;

import java.io.InputStream;
import java.lang.classfile.*;
import java.lang.classfile.instruction.FieldInstruction;
import java.lang.classfile.instruction.InvokeInstruction;
import java.lang.classfile.instruction.TypeCheckInstruction;
import java.util.*;

public final class FieldInitAnalyzer {

  private static final String CLINIT = "<clinit>";
  private static final String INIT = "<init>";
  private static final LoadingCache<FieldInitsRequest, FieldNames> FIELD_NAMES_CACHE = CacheBuilder
      .newBuilder()
      .build(new CacheLoader<>() {
        @Override
        public FieldNames load(FieldInitsRequest key) throws Exception {
          return computeInitializedFields(key);
        }
      });

  /// Search for field initializiers like
  /// `<field>=</field><request.targetMethodOwner>.<request.targetMethodName>` in the
  /// `request.targetClassObj` class. Returns info about such fields.
  /// The fields will be returned in initialization order.
  public static FieldNames getInitializedFields(FieldInitsRequest request) {
    return FIELD_NAMES_CACHE.getUnchecked(request);
  }

  static FieldNames computeInitializedFields(FieldInitsRequest request) throws Exception {
    List<Class<?>> hierarchy = buildTopDownHierarchy(request);
    List<String> combinedFields = new ArrayList<>();
    Set<String> staticFields = new HashSet<>();
    for (Class<?> clazz : hierarchy) {
      byte[] classBytes = readClassfileBytes(clazz);
      Preconditions.checkNotNull(classBytes, "Null classfile Bytes for %s", clazz.getName());
      FieldNames classFieldNames = processClassfile(classBytes, request, clazz.getName());
      combinedFields.addAll(classFieldNames.fieldNames());
      staticFields.addAll(classFieldNames.staticFields());
    }
    return new FieldNames(ImmutableList.copyOf(combinedFields), ImmutableSet.copyOf(staticFields));
  }

  private static List<Class<?>> buildTopDownHierarchy(FieldInitsRequest request) {
    List<Class<?>> hierarchy = new ArrayList<>();
    Class<?> current = request.targetClassObj(); // Accessed from the record
    while (current != null && current != Object.class) {
      hierarchy.add(current);
      current = current.getSuperclass();
    }
    Collections.reverse(hierarchy);
    return hierarchy;
  }

  // Helper to detect auto-unboxing
  private static boolean isUnboxingMethod(InvokeInstruction invoke) {
    if (invoke.opcode() != Opcode.INVOKEVIRTUAL) return false;
    String owner = invoke.owner().asInternalName();
    String name = invoke.name().stringValue();
    return (owner.equals("java/lang/Integer") && name.equals("intValue")) ||
           (owner.equals("java/lang/Boolean") && name.equals("booleanValue")) ||
           (owner.equals("java/lang/Long") && name.equals("longValue")) ||
           (owner.equals("java/lang/Double") && name.equals("doubleValue")) ||
           (owner.equals("java/lang/Float") && name.equals("floatValue")) ||
           (owner.equals("java/lang/Short") && name.equals("shortValue")) ||
           (owner.equals("java/lang/Byte") && name.equals("byteValue")) ||
           (owner.equals("java/lang/Character") && name.equals("charValue"));
  }

  private static void printMethodStructure(MethodModel method) {
    System.out.printf("Method: %s%s%n",
        method.methodName().stringValue(),
        method.methodType().stringValue()
    );

    // Check if the method has a body (abstract/native methods do not)
    method.code().ifPresentOrElse(codeModel -> {
      System.out.println("  Code Elements:");

      // Iterate through every single bytecode instruction and metadata element
      for (CodeElement element : codeModel) {
        // Formatting for readability: indenting real instructions vs metadata
        if (element instanceof PseudoInstruction) {
          System.out.println("    [Meta] " + element);
        } else {
          System.out.println("      " + element);
        }
      }
    }, () -> {
      System.out.println("  (No code available - method is abstract or native)");
    });
    System.out.println("-".repeat(50));
  }

  private static FieldNames processClassfile(byte[] classBytes, FieldInitsRequest request,
      String className) {
    List<String> fields = new ArrayList<>();
    Set<String> staticFields = new HashSet<>();
    ClassModel classModel = ClassFile.of().parse(classBytes);

    for (MethodModel method : classModel.methods()) {
      String methodName = method.methodName().stringValue();
      if (methodName.equals(INIT) || methodName.equals(CLINIT)) {
        boolean isStaticContext = methodName.equals(CLINIT);
        method.code().ifPresent(codeModel -> {
          boolean justCalledTargetMethod = false;

          for (CodeElement element : codeModel) {
            if (element instanceof PseudoInstruction) continue;

            if (element instanceof InvokeInstruction invoke) {
              if (invoke.opcode() == Opcode.INVOKESTATIC &&
                  invoke.owner().asInternalName().equals(request.internalOwnerName()) &&
                  invoke.name().stringValue().equals(request.targetMethodName())) {

                justCalledTargetMethod = true;
                continue;
              }
              if (justCalledTargetMethod && isUnboxingMethod(invoke)) {
                continue;
              }
            } else if (element instanceof TypeCheckInstruction typeInst &&
                       typeInst.opcode() == Opcode.CHECKCAST) {
              if (justCalledTargetMethod) continue;
            } else if (element instanceof FieldInstruction fieldInst) {
              if (justCalledTargetMethod &&
                  (fieldInst.opcode() == Opcode.PUTFIELD ||
                   fieldInst.opcode() == Opcode.PUTSTATIC)) {

                fields.add(fieldInst.name().stringValue());
                if (isStaticContext) {
                  staticFields.add("%s.%s".formatted(className, fieldInst.name().stringValue()));
                }
                justCalledTargetMethod = false;
                continue;
              }
            }
            justCalledTargetMethod = false;
          }
        });
      }
    }

    return new FieldNames(fields, staticFields);
  }

  private static byte[] readClassfileBytes(Class<?> clazz) throws Exception {
    String resourceName = clazz.getName().replace('.', '/') + ".class";
    ClassLoader classLoader = clazz.getClassLoader() != null ?
        clazz.getClassLoader() :
        ClassLoader.getSystemClassLoader();

    try (InputStream is = classLoader.getResourceAsStream(resourceName)) {
      if (is == null) return null;
      return is.readAllBytes();
    }
  }

  private FieldInitAnalyzer() {}
}