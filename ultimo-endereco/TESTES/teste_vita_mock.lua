-- Checks Lua code and the Vita compatibility adapter in desktop Lua.
-- It does not emulate Vita GPU/kernel. Passing does NOT verify hardware play.
local base=assert(arg[1], 'Informe caminho para APP_VITA')
local realDofile=dofile
function dofile(s)
 if s:sub(1,6)=='app0:/' then s=base..'/'..s:sub(7) end
 return realDofile(s)
end
for i,n in ipairs({'UP','DOWN','LEFT','RIGHT','CROSS','CIRCLE','SQUARE','TRIANGLE','LTRIGGER','RTRIGGER','START','SELECT'}) do _G['SCE_CTRL_'..n]=i end
FILTER_POINT=0
Color={new=function(r,g,b,a)return {r,g,b,a or 255} end}
local calls=0;local images={}
Graphics={}
function Graphics.loadImage(path)
 local file=assert(io.open(base..'/'..path:sub(7),'rb'),path)
 local data=file:read(24);file:close();assert(data:sub(2,4)=='PNG')
 local function read32(i)local a,b,c,d=data:byte(i,i+3);return a*16777216+b*65536+c*256+d end
 local id={w=read32(17),h=read32(21),path=path};images[#images+1]=id;return id
end
function Graphics.setImageFilters() end
function Graphics.freeImage(im)assert(not im.dead,'Double free');im.dead=true end
function Graphics.fillRect(x1,x2,y1,y2,c)assert(x1<=x2 and y1<=y2,'bad rectangle');calls=calls+1 end
function Graphics.drawPartialImage(x,y,img,sx,sy,w,h)
 assert(not img.dead,'freed image')
 assert(sx>=0 and sy>=0 and sx+w<=img.w and sy+h<=img.h, 'bad sprite rect '..img.path)
 calls=calls+1
end
function Graphics.drawImage(x,y,img)assert(not img.dead);calls=calls+1 end
function Graphics.debugPrint()calls=calls+1 end
function Graphics.initBlend()end
function Graphics.termBlend()end
function Graphics.initRescaler(x,y,sx,sy)assert(x==0 and y==0 and sx==2 and sy==2)end
function Graphics.termRescaler()end
Screen={clear=function()end,flip=function()end,waitVblankStart=function()end}
System={doesDirExist=function()return true end,createDirectory=function()end,exit=function()end}
Controls={read=function()return 0 end,check=function()return false end,readLeftAnalog=function()return 128,128 end}
local elapsed=0
Timer={new=function()return 0 end,getTime=function()elapsed=elapsed+16;return elapsed end}
Sound={init=function()end,term=function()end,open=function(f)assert(f:find('app0:/audio/',1,true));return 3 end,
 setVolume=function(_,v)assert(v<=32767)end,play=function()end,pause=function()end,close=function()end}
local saveDir='ux0:/data/ULTIMOEND'
os.execute('mkdir -p '..saveDir)
dofile('app0:/vita_compat.lua')
local G=dofile('app0:/game.lua')
G.init()
G.newGame();G.draw()
for i=1,54 do
 G.loadRoom(i,240,136,false);G.draw()
end
local types={}
for id,p in pairs(G.D.puzzles) do
 types[p.kind]=true
 G.loadRoom(p.room,240,136,false)
 G.p=p;G.q=G.L.initPuzzle(p);G.mode='puzzle';G.draw()
 G.input({left=true},{},0.016);G.draw()
 G.mode='world'
end
G.loadRoom(1,240,136,false)
for _,mode in ipairs({'world','journal','map','inventory','pause','title','dialog','choice','credits'}) do
 if mode=='dialog' then G.say({'Teste de dialogo.','Nova linha'},'Teste',nil,'world') end
 if mode=='choice' then G.ask('Teste',{'Um','Dois'},function()end,'world') end
 if mode=='journal' then G.journalTab=1;G.scroll=1 end
 if mode~='dialog' and mode~='choice' then G.mode=mode end
 G.draw()
end
local typeCount=0;for _ in pairs(types) do typeCount=typeCount+1 end
assert(typeCount==6,'not all puzzle types tested')
assert(calls>5000,'insufficient render calls')
print('VITA LUA MOCK PASS: 54 rooms, 36 puzzles, 9 menus/modes, '..calls..' render operations.')
