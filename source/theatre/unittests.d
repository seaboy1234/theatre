module theatre.unittests;

version (testing_theatre)  : version (unittest)
{
}
else
{
    static assert(0, "Need unittest build config!");
}

import core.thread;
import std.concurrency;

import theatre.actor;

import unit_threaded;

@actor class TestActor
{
    int calls;
    ThreadID remote;
    ThreadID local;

    mixin Actor;

    @behavior int inc(ThreadID sender = Thread.getThis.id)
    {
        calls += 1;
        remote = sender;
        local = Thread.getThis().id;

        return calls; // To ensure the caller waits for return.
    }
}

@("Actors are normal classes")
unittest
{
    TestActor actor = new TestActor();

    actor.inc();

    assert(actor.remote == Thread.getThis().id);
}

@("Actors execute asynchronously")
unittest
{
    TestActor actor = newActor!TestActor();
    scope (exit)
        actor.destroy();

    actor.inc();

    actor.remote.should.not == actor.local;
}
