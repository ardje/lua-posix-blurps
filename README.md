# lua-posix-blurps
My adventures with lua-posix

# Controlling tty's / pts tests /examples
Some trials on how to use pts and controlling tty's with lua-posix instead of
lpty.  I have a preference for lua-posix because it is easier to integrate into
a bigger coproc based multithreading engine (which I already had).

# Simple pts open, in/out
First simple test is test-openpt-bc.lua. Simple: open a pty, and use that as
stdinouterr.

# Complex pts open, controlling tty
Second difficult test is test-openpt-ssh.lua : it requires 2 arguments: a
user/host and a password.  It forks, setsids, opens the slave pts as a ctty

You have to understand that ssh doesn't care about stdin/out/err. It does care
about the *controlling tty*. Ssh tries to use a key, if it can't it will *open*
/dev/tty and print out the password question, waiting for an answer.

/dev/tty is by definition the controlling tty of the current session.
It actually is very hard to get /dev/tty to point to your created pts.

# "Super" Complex pts open, controlling tty
The third troublesome test is test-openpt-ssh-pipe.lua: it requires the same to
arguments. The essence is that we split the filedescriptors into a read-pipe
and a write-pipe for stdin/out/err, but we have a seperate filedescriptor for
/dev/tty .
The first thing ssh does, is close every filedescriptor except 0, 1 and 2.
If you opened the slave pts in the same process that was going to execve ssh,
it will be closed, and your pts will be gone.
In this example it is opened in the master to prevent it from being closed by
ssh, and hence loosing /dev/tty.

pipes are used because posix.socketpair was not implemented in 31.x , which is
the version in debian/jessie.
