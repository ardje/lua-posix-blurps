local global=require"process.globals"
local posix=require"posix"

local function spawn(this,...)
	local master,reason=assert(posix.openpt(posix.O_RDWR))
	local ok,reason=assert(posix.grantpt(master))
	local ok,reason=assert(posix.unlockpt(master))
	local slave_name,reason=assert(posix.ptsname(master))
	local pid,reason=assert(posix.fork())
	if pid==0 then
		local slave, reason = assert(posix.open (slave_name,posix.O_RDWR))
		posix.close(master)
		local termios,errmasg=assert(posix.tcgetattr(slave))
		termios.lflag=bit32.band(termios.lflag,bit32.bnot(posix.ECHO))
		assert(posix.tcsetattr(slave,posix.TCSANOW,termios))
		posix.dup2(slave,0)
		posix.dup2(slave,1)
		posix.dup2(slave,2)
		for i = 3,1023 do
			posix.close(i)
		end
		local r=this(...)
		posix.close(0)
		posix.close(1)
		posix.close(2)
		posix._exit(r)
	end
	posix.fcntl(master,posix.F_SETFL,posix.O_NONBLOCK)
	return master,pid
end

local function testfunction()
	os.execute"bc"
	return 0
end

local master,pid=spawn(testfunction)	
local fds={
	[master]= { events={IN=true} , outfd=1},
	[0]= { events={IN=true}, outfd=master },
}
while true do
	posix.poll(fds,1)
	for fd in pairs(fds) do
		if fds[fd].revents and fds[fd].revents.IN then
			local b=posix.read(fd,1024)
			-- print("got",b)
			posix.write(fds[fd].outfd,b or "")
			fds[fd].revents.IN=nil
		end
		if fds[fd].revents and fds[fd].revents.HUP then
			return
		end
	end
end
