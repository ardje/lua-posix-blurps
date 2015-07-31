local global=require"process.globals"
local posix=require"posix"

-- local fdnull=assert(posix.open("/dev/null",posix.O_RDWR,""))

local function spawn(this,fdlist,...)
	local master,reason=assert(posix.openpt(bit32.bor(posix.O_RDWR,posix.O_NOCTTY)))
	fdlist=fdlist or {}
	local ok,reason=assert(posix.grantpt(master))
	local ok,reason=assert(posix.unlockpt(master))
	local slave_name,reason=assert(posix.ptsname(master))
	local pid,reason=assert(posix.fork())
	local slave2, reason = assert(posix.open (slave_name,bit32.bor(posix.O_RDWR,posix.O_NOCTTY)))
	if pid==0 then
		posix.close(master)
		local session=posix.setpid('s') -- setsid()...
		local slave, reason = assert(posix.open (slave_name,posix.O_RDWR))
		local termios,errmasg=assert(posix.tcgetattr(slave))
		termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
		assert(posix.tcsetattr(slave,posix.TCSANOW,termios))
		fdlist[0]=fdlist[0] or slave
		fdlist[1]=fdlist[1] or slave
		fdlist[2]=fdlist[2] or slave
		for fd,dup in pairs(fdlist) do
			posix.dup2(dup,fd)
		end
		--for i = 3,1023 do
			--posix.close(i)
		--end
		print("session:",session,posix.ctermid())
		local r=this(...)
		posix.close(0)
		posix.close(1)
		posix.close(2)
		posix._exit(r)
	end
	--posix.close(slave)
	posix.fcntl(master,posix.F_SETFL,posix.O_NONBLOCK)
	return master,pid
end

local function testfunction(destination)
	--posix.exec("/usr/bin/ssh",destination,"ip","a","ls")
	posix.exec("/usr/bin/ssh",destination)
	return 0
end

local fdfrom_child, fdto_parent=posix.pipe()
local fdfrom_parent,fdto_child=posix.pipe()
posix.fcntl(fdfrom_child,posix.F_SETFL,posix.O_NONBLOCK)
posix.fcntl(fdto_child,posix.F_SETFL,posix.O_NONBLOCK)
local master,pid=spawn(testfunction,{ [0]=fdfrom_parent,[1]=fdto_parent,[2]=fdto_parent},arg[1])	
local fds={
	[fdfrom_child]={events={IN=true},outfd=1},
	[master]= { events={IN=true} , outfd=1},
	[0]= { events={IN=true}, outfd=fdto_child },
}
local loggedin=false
while true do
	assert(posix.poll(fds,-1))
	for fd,v in pairs(fds) do
		if v.revents and v.revents.IN then
			local b=posix.read(fd,1024)
			if not loggedin  and fd == master and b:match("assword:") then
				posix.write(fd,arg[2].."\n")	
				print("wrote password\n")
			end
			if v.outfd ==1 then
				print("got",fd,b)
			else
				posix.write(v.outfd,b or "")
			end
			v.revents.IN=nil
		end
		if v.revents and v.revents.HUP then
			print("Got HUP on ",fd)
			if fd == master then
				print("ignored master")
				posix.close(fd)
				fds[fd]=nil
				v.revents.HUP=nil
			else
				return
			end
		end
	end
end
