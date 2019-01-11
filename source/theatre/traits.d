module theatre.traits;

import std.meta;
import std.traits;

import theatre.actor : actor, behavior;

/// Returns whether $(D_PARAM T) is an actor
enum bool isActor(T) = is(T == class) && hasUDA!(T, actor)
    && MemberFunctionsTuple!(T, "__runService").length;

/// Returns whether the $(D_PARAM fun) is a valid behavior function.
enum bool isBehavior(alias fun) = hasUDA!(fun, behavior) && isSharedFunction!fun;

/// Returns whether the $(D_PARAM fun)'s parameters can be sent over thread barriers.
template isSharedFunction(alias fun)
{
    static foreach (param; ParameterStorageClassTuple!fun)
    {
        static if (!is(typeof(failed)) && param & (1 << ParameterStorageClass.ref_))
        {
            enum failed = true;
        }
        static if (!is(typeof(failed)) && param & (1 << ParameterStorageClass.out_))
        {
            enum failed = true;
        }
    }

    static if (!is(typeof(failed)))
    {
        enum failed = false;
    }

    enum isSharedFunction = !failed
        && allSatisfy!(templateNot!hasUnsharedAliasing, Parameters!fun);
}

/// Returns all behavior functions on the given actor type.
template getBehaviors(T) if (isActor!T)
{
    alias getBehaviors = Filter!(isBehavior, getFunctions!T);
}

/// Returns all public functions on the given type.
template getFunctions(T)
{
    alias getFunctions = Filter!(isSomeFunction, getPublicMembers!T);
}

/// Returns all public members on the given type.
template getPublicMembers(T)
{
    enum bool isPublic(string member) = __traits(compiles, __traits(getMember, T, member));

    alias getPublicMembers = staticMap!(ApplyRight!(getMember, T),
            Filter!(isPublic, __traits(allMembers, T)));
}

/// Gets the supplied member from $(D_PARAM T).
template getMember(string Member, T)
{
    alias getMember = Alias!(__traits(getMember, T, Member));
}
