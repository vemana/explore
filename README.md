# What is this repo?

An eclectic mix of small projects for one of
- my own amusement
- exploring new things by doing small but non-trivial projects
- sharing knowledge and occasionally wisdom (if the Gods so deign)
---

# What's in here?
- **anthropic_original_performance_takehome**: [Anthropic's performance challenge](https://github.com/anthropics/original_performance_takehome) pits potential engineer hires against Claude Opus. This is my entry (1110 cycles) to Claude's 1363 (lower is better). The challenge is to optimize batch tree traversal on a VLIW machine. Instead of boringly writing specific code for this problem, I took the opportunity to write a custom programming language, a compiler targeting the VLIW machine and an optimizer. See [solution_readme](anthropic_original_performance_takehome/solution_readme.md) for details.

- **galtonboard**: Simulates a Galtonboard. Hosted at [https://galtonboard.pages.dev/](https://galtonboard.pages.dev/). Wrote this for two reasons (1) To show the effects of random choices averaged over many instances to family members (I am the chief nerd of the fam). (2) Evaluate if Flutter is ergonomic for large, complex UIs. See [my impressions](galtonboard/README.md) here.

- **cuda_bellmanford**: This project implements the Bellman Ford single-source-shortest-paths algorithm on a weighted (no negative cycle) graph on a GPU (my trusty local RTX 3090). I wrote this to (1) explore CUDA and (2) experiment optimizing memory bandwidth of GPU programs. See [details](cuda_bellmanford/README.md).

- **fast_cpp_spsc_queue**: This is a simple, fast SPSC queue (2.2B int64 exchanges/sec on Ryzen 7950X) in C++ that is in sympathy with the hardware. Modern processors (even CPUs) are remarkably fast if you use them in a certain way - by understanding the cache coherency protocol, memory consistency model, the bandwidth of inter-core cache communication. See [details](fast_cpp_spsc_queue/README.md)

- **1brc**: The (in)famous Java [1-Billion Row Challenge](https://github.com/gunnarmorling/1brc). This repo contains my entry and helper scripts to run it (if it still runs!). It finished top 20 in the comp and top 10 in the hidden bonus set (a harder challenge that penalized overfitting on the competition set).

- **jmh_junit**: A Java JUnit test runner that can run JMH benchmarks & assert on metrics, run tests in parallel or a combination of both. JMH in junit is valuable for CI of performance-critical sections. Running parallel tests (while sharing test-class-level setup) cuts down iteration time on slow tests (e.g. those that start up servers).
---

# How do I run these?

My main goal is to put out the full code but not necessarily the build tooling. Some of them are adhoc projects and build tools are just a script or two tweaked to work on my machine. Some come from my personal monorepo on Bazel and it is pretty timeconsuming to extract a working version. So, I just make no promises on building/running them. Besides, they are not that interesting! That said, all the relevant code is there.

