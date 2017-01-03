#!/usr/bin/lua5.3
-- vim: set ts=2 sw=2 ai tw=0 expandtab:syntax on:
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
local psw=require"posix.sys.wait"
local posix=require"posix"
local errno=require"cqueues.errno"

local cq=cqueues.new()
signal.ignore(signal.SIGTERM, signal.SIGHUP, signal.SIGINT)
local sl=signal.listen(signal.SIGCHLD)
local pid_status={}
signal.block(signal.SIGCHLD)
local exit_status
cq:wrap(function()
  local signo
  while true do
    signo = sl:wait(5)
    print("\nGot signal",signo and signal[signo] or "NONE")
    if signo == nil then
      return
    elseif signo == signal.SIGINT then
      os.exit(true)
    elseif signo == signal.SIGCHLD then
      local pid,status,exit=posix.wait(-1,psw.WNOHANG)
      pid_status[pid]={pid=pid,status=status,exit=exit,running=false}
      while pid ~= 0 and pid ~= nil do
        print("Child exit:",pid,status,exit)
        pid,status,exit=posix.wait(-1,psw.WNOHANG)
      end
    end
  end
end)

local function sockerror(socket, method, error,level)
  print("PIPE ERROR: (good)",method,errno.strerror(error),level)
  return "PIPE"
end

local function test1()
  local fd,pid=spawn.spawn(posix.exec,{},"./mock-ssh.lua",
    [[sleep(2) for i = 1,10 do out("meeh",i,"\n") sleep(0.1) end exit(1)]])
  pid_status[pid]={running=true}
--print(fd)
--cqueues.sleep(2)
  local sock=aux.assert(cs.fdopen(fd))
  sock:onerror(sockerror)
--posix.close(fd)
  print("start test")
  for b in sock:lines() do
    print(b)
  end
  print("Start some sleep in main")
  cqueues.sleep(2)
  print("End of test1")
  if pid_status[pid] == nil or pid_status[pid].exit ~= 1 then
    print("test 1 failed:",pid_status[pid].exit)
    return 1
  else
    print("test 1 successful")
    return nil
  end
end
cq:wrap(function()
  exit_status=test1()
  if exit_status ~= nil then return end
end)
aux.assert(cq:loop())
os.exit(exitcode)
