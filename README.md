# Qimpy

Qimpy is a fun, personal Ruby project that wraps the QMP protocol--particularly the parts used by
the QEMU Guest Agent--made available by QEMU. This protocol is used to allow the host to commuicate
with any guest virtual instances through a Unix Domain Socket using simple, JSON-based messages.

You can find an [intro here](https://github.com/qemu/qemu/blob/master/docs/qmp-intro.txt), and
[specification details here](https://github.com/qemu/qemu/blob/master/docs/qmp-spec.txt). However,
in its current state, Qimpy only implements wrappers for the parts of QMP related to communicating
with the guest agent.

## Qimpy & The QEMU Guest Agent

Although Qimpy will likely evolve into a full-blown Ruby gem supporting as many QEMU features as
possible, its initial functionality revolves around wrapping the *"guest-"* series of commands
provided by QMP. These include things like read and writing files, changing the number of virtual
CPUs, power management, etc.
