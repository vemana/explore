# FAQ

## What is this?
A starter CUDA optimization project. It exercises many critical paths like reducing global memory loads, sizing grids appropriately, evaluating performance of scattered writes and so on. It is a simple algorithm that presents a rich surface for optimization.

## What is the problem?
We computes shortest path from vertex 0 to every other vertex. The so-called single-source shortes paths problem. We do this using Bellman Ford algorithm which has `O(V*E)` time complexity. It repeatedly `relaxes` each edge and is effectively equivalent to finding a fixed point for a set of inequalities `d(v) <= d(u) + edge_cost(u, v)` until `d` (the distance from vertex 0) stabilizes and exhibits no further change.

If you map each relaxation step (across all edges) as one kernel invocation and each edge to a kernel thread, you still have to contend with the fact that the vertices of the `i`th bear no relation to `i` itself and you don't utilize memory bandwidth properly.


## How to run?
Run `run.sh`. It won't work unless you have nvcc installed in a specific place. Sorry.

## What are the key points?
* learn about grid.sync() in cooperative kernel launch
* reading and writing the array `best[]` in a kernel using unpredictable indices requires synchronization and can easily produce wrong results otherwise
* kernel launch is fast; but it is noticeable if you launch 100K times

## Results?
See `results` folder.
