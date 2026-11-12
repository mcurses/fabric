package.path=arg[1]..'/?.lua;'..package.path
local T=require('bounded-trace');local s={trace={}}
for i=1,100000 do T.push(s,'trace',i,8192,'dropped')end
assert(#s.trace<=8192 and #s.trace>=7169)
assert(s.dropped+#s.trace==100000 and s.trace[#s.trace]==100000)
for i=2,#s.trace do assert(s.trace[i]==s.trace[i-1]+1)end
print('PASS 100000 trace events: bounded, ordered, exact dropped count')
