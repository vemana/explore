#include "random_array.cu"
#include <cuda_runtime.h>
#include <iostream>

void test_random_vector_generation() {
  int N = 100'000'000; // Size of the vector
  int seed = 42;

  // Test Int generation
  {
    int* d_vec = vecu::random::generateRandomsOnDevice(N, 10, seed);
    int* hd_vec = (int*)malloc(N * sizeof(int));
    CUDA_CHECK(cudaMemcpy(hd_vec, d_vec, N * sizeof(int), cudaMemcpyDeviceToHost));

    // Print some elements to verify (optional)
    std::cout << "First 10 elements of the random int vector:" << std::endl;
    for (int i = 0; i < 10; i++) {
      std::cout << hd_vec[i] << " ";
    }
    std::cout << std::endl;

    // Free memory
    free(hd_vec);
    CUDA_CHECK(cudaFree(d_vec));
  }


  // Test Float generation
  {
    float* f_vec = vecu::random::generateRandomsOnDevice(N, 1000.0f, seed);
    float* hf_vec = (float*)malloc(N * sizeof(float)); 
    CUDA_CHECK(cudaMemcpy(hf_vec, f_vec, N * sizeof(float), cudaMemcpyDeviceToHost));

    std::cout << "First 10 elements of the random float vector:" << std::endl;
    for (int i = 0; i < 10; i++) {
      std::cout << hf_vec[i] << " ";
    }
    std::cout << std::endl;

    // Free memory
    free(hf_vec);
    CUDA_CHECK(cudaFree(f_vec));
  }
}

int main() {
  test_random_vector_generation();
  return 0;
}
