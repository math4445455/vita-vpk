-- O Ultimo Endereco. Pure Lua 5.1 game rules; no platform dependencies.
local L = {}
function L.copy(t)
 if type(t)~='table' then return t end
 local o={} for k,v in pairs(t) do o[k]=L.copy(v) end return o
end
function L.new()
 return {version=1,seq=0,room=1,x=240,y=136,dir=1,seconds=0,music=1,
 flags={},items={},notes={},visited={},puzzles={},hints={},memories={},endings={}}
end
function L.count(t) local n=0 for _,v in pairs(t) do if v then n=n+1 end end return n end
function L.meets(s,requirements)
 for _,k in ipairs(requirements or {}) do if not s.flags[k] then return false,k end end return true
end
function L.reward(s,p)
 s.flags[p.id]=true
 if p.reward then s.items[p.reward]=true end
end
function L.combine(s,a,b,recipes)
 if not a or not b or a==b or not s.items[a] or not s.items[b] then return nil end
 for _,r in ipairs(recipes) do
  if (r.a==a and r.b==b) or (r.a==b and r.b==a) then
   s.items[a]=nil;s.items[b]=nil;s.items[r.out]=true;return r.out
  end
 end
end
local dirs={{0,-1},{1,0},{0,1},{-1,0}}
function L.initPuzzle(p)
 local q={cursor=1,moves=0}
 if p.kind=='code' then q.cells={} for i=1,#p.answer do q.cells[i]=0 end
 elseif p.kind=='order' then q.cells=L.copy(p.initial)
 elseif p.kind=='sequence' then q.cells={}
 elseif p.kind=='lights' then q.cells=L.copy(p.initial)
 elseif p.kind=='pipes' then q.cells=L.copy(p.initial)
 elseif p.kind=='crates' then
  q.boxes=L.copy(p.boxes);q.player=p.player;q.undo={}
 end return q
end
function L.toggle(c,i,n)
 local x=(i-1)%n;local y=math.floor((i-1)/n)
 for _,d in ipairs({{0,0},{1,0},{-1,0},{0,1},{0,-1}}) do
  local nx=x+d[1];local ny=y+d[2]
  if nx>=0 and nx<n and ny>=0 and ny<n then local j=ny*n+nx+1;c[j]=1-c[j] end
 end
end
local function has(t,v) for i,n in ipairs(t) do if n==v then return i end end end
L.has=has
function L.pipeSides(mask,rot)
 local out={}
 for i=1,4 do if math.floor(mask/2^(i-1))%2==1 then out[(i-1+rot)%4+1]=true end end
 return out
end
function L.pipeReach(p,q)
 local reached={};local queue={p.source};local sides={}
 for i,m in ipairs(p.shapes) do sides[i]=L.pipeSides(m,q.cells[i]) end
 if not sides[p.source][4] then return reached end
 reached[p.source]=true;local pos=1
 while queue[pos] do
  local i=queue[pos];pos=pos+1;local x=(i-1)%p.n;local y=math.floor((i-1)/p.n)
  for d,v in pairs(sides[i]) do
   local nx=x+dirs[d][1];local ny=y+dirs[d][2];local j=ny*p.n+nx+1
   if nx>=0 and nx<p.n and ny>=0 and ny<p.n and sides[j][(d+1)%4+1] and not reached[j] then reached[j]=true;queue[#queue+1]=j end
  end
 end return reached
end
function L.solved(p,q)
 if p.kind=='lights' then for _,v in ipairs(q.cells) do if v~=1 then return false end end return true
 elseif p.kind=='crates' then for _,v in ipairs(p.targets) do if not has(q.boxes,v) then return false end end return true
 elseif p.kind=='pipes' then local r=L.pipeReach(p,q);return r[p.sink] and L.pipeSides(p.shapes[p.sink],q.cells[p.sink])[2] or false
 else
  if #q.cells~=#p.answer then return false end
  for i,v in ipairs(p.answer) do if q.cells[i]~=v then return false end end return true
 end
end
function L.moveCrate(p,q,d)
 local n=p.n;local x=(q.player-1)%n;local y=math.floor((q.player-1)/n)
 local nx=x+dirs[d][1];local ny=y+dirs[d][2];local j=ny*n+nx+1
 if nx<0 or nx>=n or ny<0 or ny>=n or p.walls[j]==1 then return false end
 local bi=has(q.boxes,j)
 if bi then
  local bx=nx+dirs[d][1];local by=ny+dirs[d][2];local b=by*n+bx+1
  if bx<0 or bx>=n or by<0 or by>=n or p.walls[b]==1 or has(q.boxes,b) then return false end
 end
 q.undo[#q.undo+1]={player=q.player,boxes=L.copy(q.boxes)}
 if #q.undo>100 then table.remove(q.undo,1) end
 if bi then q.boxes[bi]=(ny+dirs[d][2])*n+nx+dirs[d][1]+1 end
 q.player=j;q.moves=q.moves+1;return true
end
function L.undo(q)
 local u=table.remove(q.undo or {});if u then q.player=u.player;q.boxes=u.boxes end
end
function L.puzzleInput(p,q,k)
 local n=p.n or #q.cells
 if p.kind=='crates' then
  local ds={up=1,right=2,down=3,left=4}
  if ds[k] then L.moveCrate(p,q,ds[k]) elseif k=='square' then L.undo(q) end
 elseif p.kind=='code' then
  if k=='left' then q.cursor=(q.cursor-2)%#q.cells+1
  elseif k=='right' then q.cursor=q.cursor%#q.cells+1
  elseif k=='up' then q.cells[q.cursor]=(q.cells[q.cursor]+1)%10
  elseif k=='down' then q.cells[q.cursor]=(q.cells[q.cursor]+9)%10 end
 elseif p.kind=='order' then
  if k=='left' then q.cursor=math.max(1,q.cursor-1) elseif k=='right' then q.cursor=math.min(#q.cells,q.cursor+1)
  elseif k=='cross' then
   if q.held then q.cells[q.cursor],q.cells[q.held]=q.cells[q.held],q.cells[q.cursor];q.held=nil;q.moves=q.moves+1 else q.held=q.cursor end
  end
 elseif p.kind=='sequence' then
  if k=='left' then q.cursor=(q.cursor-2)%#p.labels+1 elseif k=='right' then q.cursor=q.cursor%#p.labels+1
  elseif k=='cross' and #q.cells<#p.answer then q.cells[#q.cells+1]=q.cursor
  elseif k=='square' then table.remove(q.cells) end
 else
  local x=(q.cursor-1)%n;local y=math.floor((q.cursor-1)/n)
  if k=='left' then x=(x+n-1)%n elseif k=='right' then x=(x+1)%n
  elseif k=='up' then y=(y+n-1)%n elseif k=='down' then y=(y+1)%n
  elseif k=='cross' then
   if p.kind=='lights' then L.toggle(q.cells,q.cursor,n) else q.cells[q.cursor]=(q.cells[q.cursor]+1)%4 end
   q.moves=q.moves+1
  end
  q.cursor=y*n+x+1
 end
end
-- Bounded data-only serializer. A save is never executed as Lua code.
local function pack(x)
 local t=type(x)
 if t=='number' then return 'n'..tostring(math.floor(x))..';'
 elseif t=='boolean' then return x and 't' or 'f'
 elseif t=='string' then return 's'..#x..':'..x
 elseif t=='table' then
  local keys={} for k in pairs(x) do keys[#keys+1]=k end
  table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
  local o={'{' } for _,k in ipairs(keys) do o[#o+1]=pack(k);o[#o+1]=pack(x[k]) end
  o[#o+1]='}';return table.concat(o)
 end error('unsupported save value')
end
L.pack=pack
function L.unpack(s)
 if #s>200000 then return nil end
 local i=1;local count=0
 local function read(depth)
  count=count+1;if depth>16 or count>25000 then error('save limit') end
  local t=s:sub(i,i);i=i+1
  if t=='n' then local e=s:find(';',i,true);assert(e);local v=tonumber(s:sub(i,e-1));assert(v and v==v and math.abs(v)<1e12);i=e+1;return v
  elseif t=='s' then local e=s:find(':',i,true);assert(e);local n=tonumber(s:sub(i,e-1));assert(n and n>=0 and n<50000 and e+n<=#s);i=e+n+1;return s:sub(e+1,e+n)
  elseif t=='t' then return true elseif t=='f' then return false
  elseif t=='{' then local o={} while s:sub(i,i)~='}' do assert(i<=#s);local k=read(depth+1);assert(type(k)=='number' or type(k)=='string');o[k]=read(depth+1) end i=i+1;return o
  else error('invalid save') end
 end
 local ok,v=pcall(read,0);if ok and i==#s+1 then return v end
end
function L.checksum(s) local c=17 for i=1,#s do c=(c*31+s:byte(i))%65521 end return c end
function L.decode(s)
 if not s then return nil end
 local a,b,body=s:match('^ENDERECO1\n(%d+)\n(%d+)\n(.*)$')
 if not body or tonumber(a)~=#body or tonumber(b)~=L.checksum(body) then return nil end
 local v=L.unpack(body)
 if type(v)~='table' or v.version~=1 or type(v.room)~='number' or v.room<1 or v.room>54 then return nil end
 for _,k in ipairs({'flags','items','notes','visited','puzzles','hints','memories','endings'}) do if type(v[k])~='table' then return nil end end
 if type(v.seq)~='number' or type(v.seconds)~='number' or type(v.x)~='number' or type(v.y)~='number' then return nil end
 v.x=math.max(16,math.min(464,v.x));v.y=math.max(16,math.min(208,v.y))
 return v
end
function L.encode(s) local body=pack(s);return 'ENDERECO1\n'..#body..'\n'..L.checksum(body)..'\n'..body end
function L.load(prefix)
 local best=nil
 for _,n in ipairs({'a','b'}) do
  local f=io.open(prefix..n..'.sav','rb');if f then local v=L.decode(f:read('*a'));f:close();if v and (not best or v.seq>best.seq) then best=v end end
 end return best
end
function L.save(s,prefix)
 local old=s.seq;s.seq=old+1
 local path=prefix..(s.seq%2==0 and 'a' or 'b')..'.sav'
 local data=L.encode(s);local f,err=io.open(path,'wb')
 if not f then s.seq=old;return false,err end
 local ok=f:write(data);local closed=f:close()
 if not ok or not closed then s.seq=old;return false,'falha de escrita' end
 local check=io.open(path,'rb');local v=check and check:read('*a');if check then check:close() end
 if not L.decode(v) then s.seq=old;return false,'verificação falhou' end
 return true
end
return L
