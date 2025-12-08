#  Atlas Tracer
![GitHub contributors](https://img.shields.io/github/contributors/maxvdec/atlas-tracer)
![GitHub last commit](https://img.shields.io/github/last-commit/maxvdec/atlas-tracer)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues/maxvdec/atlas-tracer)
![GitHub Repo stars](https://img.shields.io/github/stars/maxvdec/atlas-tracer)

Atlas Tracer is a macOS application that helps the user debug Atlas applications made with the engine.

## How does it work?

Atlas Tracer works in a simple way through ports in your computer. The application interacts with the engine, and they send and recieve packets of information encoded that then the application
deciphers to give the user real-time data of what's going on the inside of the compiled game.

## Types of Sessions

Atlas Tracer works with different types of *sessions*, which they are basically different types of information that it can display:

* Graphics Sessions: These are focused on draw calls and performance of the Graphics Engine and Vulkan.
* Logic Sessions: These are focused on what the engine is doing besides rendering, like computing atmosphere or the other decisions it is taking.
* Resource Sessions: These are focused on what resources is the engine loading, how much time it spends doing it and other insights.
* Object Sessions: These are focused on the objects rendered in the screen, meaning triangle count, and general computing time insights.
* Trace Sessions: These are focused on how many memory is the engine using, including also render buffers.
* Profiling Sessions: These are focused on the timing that it takes to do certain stuff, they are tailored to what the person debugging wants.

## How to implement an Atlas Tracer?

If you waent to implement you own application that can interact with Atlas, you can consult our documentation on the protocol.
 

