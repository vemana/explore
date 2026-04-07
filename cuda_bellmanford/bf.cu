#include "cuda_macros.cu"
#include "random_array.cu"
#include "tracer.h"
#include <cassert>
#include <cooperative_groups.h>
#include <cooperative_groups/scan.h>
#include <cstdlib>
#include <iostream>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>
#include <thrust/iterator/zip_iterator.h>
#include <thrust/logical.h>
#include <thrust/sort.h>
#include <thrust/tuple.h>

namespace cg = cooperative_groups;

using Tracer = vecu::trace::Tracer;
Tracer tracer;

using DVI = thrust::device_vector<int>;
using DVF = thrust::device_vector<float>;

void printEdges(const auto& dU, const auto& dV, const auto& dC){
  for(int i=0;i<100 && i<dU.size();i++) {
    std::cout<< "(" << dU[i] << " " << dV[i]<< " " << dC[i] << ")\n";
  }
  printf("\n");
}

// If line_graph = true, in addition to the random graph, you get a line path between vertices: 0 -> 1 -> 2 -> ... -> n-1
// This forces V*E total work or V iterations of O(E) each to focus solely on the algorithm's performance.
std::tuple<DVI,DVI,DVF> generateGraph(int edges, int vertices, int seed, float maxCost, bool sort = false, bool line_graph = true) {
  tracer.trace("About to generate graph", true);

  int nedges = edges + (line_graph ? vertices - 1 : 0);
  DVI dU(nedges), dV(nedges);
  DVF dC(nedges);

  vecu::random::generateRandomsOnDeviceInto(dU.data().get(), edges, vertices, seed);
  // Use seed + 1 to avoid dV = dU and still retain repeatability
  vecu::random::generateRandomsOnDeviceInto(dV.data().get(), edges, vertices, seed + 1);
  vecu::random::generateRandomsOnDeviceInto(dC.data().get(), edges, maxCost, seed + 2);

  if(line_graph) {
    for(int i=0;i+1<vertices;i++) {
      dU[edges + i] = i;
      dV[edges + i] = i+1;
      dC[edges + i] = 0;
    }
  }
  //printEdges(dU, dV, dC);

  if(sort) {
    tracer.trace("About to sort generated graph", true);
    auto beginZip = thrust::make_zip_iterator(thrust::make_tuple(dU.begin(), dV.begin(), dC.begin()));
    thrust::sort_by_key(dV.begin(), dV.end(), beginZip);
    tracer.trace("Sorted graph", true);
  }
  //printEdges(dU, dV, dC);

  return std::make_tuple(dU, dV, dC);
}

void printBest(const std::string& message, const auto& bestDev) {
  printf("Printing best... %s\n", message.c_str());
  thrust::host_vector<float> best = bestDev;
  for(int i=0;i<10 && i < best.size();i++) {
    printf("(%d %.2f) ", i, best[i]);
  }
  printf("\n");

  for(int i=0;i<10 && i < best.size();i++) {
    printf("(%lu %.2f) ", best.size()-1 - i, best[best.size()-1-i]);
  }
  printf("\n");

  printf("\n\n");
}


__global__
void batchIterations_scatteredWrites(int iters, float* best, int edges, int vertices, const int* U, const int* V, const float* C) {
  int lane = blockIdx.x * blockDim.x + threadIdx.x;

  if(lane < edges) {
    for(int i=0;i<iters;i++) {
      int u = U[lane];
      int v = V[lane];
      float c = C[lane];
      float cand = best[u] + c;
      // This doesn't produce the right answer at all. Probably because we are reading and writing best[]
      // and some cache invalidation may not be happening correctly.
      atomicMin((int*) best + v, __float_as_int(cand));
    }
  }
}

__device__ int32_t gridSyncReached = 0;
__device__ int32_t gridSyncCounter = 0;

__global__
void batchIterations_newBest(
    int iters, int groupSize, float* best, float* newBest,
    int edges, int vertices, const int* U, const int* V, const float* C) {

  // Invariant: on entry best == newBest. 
  // on exit, newBest reflects the last iteration & best reflects the prior iteration
  // if there's only one iteration, best is untouched
  cg::grid_group g = cg::this_grid();
  int lane = g.thread_rank();
  int stride = g.num_threads();

  for(int i=0;i<iters;i++) {
    for(int j=lane; j < edges; j+=stride) {
      int u = U[j];
      int v = V[j];

      // Relax edges
      float c = C[j];
      float cand = best[u] + c;
      // This guard speeds up by 50%
      if(cand < newBest[v]) {
        atomicMin((int*) newBest + v, __float_as_int(cand));
      }
    }
    // Wait for newBest() to be fully computed.
    g.sync();

    // If we are going to do more work, initialize best = newBest
    if(i < iters-1) {
      for(int j=lane; j < vertices; j+= stride) {
        best[j] = newBest[j];
      }
    }
    g.sync();
  }
}

__global__
void oneIteration_newBest(float* best, float* newBest, int edges, int vertices, const int* U, const
    int* V, const float* C) {
  int lane = blockIdx.x * blockDim.x + threadIdx.x;

  if (lane < edges) {
    int u = U[lane];
    int v = V[lane];
    float c = C[lane];
    float cand = best[u] + c;
    /*
    atomicMin((int*) newBest + v, __float_as_int(cand));
    */
    if(cand < newBest[v]) {
      atomicMin((int*) newBest + v, __float_as_int(cand));
    }
  }
}

struct BfConfig {

  using string = std::string;

  int vertices;
  int edges;
  int itersPerBatch;
  int blockSize;
  int blockCount;
  string algo;

  static BfConfig fromArgs(char* argv[]) {
    int vertices = std::atoi(argv[0]);
    int edges = std::atoi(argv[1]);
    int itersPerBatch = std::atoi(argv[2]);
    int blockSize = std::atoi(argv[3]);
    int blockCount = std::atoi(argv[4]);
    string algo = std::string(argv[5]);
    assert(algo == "scattered" || algo == "newBest_one" || algo == "newBest_batch");
    return {vertices, edges, itersPerBatch, blockSize, blockCount, algo};
  }

  static BfConfig defaultConfig() {
    int vertices = 100;
    int edges = 1000;
    int itersPerBatch = 1000;
    int blockSize = 128;
    int blockCount = 84 * 16;
    string algo = "scattered";
    return {vertices, edges, itersPerBatch, blockSize, blockCount, algo};
  }
};

void doMain(BfConfig config) {
  using string = std::string;

  tracer.trace("Initated main", true);

  int vertices = config.vertices;
  int edges = config.edges;
  int itersPerBatch = config.itersPerBatch;
  string algo = config.algo;
  int blockSize = config.blockSize;
  int blockCount = config.blockCount;

  float maxCost = 12345.0;
  int seed = 42;
  int printOnceEvery = 5000;

  tracer.trace(std::format(R"(Parameters
-----------
vertices         = {:12}
edges            = {:12}
maxCost          = {:12.1}
seed             = {:12}
blockSize        = {:12}
blockCount       = {:12}
algo             = {:>12}
itersPerBatch    = {:12}
)", vertices, edges, maxCost, seed, blockSize, blockCount, algo, itersPerBatch), true);

  auto [dU, dV, dC] = generateGraph(edges, vertices, seed, maxCost, true);

  DVF best(vertices, 1e19);
  best[0] = 0.0;
  DVF newBest = best;

  int doneIters = 0;

  tracer.trace(std::format("Starting Iterations"), true);

  while(true) {
    bool anyChanged = false;

    if(algo == "scattered") 
    {
      float sum = thrust::reduce(best.begin(), best.end(), 0);
      int gridSize = (dU.size() + blockSize - 1) / blockSize;
      batchIterations_scatteredWrites<<<gridSize, blockSize>>>(
          itersPerBatch, best.data().get(), 
          dU.size(), vertices, dU.data().get(), dV.data().get(),
          dC.data().get()); 
      float newSum = thrust::reduce(best.begin(), best.end(), 0);
      anyChanged = sum != newSum;
      doneIters += itersPerBatch;
    } 
    else if(algo == "newBest_one") 
    {
      int gridSize = (dU.size() + blockSize - 1) / blockSize;
      oneIteration_newBest<<<gridSize, blockSize>>>(
          best.data().get(), newBest.data().get(), 
          dU.size(), vertices, dU.data().get(), dV.data().get(),
          dC.data().get()); 
      anyChanged = newBest != best;
      best = newBest;
      doneIters += 1;
    }
    else if(algo == "newBest_batch")
    {      
      float* bestPtr = best.data().get();
      float* newBestPtr = newBest.data().get();
      int duSize = dU.size();
      int* duPtr = dU.data().get();
      int* dvPtr = dV.data().get();
      float* dcPtr = dC.data().get();
      int threads = blockSize * blockCount;
      int groupSize = (duSize + threads - 1) / threads;

      void* kernelArgs[] = {
        &itersPerBatch, &groupSize, 
        &bestPtr, &newBestPtr,
        &duSize, &vertices, &duPtr,  &dvPtr, &dcPtr};

      CUDA_CHECK(cudaLaunchCooperativeKernel(batchIterations_newBest, 
          {(unsigned int)blockCount}, {(unsigned int)blockSize},
          kernelArgs, 0, 0));

      anyChanged = newBest != best;
      best = newBest;
      doneIters += itersPerBatch;
    } else 
    {
      assert(false);
    }
    

    if(doneIters%printOnceEvery == 0) {
      tracer.trace(std::format("Completed {} iterations", doneIters), true);
      //printBest("Interim", best);
    }

    if(!anyChanged) break;
  }

  tracer.trace(std::format("Completed all. Took {} iterations", doneIters), true);
  
  printBest("Completed all.", best);
}

int main(int argc, char* argv[]) {
  BfConfig config;

  if (argc == 7) {
    config = BfConfig::fromArgs(argv + 1);
  } else if(argc != 1) {
    std::cerr << 
R"(Usage
-----
path/to/executable <vertices> <edges> <itersPerBatch> <blockSize> <blockCount> <algo=scattered|newBest_one|newBest_batch>
OR
path/to/executable
)"
       << std::endl;
    return 1;
  } else {
    config = BfConfig::defaultConfig();
  }

  doMain(config);
  return 0;
}
