#!/usr/bin/lua5.3
--[[
  SSH mock:
    - close all file descriptors, except 0, 1 and 2
    - provide means to control mock

  SSH test:
    - read something from 0
    - write something to 1
    - write something to 2
    - open /dev/tty (if that fails -> no CTTY!)
    - write "Password: " to /dev/tty
    - wait for input on /dev/tty
    - close /dev/tty
    - write some more stuff to 1
--]]
local posix=require"posix"
local function closeall()
	for i=3,1023 do posix.close(i) end
end
--[[
  cqueues seems to open internal handles, which we should not close.
  So close all necessary descriptors before loading cqueues.
]]
closeall()

local cqueues=require"cqueues"
local cs=require"cqueues.socket"
--[[
  We use cs.dup() to handover control of our descriptors to get a cqueues compliant object.
  I whish there was a thing like cs.assimilate( ) ;-) .
]]
local aux=require"cqueues.auxlib"
local cq=cqueues.new()

--[[
	Handover stdin/err/out to cqueues
	They might as well be sockets, as
]]
local stdin=cs.fdopen(0)
local stdout=cs.fdopen(1)
local stderr=cs.fdopen(2)

function askforpass()
	--[[
		Open straight channel to end user to enter password
	]]
	local fd,reason=aux.assert(posix.open ("/dev/tty", posix.O_RDWR))
	local pty=aux.assert(cs.fdopen(fd))
	--[[
		turn off echo
	]]
	local termios,errmasg=aux.assert(posix.tcgetattr(fd))
	local oflag=termios.lflag
	termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
	aux.assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	termios.lflag=oflag
	--[[
		Handover to cqueues
	]]
	pty:write("I pretended trying to log in@now give me a's password: ")
	pty:flush()
	--aux.assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	local pass=pty:read("*l")
	stderr:write("debug1: got pass ",pass,"\n")
	--[[
		Restore echo settings
	]]
	aux.assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	pty:close()
	--posix.close(fd)
	stderr:write("debug1: closed stuff\n")
	return pass
end

--askforpass()
local exitcode=0
function exit(n)
	exitcode=n
end
function err(...)
	stderr:write(...)
end
function input(...)
	stdin:read(...)
end
function out(...)
	stdout:write(...)
	stdout:flush()
end
function sleep(...)
	cqueues.sleep(...)
end
local function main(arg)
	local noargs={[[
		err("debug1: testing testing 1 2 3 in the place to be\n")
		-- Thinking... why can't I log in...
		sleep(1.400)
		local p=askforpass()
		err("I got that pass "..p.."\n")
		out("Ocassionally I say somethin on stdout\n")
		sleep(2.400)
		out("after long thinking I decided to stop with exit 2\n")
		exit(2)
	]] }
	print("performing :",(table.concat(#arg == 0 and noargs or arg," ")))
	local performthis=assert(load(table.concat(#arg == 0 and noargs or arg," ")),nil,"t")
	performthis()
	return
end

cq:wrap(function () return main(arg) end)
aux.assert(cq:loop())
os.exit(exitcode)
