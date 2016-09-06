--local global=require"globals"
local M={}
local posix=require"posix"
local pss=require"posix.sys.socket"
local cs=require"cqueues.socket"

-- local fdnull=assert(posix.open("/dev/null",posix.O_RDWR,""))
function M.cloexec(fd,on)
  local oflags=posix.fcntl(fd,posix.F_GETFD)
  local CLO_EXEC=1
  if oflags then
    local flags
    if on then
      flags=oflags|CLO_EXEC
    else
      flags=oflags&(~CLO_EXEC)
    end
  local r=posix.fcntl(fd,posix.F_SETFD,flags)
end


function M.spawn(this,fdlist,...)
	local master,reason=assert(posix.openpt(bit32.bor(posix.O_RDWR,posix.O_NOCTTY)))
	fdlist=fdlist or {}
	local ok,reason=assert(posix.grantpt(master))
	local ok,reason=assert(posix.unlockpt(master))
	local slave_name,reason=assert(posix.ptsname(master))
	print("about to fork",...)
	local pid,reason=assert(posix.fork())
	local slave2=1
--	pss.setsockopt( master,pss.SOL_SOCKET,pss.SO_NOSIGPIPE)
	--local slave2, reason = assert(posix.open (slave_name,bit32.bor(posix.O_RDWR,posix.O_NOCTTY)))
	if pid==0 then
		posix.close(master)
		local session=posix.setpid('s') -- setsid()...
		local slave, reason = assert(posix.open (slave_name,posix.O_RDWR))
		local termios,errmasg=assert(posix.tcgetattr(slave))
		termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
		assert(posix.tcsetattr(slave,posix.TCSANOW,termios))
		print("dupping")
		fdlist[0]=fdlist[0] or slave
		fdlist[1]=fdlist[1] or slave
		fdlist[2]=fdlist[2] or slave
		for fd,dup in pairs(fdlist) do
			posix.dup2(dup,fd)
		end
		for i = 3,1023 do
			posix.close(i)
		end
		--print("session:",session,posix.ctermid())
		print(...)
		local r=this(...)
		print("failed")
		posix.close(0)
		posix.close(1)
		posix.close(2)
		posix._exit(r)
	end
	--posix.close(slave)
	print("after fork")
	--posix.fcntl(master,posix.F_SETFL,posix.O_NONBLOCK)
	return master,slave2,pid
end

return M
