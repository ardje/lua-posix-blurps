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
local signal=require"cqueues.signal"
local cq=cqueues.new()

local function cqhandle(fd,closeit)
	local cqfd=aux.assert(cs.dup(fd))
	if closeit then
		posix.close(fd)
	end
	return cqfd
end
--[[
	Handover stdin/err/out to cqueues
	They might as well be sockets, as 
]]
local stdin=cqhandle(0,true)
local stdout=cqhandle(1,false)
local stderr=cqhandle(2,false) -- Needed to trap errors

function askforpass()
	--[[
		Open straight channel to end user to enter password
	]]
	local fd,reason=aux.assert(posix.open ("/dev/tty", posix.O_RDWR))
	--[[
		turn off echo
	]]
	local termios,errmasg=assert(posix.tcgetattr(fd))
	local oflag=termios.lflag
	termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
	aux.assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	termios.lflag=oflag
	--[[
		Handover to cqueues
	]]
	local pty=cqhandle(fd)
	pty:write("I pretended trying to log in@now give me a's password: ")
	local pass=pty:read("*l")
	aux.assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	stderr:write("debug1: got pass ",pass,"\n")
	pty:close()
	stderr:write("debug1: closed stuff\n")
	--[[
		Restore echo settings
	]]
	assert(posix.tcsetattr(fd,posix.TCSANOW,termios))
	posix.close(fd)
	return pass
end

--askforpass()
local exitcode=0
function exit(n)
	exitcode=n)
end
function err(...)
	stderr:write(...)
end
function out(...)
	stdout:write(...)
end
sleep=cqueues.sleep
local function main(arg)
	--stderr:write("debug1: testing testing 1 2 3 in the place to be\n")
	-- Thinking... why can't I log in...
	--cqueues.sleep(1.400)
	--local p=askforpass()
	--stderr:write("I got that pass "..p.."\n")
	local performthis=assert(load(table.concat(arg," ")),nil,"t")
	performthis()
	return 1
end

cq:wrap(function () return main(arg) end)
cq:loop()
os.exit(exitcode)
