#!/usr/bin/lua5.3
--[[
  Full SSH Test case:
    -fork/exec using socket-pairs,
    -have a ctty/pts open, to mimick the case of ssh asking for a password.
  The ssh application *can* open /dev/tty. Before starting, ssh *closes* all file descriptors except 0,1,2 .
  So the slave PTY is not open yet!
]]
local cqueues=require"cqueues"
local cs=require"cqueues.socket"
local aux=require"cqueues.auxlib"
local signal=require"cqueues.signal"
local spawn=require"spawn"
local posix=require"posix"

cq=cqueues.new()
signal.ignore(signal.SIGTERM, signal.SIGHUP, signal.SIGINT)


local fd,pid=spawn.spawn(posix.exec,{},"./mock-ssh.lua",[[
sleep(2) for i = 1,10 do out("meeh",i,"\n") end exit(1)
]])
local function sockerror(socket, method, error,level)
print(method,error,level)
return "PIPE"
end
print(fd)
--cqueues.sleep(2)
local sock=aux.assert(cs.dup(fd))
sock:onerror(sockerror)
posix.close(fd)
print("poep")
for b in sock:lines() do
	print("X",b,"X")
end
print("Start some sleep in main")
cqueues.sleep(2)
print("End of main")
