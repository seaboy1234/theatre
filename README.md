
# Theatre

Theatre is an extremely simple [Actor](https://en.wikipedia.org/wiki/Actor_model)
library for the [D Programming Language](https://dlang.org).

```d
import theatre;

@actor class MyActor
{
    mixin Actor;

    @behavior void callBehavior()
    {
        writeln("Hello, World!");
    }
}

MyActor a = newActor!MyActor();
scope(exit) a.destroy() // stop the message loop

a.callBehavior() // asynchronous call

MyActor b = new MyActor();
a.callBehavior() // synchronous call.
```

## Background

The library is built on `std.concurrency.Scheduler` and uses `send` and `receive` for passing
messages. Each actor is represented as its own logical thread, though is compatible with fibers.

The fundamental goal of Theatre is to allow writing actors as though they are any other object.
An actor can be passed around like any class and functions called as though they were a regular
object. Under the hood, these function calls are converted to messages that are passed to `send`
and `receive`d by the actor's event loop. As such, behavior function calls can largely be considered
atomic operations on actors.

## Usage

```d
// The most basic actor.
@actor class BasicActor
{
    mixin Actor;
}

// Actors can also have constructors like any other class.
@actor class Player
{
    private
    {
        string _name;
        int _health;
    }

    mixin Actor;

    this(string name, int health)
    {
        _name = name;
        _health = health;
    }

    @behavior void sayHello(string greeting = "Hello, World!")
    {
        writeln("<", name, "> ", greeting);
    }

    // Behaviors can return values.
    @behavior bool alive()
    {
        return _health >= 0;
    }
}

void main(string[] args)
{
    import std.concurrency;

    scheduler = new FiberScheduler();

    scheduler.start((){
        Player p = newActor!Player("Alice", 100);
        scope(exit) p.destroy() // Make sure to destroy p.

        p.sayHello(); // => <Alice> Hello, World!

        assert(p.alive);
    });
}
```

### Disposing Actors

Because of its reliance on a message loop, **the garbage collector will never collect actors**.
To stop the message loop and allow the garbage collector to collect the actor, call the actor's
`destroy()` function.

## Limitations

### Templates

Because theatre uses `std.typecons.AutoImplement` to override behavior functions, templates are not supported.

### @safe

Theatre is not `@safe`.

### Nested Classes

In most cases, nested actor classes are not supported. In short, the class must be accessible from
`std.typecons.AutoImplement` to work.

## Future Work

* Supporting actors over network/process barriers à la Erlang
* Integration with other concurrency models (e.g. vibe-core)
