module theatre.actor;

import std.meta;
import std.traits;
import std.typecons;

import theatre.messages;
import theatre.traits;

/**
    Designates a $(D_KEYWORD class) as an actor class.

    Notes:
        This attribute is more statically enforced documentation 
        than anything else. It's simple meant to help disambiguate 
        whether a class should be constructed differently.
*/
struct actor
{
}

/**
    Designates a $(D_KEYWORD function) as a behavior. 
    
    Behavior functions are queued on the Actor's message queue and executed
    in the order they are received. In that sense, behavior functions
    can be thought of as atomic operations on a object, sense no 
    other behavior function will execute at the same time.
*/
struct behavior
{
}

/**
    Various helpers for dealing with behavior functions.
    Reserved for internal use.
*/
struct BehaviorInfo(alias fun) if (isBehavior!fun)
{
    alias Args = Parameters!fun;
    alias Message = CallBehavior!(__traits(identifier, fun), Return, Args);
    alias Return = ReturnType!fun;

    alias Delegate = void delegate(Message);

    /// Message handler for this behavior function.
    void invoke(Message msg)
    {
        import std.concurrency : send;

        static if (is(Return == void))
        {
            (cast() msg.invoke)(msg.args.expand);
        }
        else
        {
            Return val = (cast() msg.invoke)(msg.args.expand);
            send(msg.sender, ReturnMessage!(msg.name, Return)(val));
        }
    }
}

/**
    Mixin template to create core infrastructure for supporting
    actors. This template creates the actor's event loop and
    its queuing infrastructure.
*/
mixin template Actor(string file = __FILE__, int line = __LINE__)
{
    import std.concurrency : Tid;
    import std.traits : hasUDA, isFinalClass;

    import theatre.traits;
    import theatre.messages;

    protected
    {
        shared bool __running;
        Tid __tid;
    }

    static assert(isActor!(typeof(this)), typeof(this) ~ " must be annotated with @actor!");
    static assert(!hasUDA!(__runService, behavior), "Actor methods may not be behaviors!");
    static assert(!hasUDA!(__enqueueTask, behavior), "Actor methods may not be behaviors!");

    /// Runs the event loop and notifies $(D_PARAM ownerTid) that the event loop has started.
    /// Reserved for internal use.
    final void __runService(Tid ownerTid)
    {
        import core.atomic : atomicLoad, atomicStore;
        import std.concurrency : thisTid, receive, send;
        import std.meta : ApplyLeft, staticMap;
        import std.typecons : Tuple;

        alias This = typeof(this);
        alias Handlers = staticMap!(BehaviorInfo, getBehaviors!This);
        alias Delegates = staticMap!(ApplyLeft!(getMember, "Delegate"), Handlers);

        Tuple!(Delegates) createHandlers()
        {
            Tuple!(Delegates) delegates;

            static foreach (i, Type; Handlers)
            {
                delegates[i] = &Type().invoke;
            }

            return Tuple!(Delegates)(delegates.expand);
        }

        atomicStore(__running, true);
        __tid = thisTid;
        send(ownerTid, ServiceRunning());

        enum handlers = createHandlers;
        while (atomicLoad(__running))
        {
            receive(handlers.expand);
        }
    }

    static foreach (fun; getFunctions!This)
    {
        static if (hasUDA!(fun, behavior))
        {
            static assert(__traits(getProtection, fun) == "public",
                    "Behavior " ~ __traits(identifier, fun) ~ " must be public!");

            static assert(isSharedFunction!fun,
                    "Aliasing unshared data not allowed for " ~ __traits(identifier, fun));
        }
    }

    /// Adds a method call to the queue. Reserved for internal use.
    final protected void __enqueueTask(string fun, Return, Args...)(
            Return delegate(Args) invoke, Args args)
    {
        import std.concurrency : send, thisTid;
        import std.typecons : Tuple;

        send(__tid, CallBehavior!(fun, Return, Args)(thisTid,
                cast(shared) invoke, Tuple!(Args)(args)));
    }

    /// Notifies this actor to exit the event loop.
    @behavior void destroy()
    {
        import core.atomic : atomicStore;

        atomicStore(__running, false);
    }
}

/**
    Instantiates a new actor with the given arguments.
*/
T newActor(T, Args...)(Args args) if (isActor!T)
{
    import std.concurrency : spawn, receive, thisTid, Tid;

    ActorImpl!T actor = new ActorImpl!T(args);

    Tid tid = thisTid;

    static void start(shared ActorImpl!T actor, Tid owner)
    {
        (cast() actor).__runService(owner);
    }

    spawn(&start, cast(shared) actor, tid);

    receive((ServiceRunning msg) {}); // Wait until the service actually starts.

    return actor;
}

/// Implements $(D_PARAM fun) as a behavior. Reserved for internal use. 
string implBehavior(T, alias fun)() @property
{
    import std.string : format;

    return q{
        import std.concurrency : thisTid, receive;

        import theatre.messages : ReturnMessage;
        
        alias R = ReturnType!%1$s;

        if (thisTid == __tid)
        {
            // When we're calling this locally, we can simply call the 
            // function without enqueuing the task.
            static if(!is(R == void))
            {
                return super.%1$s(args);
            }
            else
            {
                super.%1$s(args);
            }
        }
        else
        {
            __enqueueTask!"%1$s"(&super.%1$s, args);
            static if(!is(R == void))
            {
                R ret;
                receive((ReturnMessage!("%1$s", R) msg) { ret = msg.value; });
                return ret;
            }
        }
    }.format(__traits(identifier, fun));
}

private alias ActorImpl(T) = AutoImplement!(T, implBehavior, isBehavior);
