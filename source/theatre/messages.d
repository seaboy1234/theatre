module theatre.messages;

import std.typecons : Tuple;

/**
    Message to call a specific behavior. Reserved for internal use.
*/
struct CallBehavior(string _behavior, Return, Args...)
{
    import std.concurrency : Tid;

    /// The name of the behavior to call.
    enum name = _behavior;

    /// The Tid that sent this message.
    Tid sender;

    /// The real function to invoke.
    shared Return delegate(Args) invoke;

    /// Arguments passed to this behavior function.
    Tuple!Args args;
}

/**
    Message that represents the return value of a non-void behavior call.
    Reserved for internal use.
*/
struct ReturnMessage(string behavior, T)
{
    /// The value that was returned.
    T value;
}

/**
    Message used to notify that an actor's message loop is running.
*/
struct ServiceRunning
{
}

