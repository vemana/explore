#include <iostream>
#include <cuda_runtime.h>
#include <curand.h>

// Error handling macro
#define CUDA_CHECK(call) \
  do { \
    cudaError_t error = call; \
    if (error != cudaSuccess) { \
      fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, cudaGetErrorString(error)); \
      exit(EXIT_FAILURE); \
    } \
  } while (0)

#define CURAND_CHECK(call) \
  do { \
    curandStatus_t error = call; \
    if (error != CURAND_STATUS_SUCCESS) { \
      fprintf(stderr, "cuRAND error at %s:%d: %d\n", __FILE__, __LINE__, error); \
      exit(EXIT_FAILURE); \
    } \
  } while (0)

