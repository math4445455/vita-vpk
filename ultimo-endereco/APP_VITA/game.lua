-- O Ultimo Endereco / PlayStation Vita / Lua Player Plus Vita
-- Adapted via vita_compat.lua; original game rules and content preserved.
local L=dofile('app0:/logic.lua')
local D=dofile('app0:/data/content.lua')
local SAVE_PREFIX='ux0:/data/ULTIMOEND/progresso_'
local G={L=L,D=D,mode='title',S=L.load(SAVE_PREFIX) or L.new(),selected=nil,
 timer=0,frame=0,titleCursor=1,cursor=1,scroll=1,toast='',toastTime=0,saveTime=0,
 musicChapter=0,musicReady=false,dialog=nil,choice=nil,playing=false,walk=0}
local COL={}
local fonts,assets={},{}
local old={} -- independent key state; no userdata equality assumptions
local normalized={}
local function latin(s)
 if normalized[s] then return normalized[s] end
 local q=s:gsub('—','-'):gsub('–','-'):gsub('…','...'):gsub('“','"'):gsub('”','"'):gsub('’',"'")
 q=q:gsub('[\194-\244][\128-\191]+',function(c)
  local a,b=c:byte(1,2);local n=(a-192)*64+b-128
  return #c==2 and n>=0 and n<=255 and string.char(n) or '?'
 end)
 normalized[s]=q;return q
end
local function wrap(s,width)
 s=latin(s);local lines={};local line=''
 for word in s:gmatch('%S+') do
  if #line>0 and #line+#word+1>width then lines[#lines+1]=line;line='' end
  while #word>width do
   if #line>0 then lines[#lines+1]=line;line='' end
   lines[#lines+1]=word:sub(1,width);word=word:sub(width+1)
  end
  line=line=='' and word or line..' '..word
 end
 if #line>0 then lines[#lines+1]=line end
 return lines
end
local function raw(x,y,s,color)
 local img=fonts[color or 'cream']
 for i=1,#s do
  local c=s:byte(i)
  if c~=32 and x+(i-1)*8<476 then
   screen:blit(math.floor(x+(i-1)*8),math.floor(y),img,255,(c%16)*8,math.floor(c/16)*14,8,14)
  end
 end
end
local function text(x,y,s,color) raw(x,y,latin(tostring(s)),color) end
local function rect(x,y,w,h,c) screen:fillRect(math.floor(x),math.floor(y),math.floor(w),math.floor(h),COL[c]) end
local function box(x,y,w,h)
 rect(x,y,w,h,'border');rect(x+1,y+1,w-2,h-2,'panel')
 rect(x+6,y+5,2,2,'gold');rect(x+w-8,y+5,2,2,'gold')
end
local function sprite(img,id,x,y)
 if img==assets.lia then
  -- Lia: 48x48 kemonomimi human with fox ears/tail, feet-anchored on the map.
  screen:blit(math.floor(x-24),math.floor(y-44),img,255,(id%12)*48,math.floor(id/12)*48,48,48)
 else
  screen:blit(math.floor(x-16),math.floor(y-28),img,255,(id%16)*32,math.floor(id/16)*32,32,32)
 end
end
function G.message(t) G.toast=t;G.toastTime=3 end
function G.save()
 local ok,err=L.save(G.S,SAVE_PREFIX);G.saveTime=0
 G.message(ok and 'Progresso salvo.' or 'Falha ao salvar: confira o espaço livre.')
 return ok,err
end
function G.say(paragraphs,title,after,returnMode)
 local pages={}
 for _,p in ipairs(paragraphs) do
  local ls=wrap(p,52)
  for i=1,#ls,5 do
   local a={} for j=i,math.min(i+4,#ls) do a[#a+1]=ls[j] end
   pages[#pages+1]=a
  end
 end
 G.dialog={pages=pages,index=1,title=title or 'Lia e Nimbo',after=after,back=returnMode or G.mode}
 G.mode='dialog'
end
function G.story(id,title,after,returnMode) G.say(D.stories[id] or {'...'},title,after,returnMode) end
function G.ask(title,options,callback,back)
 G.choice={title=title,options=options,callback=callback,back=back or 'world'};G.cursor=1;G.mode='choice'
end
-- One distinct, seamless-looped ambient composition for every one of the six areas.
local TRACK_NAMES={'Cartas Sob a Chuva','Sinos de Sal','Jardim de Orvalho',
 'Papel e Maré','Luzes nas Janelas','O Nome que Resta'}
function G.music()
 local c=D.rooms[G.S.room].chapter
 if G.musicChapter==c and G.musicReady then return end
 if G.musicReady then pcall(Ogg.stop,0);pcall(Ogg.unload,0);G.musicReady=false end
 G.musicChapter=c
 if G.S.music==0 then return end
 local ok,err=pcall(function()
  Ogg.load('audio/distrito'..c..'.ogg',0)
  Ogg.volume(0.47,0)
  Ogg.play(true,0)
 end)
 G.musicReady=ok
 if not ok then G.musicError=tostring(err) else G.musicError=nil end
end
function G.loadRoom(id,x,y,narrate)
 G.S.room=id;G.S.x=x or 240;G.S.y=y or 136
 local r=D.rooms[id];G.room=r;G.S.visited[id]=true
 if assets.room then Image.free(assets.room);assets.room=nil end
 collectgarbage('collect');assets.room=Image.load(string.format('assets/rooms/%02d.png',id))
 G.music();G.mode='world';G.playing=true;G.save()
 local key='arrival'..r.chapter
 if narrate and not G.S.flags[key] then
  G.S.flags[key]=true
  G.story(key,D.chapters[r.chapter].name,function() G.save() end,'world')
 end
end
function G.newGame()
 local seq=G.S.seq;G.S=L.new();G.S.seq=seq;G.selected=nil;G.playing=true
 G.loadRoom(1,240,136,false)
 G.story('intro','O Último Endereço',function() G.S.flags.arrival1=true;G.save() end,'world')
end
function G.currentTask()
 local ch=D.rooms[G.S.room].chapter
 for n=(ch-1)*6+1,ch*6 do
  local p=D.puzzles[string.format('p%02d',n)]
  if not G.S.flags[p.id] then return p end
 end
 return nil
end
function G.nearest()
 local best,dist=nil,34*34
 for _,o in ipairs(G.room.objects) do
  local d=(o.x-G.S.x)^2+(o.y-G.S.y)^2
  if d<dist then best=o;dist=d end
 end
 return best
end
function G.finalChoice()
 if not G.S.flags.p36 then G.say({'O último painel ainda está fechado. Complete a Última autorização nesta sala.'},'O último endereço',nil,'world');return end
 local opts={'Manter as referências por enquanto','Abrir a rota de evacuação',L.count(G.S.memories)>=6 and 'Compartilhar os endereços' or 'Compartilhar: faltam testemunhos','Ainda não escolher'}
 G.ask('Que futuro você oferece à cidade?',opts,function(i)
  if i==4 then G.mode='world';return end
  if i==3 and L.count(G.S.memories)<6 then
   G.say({'A rota coletiva depende dos seis testemunhos voluntários. Procure as cartas na casa de cada distrito, escolha com cuidado e volte. START > Viajar entre bancos leva aos distritos que você já visitou. Nada será perdido por esperar.'},'Seis pessoas, seis escolhas',nil,'world');return
  end
  local key=({'ending_keep','ending_leave','ending_share'})[i]
  G.ask('Confirmar esta decisão?',{'Sim, quero seguir esta rota','Voltar e pensar mais'},function(j)
   if j==2 then G.mode='world';return end
   G.S.endings[key]=true;G.save()
   G.story(key,'O Último Endereço',function()
    G.mode='credits';G.scroll=1
   end,'world')
  end,'world')
 end,'world')
end
function G.interact(o)
 if not o then G.message('Chegue perto de uma pessoa ou objeto.');return end
 if o.type=='puzzle' then
  local p=D.puzzles[o.puzzle]
  if G.S.flags[p.id] then G.say({'Este mecanismo já está funcionando. A pista continua guardada no diário.'},p.name,nil,'world');return end
  local ready,missing=L.meets(G.S,p.requires)
  if not ready then G.say({'Este mecanismo depende de '..D.puzzles[missing].name..'. Procure em '..D.rooms[D.puzzles[missing].room].name..'. O mapa mostra as salas que você já visitou.'},p.name,nil,'world');return end
  if p.item and G.selected~=p.item then
   local a,b
   for _,recipe in ipairs(D.recipes) do if recipe.out==p.item then a=recipe.a;b=recipe.b end end
   G.say({'Para usar este mecanismo, equipe '..D.items[p.item].name..'. Abra a bolsa com Triângulo. Combine '..D.items[a].name..' e '..D.items[b].name..' com Quadrado; depois equipe o resultado com X e examine o aparelho.'},p.name,nil,'world');return
  end
  G.p=p;G.q=G.S.puzzles[p.id] or L.initPuzzle(p);G.S.puzzles[p.id]=G.q
  G.mode='puzzle'
  if not G.S.flags['tutorial_'..p.kind] then
   G.S.flags['tutorial_'..p.kind]=true
   local tutorial={code='Esquerda e direita escolhem o dígito. Cima e baixo alteram o número. Triângulo testa a resposta. R mostra dicas graduais, L reinicia, O volta sem perder a tentativa.',pipes='Mova o cursor com o direcional. X gira o tubo selecionado. Conecte a entrada à esquerda à saída à direita. Triângulo testa. R dá uma dica, L reinicia e O volta.',order='Escolha um cartão com esquerda/direita e marque com X. Vá até outro cartão e aperte X para trocar os dois. Triângulo verifica a ordem. R dá uma dica, L reinicia e O volta.',crates='O direcional move Lia. Empurre as caixas para todas as marcas douradas. Quadrado desfaz o último movimento. L reinicia. Triângulo verifica. R dá dicas e O volta.',lights='O direcional escolhe uma célula. X inverte a luz dela e das vizinhas em cruz. Acenda todas. Triângulo testa. R dá dicas, L reinicia e O volta.',sequence='Escolha um símbolo com esquerda/direita e aperte X para acrescentar à sequência. Quadrado apaga o último. Triângulo testa. R dá dicas, L reinicia e O volta.'}
   G.say({tutorial[p.kind]},p.name,nil,'puzzle')
  end
 elseif o.type=='note' then
  G.S.notes[o.note]=true;local n=D.notes[o.note];G.save();G.say({n.text},n.title,nil,'world')
 elseif o.type=='npc' or o.type=='look' then G.story(o.story,o.type=='npc' and o.label or 'Lia e Nimbo',nil,'world')
 elseif o.type=='rest' then G.save();G.story(o.story,'Uma pausa na viagem',nil,'world')
 elseif o.type=='memory' then
  local c=o.chapter;local ch=D.chapters[c]
  if G.S.memories[c] then G.story('memory_done'..c,ch.memory.name,nil,'world');return end
  G.story('memory'..c,ch.memory.name,function()
   G.ask(ch.memory.name,{ch.memory.options[1],ch.memory.options[2],ch.memory.options[3],'Pensar mais e voltar'},function(i)
    if i==4 then G.mode='world'
    elseif i==ch.memory.correct then
     G.S.memories[c]=true;G.save();G.story('memory_done'..c,'Testemunho voluntário',nil,'world')
    else G.say({'A pessoa hesita. «Isso ainda prende alguém ao que não pode escolher. Vamos reler a carta e pensar no que ela pede?» Você pode tentar de novo quando quiser.'},ch.npc,nil,'world') end
   end,'world')
  end,'world')
 elseif o.type=='final' then G.finalChoice() end
end
function G.walkable(x,y)
 if x<2 or x>478 or y<2 or y>222 then return false end
 for _,pt in ipairs({{-4,-3},{4,-3},{-4,3},{4,3}}) do
  local tx=math.floor((x+pt[1])/16)+1;local ty=math.floor((y+pt[2])/16)+1
  local row=G.room.collision[ty]
  if not row or row:sub(tx,tx)~='.' then return false end
 end return true
end
function G.transition(side)
 local e=G.room.exits[side];if not e then return end
 local ok=L.meets(G.S,e.requires)
 if not ok then
  G.S.x=side=='east' and 460 or G.S.x
  G.say({'A passagem só abre depois de resolver '..D.puzzles[e.requires[1]].name..'. Há seis mecanismos conectados neste distrito. Consulte o objetivo no diário.'},'Passagem fechada',nil,'world');return
 end
 local sp={east={26,112},west={454,112},north={240,198},south={240,26}}
 G.loadRoom(e.room,sp[side][1],sp[side][2],true)
end
local function key(k) return G.pressed[k] end
function G.openInventory() G.mode='inventory';G.cursor=1;G.combineFirst=nil end
function G.inventoryList()
 local a={} for id in pairs(G.S.items) do a[#a+1]=id end
 table.sort(a,function(x,y) return D.items[x].name<D.items[y].name end);return a
end
function G.openJournal() G.mode='journal';G.scroll=1;G.journalTab=1 end
function G.pause()
 G.mode='pause';G.cursor=1
end
function G.travel()
 local options,ids={},{}
 for c,ch in ipairs(D.chapters) do
  local seen=false
  for id in pairs(G.S.visited) do if D.rooms[id].chapter==c then seen=true end end
  if seen then options[#options+1]=ch.name;ids[#ids+1]=ch.start+4 end
 end
 options[#options+1]='Voltar'
 G.ask('Bancos já alcançados',options,function(i)
  if ids[i] then G.loadRoom(ids[i],240,144,false) else G.mode='pause';G.cursor=1 end
 end,'pause')
end
function G.input(k,held,dt)
 G.pressed=k;G.held=held;G.timer=G.timer+dt;G.frame=G.frame+1
 G.toastTime=math.max(0,G.toastTime-dt)
 if G.playing then G.S.seconds=G.S.seconds+dt;G.saveTime=G.saveTime+dt end
 if G.mode=='title' then
  if key('up') then G.titleCursor=(G.titleCursor-2)%4+1 elseif key('down') then G.titleCursor=G.titleCursor%4+1 end
  if key('cross') then
   if G.titleCursor==1 then
    local save=L.load(SAVE_PREFIX)
    if save then G.S=save;G.selected=nil;G.loadRoom(save.room,save.x,save.y,false)
    else G.newGame() end
   elseif G.titleCursor==2 then
    if L.load(SAVE_PREFIX) then G.ask('Começar de novo substitui o progresso atual.',{'Cancelar','Começar nova viagem'},function(i) if i==2 then G.newGame() else G.mode='title' end end,'title') else G.newGame() end
   elseif G.titleCursor==3 then G.say({'Direcional ou analógico: andar. Segure O: correr. X: examinar/conversar. Triângulo: bolsa. Quadrado: diário. SELECT: mapa. START: pausa. Na bolsa, Quadrado combina e X equipa. Os enigmas explicam seus próprios controles.','O jogo salva ao mudar de sala, concluir puzzles, recolher pistas e fazer escolhas, além do salvamento manual. Duas cópias alternadas protegem contra uma gravação interrompida. Aguarde o aviso de progresso salvo antes de fechar.','Leia as cartas com calma. O diário registra pistas e objetivos. R oferece três níveis de dica nos puzzles. Não existe prazo em tempo real, combate, punição por respostas erradas ou exigência de abrir arquivos fora do jogo.','Criação original para esta aventura. Trilha original sintetizada, arte de abertura gerada e sprites em pixel art definidos em código. Execução PSP: LuaPlayer Euphoria 8, de Zack e colaboradores. Veja os créditos completos no pacote.'},'Como jogar',nil,'title')
   else G.quit=true end
  end
 elseif G.mode=='world' then
  if key('start') then G.pause();return elseif key('triangle') then G.openInventory();return elseif key('square') then G.openJournal();return elseif key('select') then G.mode='map';return end
  if key('cross') then G.interact(G.nearest());return end
  local dx,dy=0,0
  if held.left then dx=-1;G.S.dir=4 elseif held.right then dx=1;G.S.dir=2 elseif held.up then dy=-1;G.S.dir=1 elseif held.down then dy=1;G.S.dir=3 end
  local speed=(held.circle and 122 or 77)*dt
  if dx~=0 or dy~=0 then
   G.walk=G.walk+dt
   local nx=G.S.x+dx*speed;local ny=G.S.y+dy*speed
   if G.walkable(nx,G.S.y) then G.S.x=nx end
   if G.walkable(G.S.x,ny) then G.S.y=ny end
   if G.S.x<9 then G.transition('west') elseif G.S.x>471 then G.transition('east') elseif G.S.y<9 then G.transition('north') elseif G.S.y>215 then G.transition('south') end
  else G.walk=0 end
  if G.saveTime>90 and G.mode=='world' then G.save() end
 elseif G.mode=='dialog' then
  if key('cross') then
   local d=G.dialog;d.index=d.index+1
   if d.index>#d.pages then G.mode=d.back;G.dialog=nil;if d.after then d.after() end end
  elseif key('left') and G.dialog.index>1 then G.dialog.index=G.dialog.index-1 end
 elseif G.mode=='choice' then
  local ch=G.choice
  if key('up') then G.cursor=(G.cursor-2)%#ch.options+1 elseif key('down') then G.cursor=G.cursor%#ch.options+1
  elseif key('circle') then G.mode=ch.back
  elseif key('cross') then local cb=ch.callback;G.mode=ch.back;cb(G.cursor) end
 elseif G.mode=='inventory' then
  local list=G.inventoryList();G.cursor=math.max(1,math.min(G.cursor,#list))
  if key('circle') then G.mode='world';G.combineFirst=nil
  elseif key('up') then G.cursor=math.max(1,G.cursor-1) elseif key('down') then G.cursor=math.min(#list,G.cursor+1)
  elseif key('cross') and list[G.cursor] then G.selected=list[G.cursor];G.message('Equipado: '..D.items[G.selected].name);G.mode='world'
  elseif key('triangle') and list[G.cursor] then local it=D.items[list[G.cursor]];G.say({it.description},it.name,nil,'inventory')
  elseif key('square') and list[G.cursor] then
   local id=list[G.cursor]
   if not G.combineFirst then G.combineFirst=id;G.message('Escolha o segundo objeto e aperte Quadrado.')
   else
    local out=L.combine(G.S,G.combineFirst,id,D.recipes);G.combineFirst=nil
    if out then G.selected=out;G.cursor=1;G.save();G.say({'Você preparou '..D.items[out].name..'. O objeto já ficou equipado. Feche a bolsa com O e examine o aparelho que precisa dele.'},'Combinação',nil,'inventory')
    else G.say({'Esses objetos não se combinam. Nenhum foi perdido. As pistas explicam quais materiais usar em cada distrito.'},'Bolsa',nil,'inventory') end
   end
  end
 elseif G.mode=='journal' then
  if key('circle') or key('square') then G.mode='world'
  elseif key('left') then G.journalTab=(G.journalTab+1)%3+1;G.scroll=1
  elseif key('right') then G.journalTab=G.journalTab%3+1;G.scroll=1
  elseif key('up') then G.scroll=math.max(1,G.scroll-1) elseif key('down') then G.scroll=math.min(G.journalMax or 1,G.scroll+1) end
 elseif G.mode=='map' then if key('circle') or key('select') then G.mode='world' end
 elseif G.mode=='pause' then
  if key('up') then G.cursor=(G.cursor-2)%6+1 elseif key('down') then G.cursor=G.cursor%6+1
  elseif key('circle') or key('start') then G.mode='world'
  elseif key('cross') then
   if G.cursor==1 then G.mode='world'
   elseif G.cursor==2 then G.save()
   elseif G.cursor==3 then G.travel()
   elseif G.cursor==4 then
    G.S.music=1-G.S.music
    if G.musicReady then pcall(Ogg.stop,0);pcall(Ogg.unload,0);G.musicReady=false end
    if G.S.music==1 then G.musicChapter=0;G.music() end
    G.save()
   elseif G.cursor==5 then if G.save() then G.playing=false;G.mode='title' end
   else if G.save() then G.quit=true end end
  end
 elseif G.mode=='puzzle' then
  if key('circle') then G.mode='world';return end
  if key('l') then G.q=L.initPuzzle(G.p);G.S.puzzles[G.p.id]=G.q;G.message('Tentativa reiniciada.');return end
  if key('r') then
   local n=math.min(3,(G.S.hints[G.p.id] or 0)+1);G.S.hints[G.p.id]=n
   G.say({G.p.hints[n]},'Dica '..n..'/3 - '..G.p.name,nil,'puzzle');return
  end
  if key('triangle') then
   if L.solved(G.p,G.q) then
    local p=G.p;L.reward(G.S,p);G.mode='world';G.save();G.story(p.success,p.name,nil,'world')
   else G.message('Ainda não. Você pode ajustar ou pedir dica com R.') end
   return
  end
  for _,n in ipairs({'up','right','down','left','cross','square'}) do if key(n) then L.puzzleInput(G.p,G.q,n) end end
 elseif G.mode=='credits' then
  if key('cross') or key('circle') then G.mode='world';G.message('Você pode continuar e rever as outras rotas.') end
 end
end
function G.drawWorld()
 if not assets.room then screen:blit(0,0,assets.title);return end
 screen:blit(0,24,assets.room)
 local actors={}
 for _,o in ipairs(G.room.objects) do actors[#actors+1]={y=o.y,o=o} end
 actors[#actors+1]={y=G.S.y,player=true};table.sort(actors,function(a,b) return a.y<b.y end)
 for _,a in ipairs(actors) do
  if a.player then
   local frame=G.walk>0 and (math.floor(G.walk*9)%3) or 0
   sprite(assets.lia,(G.S.dir-1)*3+frame,G.S.x,G.S.y+24)
   sprite(assets.objects,0,G.S.x-18,G.S.y+12+math.sin(G.timer*4)*2)
  else
   local o=a.o;sprite(assets.objects,o.sprite,o.x,o.y+24)
   local solved=o.type=='puzzle' and G.S.flags[o.puzzle] or o.type=='memory' and G.S.memories[o.chapter]
   if solved then text(o.x-4,o.y-20,'+','teal')
   elseif o.type=='note' and not G.S.notes[o.note] then rect(o.x-1,o.y-18,3,3,'gold') end
  end
 end
 rect(0,0,480,24,'panel');rect(0,247,480,25,'panel')
 text(10,5,G.room.name,'cream')
 local c=G.room.chapter;local solved=0
 for i=(c-1)*6+1,c*6 do if G.S.flags[string.format('p%02d',i)] then solved=solved+1 end end
 text(402,5,c..'/6 '..solved..'/6','gold')
 local near=G.nearest()
 if near then
  text(12,252,'X  '..near.label,'gold')
  rect(near.x-12,near.y+27,24,2,'gold')
 else text(10,252,G.selected and ('Equipado: '..D.items[G.selected].name) or 'X examinar   TRI bolsa   QUAD diário   SELECT mapa','dim') end
end
function G.drawTitle()
 screen:blit(0,0,assets.title);screen:blit(25,35,assets.logo)
 text(28,119,'Uma aventura de Lia e Nimbo','dim')
 local list={'Continuar / começar','Nova viagem','Como jogar e créditos','Sair'}
 for i,t in ipairs(list) do
  if i==G.titleCursor then rect(23,151+(i-1)*22,239,20,'select');text(28,153+(i-1)*22,'>','gold') end
  text(47,153+(i-1)*22,t,i==G.titleCursor and 'gold' or 'cream')
 end
 text(26,251,'PS VITA  |  X confirmar','dim')
end
local function listPanel(title,options,cursor)
 box(22,29,436,213);text(39,41,title,'gold')
 for i,s in ipairs(options) do
  local y=68+(i-1)*23
  if i==cursor then rect(33,y-1,414,22,'select') end
  text(40,y,(i==cursor and '> ' or '  ')..s,i==cursor and 'gold' or 'cream')
 end
end
function G.drawPuzzle()
 local p,q=G.p,G.q
 rect(0,0,480,272,'panel');text(16,9,p.name,'gold')
 text(16,29,'TRI testar   R dica   L reiniciar   O voltar','dim')
 if p.kind=='code' then
  text(28,58,'Procure a anotação, escolha e ajuste os números.')
  local x=240-#q.cells*29
  for i,v in ipairs(q.cells) do
   box(x+(i-1)*58,105,48,64)
   if i==q.cursor then rect(x+(i-1)*58+2,107,44,60,'select') end
   text(x+20+(i-1)*58,130,v,'gold')
   if i==q.cursor then text(x+20+(i-1)*58,88,'^','teal');text(x+20+(i-1)*58,175,'v','teal') end
  end
  text(32,216,'Esq/dir: escolher   Cima/baixo: alterar','dim')
 elseif p.kind=='order' then
  text(24,61,'X marca um cartão e troca com outro.','cream')
  for i,v in ipairs(q.cells) do
   local x=15+(i-1)*92
   box(x,103,88,74)
   if i==q.cursor then rect(x+2,105,84,70,'select') end
   text(x+39,110,tostring(i),'dim')
   local s=latin(p.labels[v]);raw(x+44-#s*4,139,s,q.held==i and 'teal' or 'gold')
   if q.held==i then text(x+13,184,'MARCADO','teal') end
  end
  text(24,222,'Leia a ordem na pista guardada no diário.','dim')
 elseif p.kind=='sequence' then
  text(26,59,'Escolha um símbolo. X acrescenta; QUAD apaga.')
  local x=32
  for i,s in ipairs(p.labels) do
   box(x+(i-1)*106,87,98,49)
   if i==q.cursor then rect(x+2+(i-1)*106,89,94,45,'select') end
   local ss=latin(s);raw(x+49+(i-1)*106-#ss*4,105,ss,'gold')
  end
  text(26,155,'Sua sequência:','dim')
  for i=1,#p.answer do
   local xx=28+(i-1)*55
   box(xx,181,49,43)
   text(xx+20,185,tostring(i),'dim')
   text(xx+20,205,q.cells[i] and tostring(q.cells[i]) or '-','gold')
  end
  text(26,244,'Os números correspondem aos símbolos acima.','dim')
 elseif p.kind=='lights' or p.kind=='pipes' then
  local n=p.n;local cell=39;local ox=43;local oy=63
  local reached=p.kind=='pipes' and L.pipeReach(p,q) or {}
  for i=1,n*n do
   local x=ox+((i-1)%n)*cell;local y=oy+math.floor((i-1)/n)*cell
   rect(x,y,cell-3,cell-3,i==q.cursor and 'gold' or 'border');rect(x+2,y+2,cell-7,cell-7,'floor')
   if p.kind=='lights' then
    rect(x+9,y+9,17,17,q.cells[i]==1 and 'gold' or 'panel')
    if q.cells[i]==1 then rect(x+13,y+12,4,4,'cream') end
   else
    local sides=L.pipeSides(p.shapes[i],q.cells[i]);local color=reached[i] and 'teal' or 'dim'
    rect(x+15,y+15,6,6,color)
    if sides[1] then rect(x+15,y+3,6,17,color) end
    if sides[2] then rect(x+18,y+15,17,6,color) end
    if sides[3] then rect(x+15,y+18,6,17,color) end
    if sides[4] then rect(x+3,y+15,17,6,color) end
   end
  end
  if p.kind=='pipes' then
   text(20,oy+math.floor((p.source-1)/n)*cell+9,'>','teal')
   text(ox+n*cell+1,oy+math.floor((p.sink-1)/n)*cell+9,'>','gold')
  end
  local lines=wrap(p.kind=='lights' and 'Acenda todas as luzes. X muda a célula e suas vizinhas em cruz. As casas vão de 1 a 16, por linha.' or 'Ligue as duas setas. X gira um cano. Azul mostra a água chegando. Nem todo tubo precisa ser usado.',27)
  for i,s in ipairs(lines) do raw(237,80+i*17,s,'cream') end
  text(238,201,'Movimentos: '..q.moves,'dim')
 elseif p.kind=='crates' then
  local n=p.n;local cell=25;local ox=49;local oy=58
  for i=1,n*n do
   local x=ox+((i-1)%n)*cell;local y=oy+math.floor((i-1)/n)*cell
   rect(x,y,cell-1,cell-1,p.walls[i]==1 and 'border' or 'floor')
   if L.has(p.targets,i) then rect(x+7,y+7,10,10,'gold') end
   if L.has(q.boxes,i) then
    rect(x+3,y+3,18,18,'wood');rect(x+4,y+4,16,2,L.has(p.targets,i) and 'teal' or 'gold');rect(x+11,y+5,2,14,'panel')
   end
   if q.player==i then rect(x+8,y+4,9,8,'cream');rect(x+6,y+12,13,10,'orange') end
  end
  local lines=wrap('Empurre as caixas até as marcas douradas. QUAD desfaz um passo. L reinicia. Não há limite de tentativas.',25)
  for i,s in ipairs(lines) do raw(254,73+i*17,s) end
  text(254,202,'Passos: '..q.moves,'dim')
 end
end
function G.drawJournal()
 rect(0,0,480,272,'panel');text(16,9,({'OBJETIVO','PISTAS','TESTEMUNHOS'})[G.journalTab],'gold')
 text(16,29,'Esq/dir: aba  Cima/baixo: ler  O: voltar','dim')
 local lines={}
 local function add(s,color)
  for _,v in ipairs(wrap(s,53)) do lines[#lines+1]={s=v,color=color or 'cream'} end
  lines[#lines+1]={s='',color='dim'}
 end
 if G.journalTab==1 then
  local p=G.currentTask()
  add(D.chapters[G.room.chapter].name,'gold')
  if p then
   add('Próximo mecanismo: '..p.name..'. Local: '..D.rooms[p.room].name..'.')
   if p.item then add('Objeto necessário: '..D.items[p.item].name..'. Combine os dois materiais deste distrito na bolsa.') end
   add('Pista: '..D.notes[p.note].title..'. '..(G.S.notes[p.note] and 'Já está na aba Pistas.' or 'Procure as placas e anotações nas salas deste distrito.'))
  else add(G.room.chapter<6 and 'Os seis mecanismos estão prontos. Vá à sala sudeste do mapa e atravesse a saída para o próximo distrito.' or 'A Última autorização está aberta. Converse com Azel e escolha o futuro na sala sudeste.') end
  add('Opcional: seis cartas, uma na casa de cada distrito, permitem reunir testemunhos voluntários. Use START > Viajar entre bancos para retornar.')
  add('Dicas: cada puzzle tem três níveis, acessíveis com R. Reiniciar ou errar não remove itens nem progresso. Não há combate ou cronômetro de missão.')
 elseif G.journalTab==2 then
  local any=false
  for c=1,6 do
   for i=(c-1)*6+1,c*6 do local id=string.format('n%02d',i);if G.S.notes[id] then any=true;add(D.notes[id].title,'gold');add(D.notes[id].text) end end
  end
  if not any then add('As pistas examinadas com X serão copiadas para estas páginas.') end
 else
  add('Testemunhos: '..L.count(G.S.memories)..' / 6','gold')
  for c,ch in ipairs(D.chapters) do add((G.S.memories[c] and '[+] ' or '[ ] ')..ch.npc..' - '..ch.memory.name,G.S.memories[c] and 'teal' or 'cream') end
  add('Finais conhecidos: '..L.count(G.S.endings)..' / 3. As escolhas finais podem ser revisitadas. Nenhum final apaga seu progresso.')
 end
 G.journalMax=math.max(1,#lines-13)
 for i=G.scroll,math.min(G.scroll+12,#lines) do raw(24,58+(i-G.scroll)*14,lines[i].s,lines[i].color) end
 text(16,250,G.scroll..' / '..G.journalMax,'dim')
end
function G.drawMap()
 rect(0,0,480,272,'panel');text(16,11,D.chapters[G.room.chapter].name,'gold')
 text(16,32,'Mapa local  |  Você: ponto dourado  |  O voltar','dim')
 local start=D.chapters[G.room.chapter].start
 for ri=0,8 do
  local x=28+(ri%3)*147;local y=64+math.floor(ri/3)*55;local rid=start+ri
  if ri%3<2 then rect(x+132,y+21,15,2,'border') end
  if ri<6 then rect(x+65,y+43,2,13,'border') end
  box(x,y,132,45)
  if G.S.visited[rid] then
   local ls=wrap(D.rooms[rid].name,15)
   for j=1,math.min(2,#ls) do raw(x+7,y+6+(j-1)*14,ls[j],G.S.room==rid and 'gold' or 'cream') end
  else text(x+10,y+13,'Não visitado','dim') end
  if G.S.room==rid then rect(x+117,y+32,6,6,'gold') end
 end
 local ready=G.S.flags[string.format('p%02d',G.room.chapter*6)]
 text(26,239,G.room.chapter==6 and 'Último painel na sala sudeste.' or (ready and 'Saída leste da sala sudeste: aberta.' or 'Saída leste da sala sudeste: 6 mecanismos.'),'dim')
end
function G.draw()
 screen:clear(COL.panel)
 if G.mode=='title' then G.drawTitle()
 elseif G.mode=='puzzle' or (G.mode=='dialog' and G.dialog.back=='puzzle') then G.drawPuzzle()
 elseif G.mode=='journal' then G.drawJournal()
 elseif G.mode=='map' then G.drawMap()
 elseif G.mode=='credits' then
  screen:blit(0,0,assets.title);box(22,25,436,223)
  text(48,42,'O ÚLTIMO ENDEREÇO','gold');text(48,69,'Obrigado por jogar.','cream')
  local min=math.floor(G.S.seconds/60);text(48,102,'Seu tempo: '..math.floor(min/60)..'h '..(min%60)..'min','cream')
  text(48,125,'Testemunhos: '..L.count(G.S.memories)..'/6','teal')
  text(48,148,'Finais vistos: '..L.count(G.S.endings)..'/3','teal')
  text(48,184,'A cidade ainda tem histórias.','cream');text(48,217,'X voltar ao ponto anterior à escolha','gold')
 else if G.playing then G.drawWorld() else G.drawTitle() end end
 if G.mode=='dialog' then
  box(11,137,458,126)
  local d=G.dialog;text(25,145,d.title:sub(1,52),'gold')
  for i,s in ipairs(d.pages[d.index] or {}) do raw(27,164+(i-1)*15,s) end
  text(27,244,'X continuar   < reler','dim');text(390,244,d.index..'/'..#d.pages,'dim')
 elseif G.mode=='choice' then listPanel(G.choice.title,G.choice.options,G.cursor)
 elseif G.mode=='inventory' then
  box(22,23,436,224);text(38,35,'BOLSA  /  X equipar  QUAD combinar','gold')
  local list=G.inventoryList();local first=math.max(1,G.cursor-6)
  for i=first,math.min(first+6,#list) do
   local y=65+(i-first)*20;local id=list[i]
   if i==G.cursor then rect(34,y-1,411,20,'select') end
   text(40,y,(id==G.combineFirst and '* ' or i==G.cursor and '> ' or '  ')..D.items[id].name,id==G.selected and 'teal' or 'cream')
  end
  if #list==0 then text(40,87,'Você ainda não recolheu objetos.','dim') end
  text(38,219,'TRI examinar  O fechar  '..#list..' objetos','dim')
 elseif G.mode=='pause' then
  listPanel('UMA PAUSA NA VIAGEM',{'Continuar','Salvar agora','Viajar entre bancos',G.S.music==1 and ('Música: '..TRACK_NAMES[D.rooms[G.S.room].chapter]) or 'Música: desligada','Salvar e voltar ao início','Salvar e sair'},G.cursor)
 end
 if G.toastTime>0 and G.mode~='dialog' then
  local s=latin(G.toast);if #s>57 then s=s:sub(1,57) end
  rect(7,250,466,18,'panel');raw(12,250,s,'gold')
 end
end
function G.init()
 COL={panel=Color.new(13,25,36),border=Color.new(63,88,99),gold=Color.new(231,180,102),cream=Color.new(237,226,199),teal=Color.new(109,210,184),dim=Color.new(135,158,168),floor=Color.new(37,57,67),wood=Color.new(137,93,62),orange=Color.new(194,105,60),select=Color.new(42,64,74)}
 for _,s in ipairs({'cream','gold','teal','dim'}) do fonts[s]=Image.load('assets/font_'..s..'.png') end
 assets.title=Image.load('assets/title.png');assets.logo=Image.load('assets/logo.png');assets.lia=Image.load('assets/lia.png');assets.objects=Image.load('assets/objects.png')
 -- Native Vita profile: do not force PSP clock settings.
end
function G.run()
 G.init();local timer=Timer.new();local last=timer:time();local repeatTime={}
 local keys={'up','right','down','left','cross','circle','triangle','square','l','r','start','select'}
 while not G.quit do
  local p=Controls.read();local held,pressed={},{}
  local now=timer:time();local dt=math.max(0.001,math.min(0.05,(now-last)/1000));last=now
  for _,k in ipairs(keys) do
   held[k]=p[k](p);pressed[k]=held[k] and not old[k]
   if held[k] and (k=='up' or k=='down' or k=='left' or k=='right') and G.mode~='world' and G.mode~='puzzle' then
    repeatTime[k]=(repeatTime[k] or 0)+dt
    if repeatTime[k]>0.32 then pressed[k]=true;repeatTime[k]=0.24 end
   else repeatTime[k]=0 end
  end
  local ax,ay=p:analogX(),p:analogY()
  if G.mode=='world' then
   if ax < -35 then held.left=true elseif ax>35 then held.right=true end
   if ay < -35 then held.up=true elseif ay>35 then held.down=true end
  end
  G.input(pressed,held,dt);old=held
  System.draw();G.drawing=true;G.draw();System.endDraw();G.drawing=false;screen.flip()
 end
 if G.musicReady then pcall(Ogg.stop,0);pcall(Ogg.unload,0) end
 System.quit()
end
G.wrap=wrap;G.latin=latin
return G
