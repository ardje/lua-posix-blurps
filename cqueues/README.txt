moch-ssh.lua : ssh "emulation"

mock-ssh.lua expects lua code as argument.
It is intended to behave a bit like ssh, with waits and opening /dev/tty for password.
If you don't give an argument it will default to this:

err("debug1: testing testing 1 2 3 in the place to be\n")
-- Thinking... why can't I log in...
sleep(1.400)
local p=askforpass()
err("I got that pass "..p.."\n")
out("Ocassionally I say somethin on stdout\n")
sleep(2.400)
out("after long thinking I decided to stop with exit 2\n")
exit(2)

askforpass opens /dev/tty, prompts a question and closes it again.
out sends something to stdout and flushes it.
err sends something to stderr (autoflush)
sleep uses cqueues.sleep.
