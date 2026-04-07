# FAQ

## What is this?
A starter CUDA optimization project. It exercises many critical paths like reducing global memory loads, sizing grids appropriately, evaluating performance of scattered writes and so on. It is a simple algorithm that presents a rich surface for optimization.

## How to run?
Run run.sh. It won't work unless you have nvcc installed in a specific place.

## What are the key points?
* learn about grid.sync() in cooperative kernel launch
* reading and writing the array `best[]` in a kernel with different indices requires some synchronization coordination. Seeing wrong results because of this.
* kernel launch is fast; but it is noticeable if you launch 100K times.

## Results?
See `results` folder.
