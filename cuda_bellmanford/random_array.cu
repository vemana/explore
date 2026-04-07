#include <cuda_runtime.h>
#include <curand.h>
#include <cassert>
#include "cuda_macros.cu"

namespace vecu{
namespace random {

template<typename T>
__global__ void __convert_float_to_T(T* out, float* vec, int N, T K) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < N) {
    out[i] = (T)(vec[i] * K);
    if(std::is_same<T, int>::value && out[i]==K)
      out[i] = K-1;
  }
}

typedef unsigned long long ull;

// Function to generate a random vector on to device at location [out]
template <typename T>
void generateRandomsOnDeviceInto(T* out, int N, T K, ull seed) {
  float* f_vec;

  // Setup
  if (std::is_same<T, float>::value) {
    f_vec = (float*)out;
  } else {
    CUDA_CHECK(cudaMalloc((void**)&f_vec, N * sizeof(float)));
  }

  curandGenerator_t gen;
  CURAND_CHECK(curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_DEFAULT));
  CURAND_CHECK(curandSetPseudoRandomGeneratorSeed(gen, seed));

  // Generate
  CURAND_CHECK(curandGenerateUniform(gen, f_vec, N)); // Generate floats initially

  int blockSize = 128; // Number of threads per block
  int gridSize = (N + blockSize - 1) / blockSize; // Number of blocks in the grid
  __convert_float_to_T<<<gridSize, blockSize>>>(out, f_vec, N, K); 

  // cleanup
  CURAND_CHECK(curandDestroyGenerator(gen));
  if (!std::is_same<T, float>::value) {
    CUDA_CHECK(cudaFree(f_vec));
  }
}

// Function to generate a random vector on the device
// Returns a on-device memory pointer
template <typename T>
T* generateRandomsOnDevice(int N, T K, ull seed) {
  T* out;
  CUDA_CHECK(cudaMalloc((void**)&out, N * sizeof(T)));
  vecu::random::generateRandomsOnDeviceInto(out, N, K, seed);
  return out;
}


} // namespace vecu::random
} // namespace vecu
