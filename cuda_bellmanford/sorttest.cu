#include <thrust/device_vector.h>
#include <thrust/sort.h>
#include <thrust/tuple.h>
#include <thrust/iterator/zip_iterator.h>
#include <thrust/copy.h>
#include <iostream>

int main() {
  thrust::device_vector<int> A = {3, 2, 1};
  thrust::device_vector<int> B = {1, 2, 3};
  thrust::device_vector<int> C = {4, 5, 6};
  thrust::device_vector<int> D = {7, 8, 9};

  auto begin = thrust::make_zip_iterator(thrust::make_tuple(A.begin(), B.begin(), C.begin(), D.begin()));

  thrust::sort_by_key(A.begin(), A.end(), begin);

  thrust::copy(A.begin(), A.end(), std::ostream_iterator<int>(std::cout, " "));
  std::cout << std::endl;
  thrust::copy(B.begin(), B.end(), std::ostream_iterator<int>(std::cout, " "));
  std::cout << std::endl;
  thrust::copy(C.begin(), C.end(), std::ostream_iterator<int>(std::cout, " "));
  std::cout << std::endl;
  thrust::copy(D.begin(), D.end(), std::ostream_iterator<int>(std::cout, " "));
  std::cout << std::endl;

  return 0;
}
