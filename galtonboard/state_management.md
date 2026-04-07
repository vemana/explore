# What is this?
This is my solution for managing state in Flutter apps based on the experience of writing Galtoboard.

State management is such a problem in every UI framework there is. Flutter is no different. Flutter comes across as having been designed with different goals and State management was not one of them. I looked at React and it seemed way worse. 

The Flutter ecosystem manages state in various ways. I looked at the popular libraries - Riverpod, Provider, GetX, Bloc. All of them had fairly significant shortcomings for reasonably complex/large codebases. 

So, I spent a fair amount of time working out how I'd manage state under the following constraints
- Don't sphagettify the codebase
- You should have very high certainty - without even running the UI - what your change would do. This level of certainty is not possible in sphagetti UI codebases

# Spill the beans...
This is my mental model for managing State in Flutter. Galtonboard app follows it quite religiously.

* **UI = f(State)**. All my choices follow logically from this mantra. In fact, before I knew any details, I thought it was worth trying Flutter just for this mantra.  
* **State exists even without UI**. What is State? I pretend that my app is controlled via command line (no graphical interface) and the core that remains is the State. I also find it useful to pretend that my users are across a phone line (so, no graphical interface, no command line) - this brings even more clarity to what my State is.  
* **State, UState and View** are the three kinds of classes  
  * UState is like State except it is for display purposes. For example, user’s preferences of colors, fonts etc. would be UState.  
  * View classes are just immutable classes that have methods that return Widgets. More on this later.  
* **State is pristine.** No wrapping it, no special extends X, no dependency on flutter. Just pure, plain Dart classes. Mutable state can choose to be observable.  
* **Dependency Injection**. Large codebases benefit from it. I like it from day 1\. I was going to write one with AssistedInject support, but luckily found this package: inject\_annotation which supported it. Much thanks to the author.  
* **Widgets are returned by methods on Views.** Views are immutable classes. They can refer to as much state as they like \- the entire app’s state or a small piece \- via DI and construct widgets. A View can have many Widget returning methods. Organize it as it makes sense. AssistedInject is very handy to construct objects out of non-singleton state. Since they don’t take the BuildContext parameter, there’s no risk of over-rebuilding.  
* **Widgets apply user actions by invoking methods on State**. There's no additional layer here. Widgets (being constructed from Views) have access to State objects and one user action typically translates to one call on a State instance.  
* **Decouple WHEN to rebuild from WHAT to rebuild.** I have **exactly one** StatefulWidget class. It’s called RebuildOnEvent and its job is to rebuild its child widget upon changes to an object it observes. This allows my widget construction in Views to look like: “My widget is a function of state X, Y and Z. When any of X, Y, Z change, rebuild it”. I made it ergonomic to code and read back.  
* **Avoid**  
  * Using BuildContext. Prefer reducing number of concepts  
  * Using InheritedWidget. State needs to be accessible from anywhere, not just descendant widgets  
  * Writing new Stateful Widgets. Just use the one   
  * probably more I am forgetting. But, general rule is to reduce number of concepts

That’s most of it. Caveat obviously that it is not battle tested and I am yet to write more complex apps, but I know in my mind’s eye how they’ll work. There’s also nothing that I see that I can take away - State, UState, Views all need to exist and State needs to be Observable and Widgets need to rebuild based on updates. So, I feel this is at least a locally optimal solution.

# Code Pointers
The above model is reflected in the code. Look at examples:
- [Main View](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/example/galtonboard/lib/src/ui/main.ui.dart#L22)
  - a view injects State and UState as it needs
  - view returns a widget
  - located in ui/ package
  - uses [guard](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/common/ui/widgets/lib/src/rebuild_on_event.dart#L43) clauses to convey when to rebuild. The `guard` simply says `whenever any of the guarded state (or ustate) changes, rebuild my widget`
  - state changes => updated event fired => guard notices it => rebuilds widget.
  - A widget that is 20 levels deep only needs to rebuild on level 19 and below if that's all that is needed.
- [Main State](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/example/galtonboard/lib/src/state/mainstate.dart#L9)
  - holds the state of the simulation
  - independent of the UI
  - located in state/ folder
- [UState](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/example/galtonboard/lib/src/ustate/debug_panel.dart#L6)
  - ustate is state that exists only for UI purposes
  - located in ustate/ folder
- [EventBus](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/common/event/lib/src/eventbus.dart#L44)
  - Sends events to subscribers registered on the bus
- [RebuildOnEventWidget](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/common/ui/widgets/lib/src/rebuild_on_event.dart#L69)
  - Rebuilds a widget upon hearing an event
  - The only event we have write now is `I am an object and my state has changed`
- State listens to other State ([example](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/example/galtonboard/lib/src/state/simcontrol.dart#L39)) for updates
- State changes fire events ([example](https://github.com/vemana/explore/blob/97b83094b39126efedfb9891dc9081a3a13ef6c8/galtonboard/example/galtonboard/lib/src/state/simstate.dart#L114)) on the EventBus


# Mental Model
The mental model of the codebase can be distilled into this:
- A state object defines its state at any given moment as `values of its public fields + the return values of its public methods at that moment`
- A state object fires updates on the event bus whenever its state changes
- A state object registers and listens to updates of its dependencies in order to update itself
- A ustate object is like state but for UI concerns. For example, if a button is on or off is represented as some boolean parameter in ustate. Then, when the button is added to a view, it is turned on or off based on the correponding boolean. This may seem unconventional but it is really important to maintain the `UI = f(State)` invariant
- State updates are NOT finegrained. An object simplys says `my state changed`. It does not say `my field X changed` or `my method M changed`. This is extremely important for keeping the codebase maintainable. If you need to reduce the granularity of a state update, reduce the granularity of the object itself by extracting out a portion of it.
- Views inject as much state and ustate as they want to compose the view
- Views declare dependencies on state using `guard` clauses. The view expresses `I am a view. I depend on the state of objects X, Y & Z and hence I need to rebuilt whenever the state of any of X, Y and Z changes.`