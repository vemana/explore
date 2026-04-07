# What is this?
Simulates a Galtonboard. hosted at [https://galtonboard.pages.dev/](https://galtonboard.pages.dev/). A Galton board simulates a Gaussian distribution by taking a point and randomly sending it left or right over many obstacles.

This simulation supports many parameters
- Speed of simulation: change speed dynamically as the user changes the slide. No visual jitter
  - Pausing and Resuming the simulation. Special case of simulation speed
- Number of points to simulate: drawing thousands of circles per frame or 1 circle per frame
- Number of levels to simulate: More levels = more points
- Bias of each point (e.g. goes left with 90% probability)
- Whether to render stats (e.g. FPS)

All the above has to be done at 60 FPS without any stutter or visually noticeable gaps. each circle travels down the screen at a set velocity (controlled by user). On each frame,
- draw each point's location as a red circle
- if the circle meets one of the obstacles, toss a (biased) coin and decide which way to send the circle
- once the circle exits the obstacle (based on its vertical speed), redraw it, otherwise hide it
- once the circle falls into the bottom of the bucket, reflect the bucket percentage
- This shape should resemble the Gaussian distribution (Bell curve) over time

# Why this?

This was my first project in Flutter. I was always fascinated by Flutters `UI = f(State)` headline and wanted to give it a try. 

I chose this relatively complex project for two main reasons:
- To learn if Flutter could ergonomically support huge frontend codebases
- As a fun project to demonstrate the effect of random choices to my parents because it came up in a conversation

This example is complex enough to expose any Flutter shortcomings - it has a ton of user controls, manages a ton of state, needs to stay performant and run both as a mobile app (Android in my case) as well as web from the same codebase.

# How did Flutter do?
 Turns out Flutter has a lot of good stuff. For example,
- The layout engine is O(N) (except in a handful of cases; unlike CSS and other layout engines)
- Views are expressed as simple compositions of other views and primitive views
- Provides a game-like experience on the Web. There's even support for shaders. In this project, I only use `drawAtlas` which batches a bunch of points and sends to GPU for rendering
- Compiles to wasm as well for better performance. In this project, Chrome's GPU acceleration matters when simulating high number of points at a high speed.
- Devx is fantastic for a frontend. Very quick refresh cycle
- This same code compiles into an Android app and renders well natively too (terrific!)

Overall, the framework is quite impressive.

# Flutter's shortcomings

I did run into problems with (1) State management and (2) WASM support on the web.

State management is intrinsically hard in UIs and Flutter doesn't have a great story. I looked at React and that looked way worse. Then I looked at libraries in the ecosystem. Riverpod, Provider, Bloc and GetX all seemed to have significant shortcomings. They are all intrusive to the data model.

WASM support was still immature as of late 2024. There were significant memory issues as the webapp would continuously increase memory usage until OOMing Chrome. I had to make quite a few tweaks to keep it under control for a long time.

# State Management

See my [state management mental model](state_management.md). It took me a while to solve but I eventually reasoned out a state management solution. It is to my taste and I find it ergonomic even for large codebases. It pretty much follows from `UI = f(State)`, retains the pristineness of domain model and is essentially unintrusive - in other words, I think it is a locally optimal solution for its feature-set.

# How does it look ?
![alt text](image.png)