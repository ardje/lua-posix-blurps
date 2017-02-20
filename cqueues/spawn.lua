--local global=require"globals"
local M={}
local posix=require"posix"
--local pss=require"posix.sys.socket"
--local cs=require"cqueues.socket"

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
end


function M.spawn(this,fdlist,...)
	fdlist=fdlist or {}
	local master=assert(posix.openpt(bit32.bor(posix.O_RDWR,posix.O_NOCTTY)))
	assert(posix.grantpt(master))
	assert(posix.unlockpt(master))
	local pid,reason=assert(posix.fork())
	if pid==0 then
		local slave_name=assert(posix.ptsname(master))
		posix.close(master)
		local session=posix.setpid('s') -- setsid()...
		--[[
			We have to open the slave tty now at least once to make it our CTTY.
		]]
		slave = assert(posix.open (slave_name,posix.O_RDWR))
		local termios,errmsg=assert(posix.tcgetattr(slave))
		termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
		assert(posix.tcsetattr(slave,posix.TCSANOW,termios))
		fdlist[0]=fdlist[0] or slave
		fdlist[1]=fdlist[1] or slave
		fdlist[2]=fdlist[2] or slave
		for fd,dup in pairs(fdlist) do
			posix.dup2(dup,fd)
		end
		for fdk,fdv in pairs(fdlist) do
			if fdlist[fdv] == nil then
				print("closing:",fdv)
				posix.close(fdv)
			end	
		end
		for i = 0,1023 do
			if fdlist[i] == nil then
				local r=posix.close(i)
				if r == 0 then
					print("filedescriptor was open:",i)
				end
			end
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
	return master,pid
end

return M
