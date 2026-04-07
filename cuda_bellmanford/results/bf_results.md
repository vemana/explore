This has results of the CUDA Bellman Ford algorithm.

Tests were run on a local RTX 3090. As the `bf.cu` reveals, there's little CPU involvement; even the randomn graph is generated using CUDA libraries.


The algorithm is run on a random graph. First, I generate a random graph. Then, I add a path `0 -> 1 -> 2 -> ... -> N-1` with each edge 0 weight so that
- The Bellman Ford algorithm has to iterate for V times
- The final `d` value is 0 for every vertex
- This way we have comparable latency across runs and correctness verifiability too

------
1000 relaxation per kernel.

112345 vertices, 712345 edges, **total work approx 8 * 10^10, 2s on RTX 3090**, launching 113 kernels

```
$ ./run.sh compile bf.cu 112345 712345 1000 256 336 newBest_batch                                                                                                                                                                                                                                                                                                                                                 

vertices         =       112345
edges            =       712345
maxCost          =        1e+04
seed             =           42
blockSize        =          256
blockCount       =          336
algo             = newBest_batch
itersPerBatch    =         1000

[       0] About to generate graph
[    1628] About to sort generated graph
[    1629] Sorted graph
[    1630] Starting Iterations
[    1722] Completed 5000 iterations
[    1813] Completed 10000 iterations
[    1901] Completed 15000 iterations
[    1985] Completed 20000 iterations
[    2069] Completed 25000 iterations
[    2153] Completed 30000 iterations
[    2237] Completed 35000 iterations
[    2320] Completed 40000 iterations
[    2403] Completed 45000 iterations
[    2487] Completed 50000 iterations
[    2570] Completed 55000 iterations
[    2653] Completed 60000 iterations
[    2737] Completed 65000 iterations
[    2822] Completed 70000 iterations
[    2905] Completed 75000 iterations
[    2989] Completed 80000 iterations
[    3071] Completed 85000 iterations
[    3154] Completed 90000 iterations
[    3237] Completed 95000 iterations
[    3319] Completed 100000 iterations
[    3401] Completed 105000 iterations
[    3482] Completed 110000 iterations
[    3531] Completed all. Took 113000 iterations
Printing best... Completed all.
(0 0.00) (1 0.00) (2 0.00) (3 0.00) (4 0.00) (5 0.00) (6 0.00) (7 0.00) (8 0.00) (9 0.00) 
(112344 0.00) (112343 0.00) (112342 0.00) (112341 0.00) (112340 0.00) (112339 0.00) (112338 0.00) (112337 0.00) (112336 0.00) (112335 0.00) 
```

----------------------

5000 relaxation steps per kernel.

112345 vertices, 7123456 edges, **total work approx 8 * 10^11, 15s on RTX 3090**, launching 23 kernels

```
$ ./run.sh  bf.cu 112345 7123456 5000 256 336 newBest_batch
Executing now: bf
--------------------------------------
[       0] Initated main
[       0] Parameters
-----------
vertices         =       112345
edges            =      7123456
maxCost          =        1e+04
seed             =           42
blockSize        =          256
blockCount       =          336
algo             = newBest_batch
itersPerBatch    =         5000

[       0] About to generate graph
[    1685] About to sort generated graph
[    1689] Sorted graph
[    1694] Starting Iterations
[    2369] Completed 5000 iterations
[    3047] Completed 10000 iterations
[    3721] Completed 15000 iterations
[    4398] Completed 20000 iterations
[    5076] Completed 25000 iterations
[    5753] Completed 30000 iterations
[    6428] Completed 35000 iterations
[    7104] Completed 40000 iterations
[    7778] Completed 45000 iterations
[    8451] Completed 50000 iterations
[    9124] Completed 55000 iterations
[    9796] Completed 60000 iterations
[   10466] Completed 65000 iterations
[   11134] Completed 70000 iterations
[   11803] Completed 75000 iterations
[   12468] Completed 80000 iterations
[   13134] Completed 85000 iterations
[   13798] Completed 90000 iterations
[   14456] Completed 95000 iterations
[   15113] Completed 100000 iterations
[   15767] Completed 105000 iterations
[   16419] Completed 110000 iterations
[   17070] Completed 115000 iterations
[   17070] Completed all. Took 115000 iterations
Printing best... Completed all.
(0 0.00) (1 0.00) (2 0.00) (3 0.00) (4 0.00) (5 0.00) (6 0.00) (7 0.00) (8 0.00) (9 0.00) 
(112344 0.00) (112343 0.00) (112342 0.00) (112341 0.00) (112340 0.00) (112339 0.00) (112338 0.00) (112337 0.00) (112336 0.00) (112335 0.00) 
```

-----------------------

1 relaxation per kernel. The number of kernel launches = number of vertices.

112345 vertices, 712345 edges, total work ~ 8*10^10, 5s on RTX 3090 with 112345 kernel launches. **Kernel launch ~ 40 us.**

```
$ ./run.sh bf.cu 112345 712345 1000 256 336 newBest_one

vertices         =       112345
edges            =       712345
maxCost          =        1e+04
seed             =           42
blockSize        =          256
blockCount       =          336
algo             =  newBest_one
itersPerBatch    =         1000

[       0] About to generate graph
[    1654] About to sort generated graph
[    1655] Sorted graph
[    1656] Starting Iterations
[    1892] Completed 5000 iterations
[    2108] Completed 10000 iterations
[    2323] Completed 15000 iterations
[    2539] Completed 20000 iterations
[    2752] Completed 25000 iterations
[    2967] Completed 30000 iterations
[    3181] Completed 35000 iterations
[    3395] Completed 40000 iterations
[    3610] Completed 45000 iterations
[    3824] Completed 50000 iterations
[    4038] Completed 55000 iterations
[    4252] Completed 60000 iterations
[    4466] Completed 65000 iterations
[    4680] Completed 70000 iterations
[    4892] Completed 75000 iterations
[    5106] Completed 80000 iterations
[    5321] Completed 85000 iterations
[    5536] Completed 90000 iterations
[    5750] Completed 95000 iterations
[    5967] Completed 100000 iterations
[    6182] Completed 105000 iterations
[    6397] Completed 110000 iterations
[    6498] Completed all. Took 112345 iterations
Printing best... Completed all.
(0 0.00) (1 0.00) (2 0.00) (3 0.00) (4 0.00) (5 0.00) (6 0.00) (7 0.00) (8 0.00) (9 0.00) 
(112344 0.00) (112343 0.00) (112342 0.00) (112341 0.00) (112340 0.00) (112339 0.00) (112338 0.00) (112337 0.00) (112336 0.00) (112335 0.00) 
```