# Metamorphosis. Kykeon cooked by Circe. Or just plugins.

Metamorphosis provides you with a generic "plugins" system. Using Metamorphosis,
a module or a class is able to alter and/or extend its original behavior at
run-time, in a standardized, programmer-friendly way.

Typical use-cases may be:

* you wrote a tiny yet powerful application, and would like to be able to extend
its functionnalities without clutering the code base with loads of specific stuff;
* you wrote your very own CMS and would like your users to be able to write and
share some plugins;
* you are using software someone else wrote and would like to be able to customize
your running instance with some very specific features only you care about;
* you wrote a script which would gain on being able to alter its behavior at
run-time and per-module or even per-class.

Let's review a common pattern

    module MyProject
      # So let's say a plugins system would be nice for MyProject...
      # MyProject is called the receiver, because it extends Metamorphosis:

      extend Metamorphosis

      # By doing so, it gains some new functionalities related to plugins definition.
      # At this point, MyProject's internals are exposed in a standardized way
      # to Metamorphosis DSL. Both Speaker and Server modules can be altered
      # by plugins.

      module Speaker
        def say something
          puts "say: #{something}"
        end
      end

      module Server
        a = Speaker.new
        a.say "hello world!" # => hello world!

        # Ok, talking backward is cool. Let's do that.
        MyProject.activate "backward"

        a.say "hello world again!" # => hello world again!
        # Goodness me!
        # Well, actually, the Backward plugin affects Speaker's instances,
        # but only thoses defined from the time it is activated.

        Speaker.new.say "hello then" # => neht olleh
      end
    end

Here's how the Backward plugin is defined:

    module Spells
      module Speaker
        module InstanceMethods
          def say something
            super something.reverse
          end
        end
      end
    end

Some more examples are available under the `example` directory. *Spells* is to
Metamorphosis what you may brand as *plugins*. That's the default, but it can easily
be changed to any custom value, allowing you to tailor the DSL.

So you just open the `Spells` module, then open a module which name mimics the name
of whatever receiver's module or class you want to hook-in (`Speaker`). Here comes a
piece of *Convention*: we want to modify instances behavior, so let's make that
explicit and open an `InstanceMethods` module. Then we talk backward.

We could have merely redefine `say` but instead, we called `super` with a new
argument. It's just to illustrate how cool is this: `super`. No. More. Alias.

## Inheritance everywhere!

Traditionnal plugins solutions wants you to manage some aliasing and make it hard
to fallback on original behavior should you want to. Metamorphosis ships with a
clean extension mechanism which handle both class and instance behavior redefinition
on-the-fly.

    code...

Metamorphosis relies on the power of Ruby's mixin and `extend` method to design
a powerful inheritance chain around your objects. To learn more about the nitty-gritty
details, see the section "Under the hood".

## Just write the code you care about

Metamorphosis aims at making the process of writing plugins dead-simple. Using some
smart *Convention Over Configuration* rules, it allows you to focus on the plugin's
code. If you abide by the defaults, only three things are your responsibility:

1. write some plugin of your own kind targeting a "receiver"
2. declare that you want to use Metamorphosis for the specific receiver
3. activate your plugin!

A simple convention in plugins definitions makes it possible to auto-discover
which internal modules or classes of the receiver are concerned by the plugin.
Once the plugin is be activated, it will outfit its targets with new or
revamped behavior, while retaining the ability to fallback on
their original behaviors via simple inheritance (think `super`).

## Customize the hooks

Given a smart plugin definition, Metamorphosis will automagically find class and
instance methods in their proper location within the receiver. Yet there are some
times when you want to gain control over the process, so you can actually get rid
of the *Convention* and dive into the *Configuration*.

You may:
* specify your very own merging process between the receiver and the plugin (you
may use the pretty common idioms of `send :extend, SomeMethods` Rails teached you
about, or do it some other way)
* tweak with the configuration so as to streamline which parts of the receiver
can actually be altered by the plugins, or even compose a hydra-like receiver,
gathering otherwise unrelated pieces of your software.

## A few words about the DSL, Ancient Greek cuisine and security

Everybody's familiar with the notion of metamorphose. A differentiation
process turns some entity into another, while retaining its identity. Was
Mr Hyde some kind of plugin to Dr Jekyll? What about Lepidopteras?

In Greek mythology, Circe is a minor goddess of magic famous for her ability
to use meals as metamorphose spells. She used to share kykeon, a mix between a
beverage and a meal, to hide her poisons and charms.

I retained the phrasing of "spells" to designate what are mostly "plugins". Yet,
Metamorphosis is not *really* about plugins. It's more about extending "something"
you want with **new** or **modified** behaviors. Plugins *add* functionalities,
so the semantics is quite non-destructive: one doesn't want a *plug-in* to turn the
master into a crank, or make the base explode, or *break the software*. Metamorphosis
does not make such an assumption and lets you do merely anything to your "something".
It's a general-purpose metamorphose system.

Advice, then: if you want to use it as a **solid** plugins system, you may want to
add some control on top of it (be it automatic or by peer-reviewing). Forthcoming
refinements on the quantity of information Metamorphosis shares with the receiver
should allow you to perform fine-checks, wait & see.

# Care about your parents, they made you (or not?)

Yet plugins are cool stuff and we hardly eat kykeon nowadays, so let's talk about
plugins anyway.

If several plugins are activated and each one of them performs some behavior
redefinition on some entity, one has to pay extra attention to chained behavior
and inconsistency. It's good practice to always call `super` at some point within
the redefinitions, so as to traverse the whole redefinitions inheritance chain,
until the original definition is reached.

If you want to merely bypass the original behavior while being able to activate
multiple plugins, a nice way to do so is to write a SuperPlugin which does not
call `super` and will be the first activated plugin.

## Under the hood

*Pending*.

## Caveats

* It is not possible to deactivate a plugin at the present time, without bootstraping
  the receiver again. Hard work forthcoming.
* The TODO list is not empty.

## Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

## Copyright

Copyright (c) 2010 Jean-Denis Vauguet. See LICENSE for details.

