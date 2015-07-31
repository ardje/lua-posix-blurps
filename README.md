# lua-posix-blurps
My adventures with lua-posix

# Controlling tty's / pts tests /examples
Some trials on how to use controlling tty's with lua-posix instead of lpty.
Preference for lua-posix is that it is easier to integrate into a bigger coproc based multithreading engine.

First simple test is test-openpt-bc.lua. Simple: open a pty, and use that as stdinouterr.
Second difficult test is test-openpt-ssh.lua : it requires 2 arguments: a user/host and a password.
It forks, setsids, opens the slave pts as a ctty
You have to understand that ssh doesn't care about stdin/out/err. It does care about the *controlling tty*. It will ask the password by *opening* /dev/tty, which by definition is the controlling tty of the current session.
