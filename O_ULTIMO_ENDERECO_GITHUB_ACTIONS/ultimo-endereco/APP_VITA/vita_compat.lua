-- O ULTIMO ENDERECO: LPE/PSP -> Lua Player Plus Vita compatibility layer.
-- Requires LPP-Vita built for the PS Vita (not the PSP's EBOOT.PBP).
-- Renders original 480x272 coordinates at exact 2x for Vita's 960x544 panel.
-- Do not create or load PSP .prx files.
local nativeControls=Controls
local nativeRead=nativeControls.read
local nativeCheck=nativeControls.check
local nativeAnalog=nativeControls.readLeftAnalog
local nativeTimer=Timer
local nativeExit=System.exit
local nativeScreen=Screen
local nativeGraphics=Graphics

-- In safe mode, app0: is read-only. Both save slots live in writable ux0:/data.
local saveDir='ux0:/data/ULTIMOEND'
if not System.doesDirExist(saveDir) then System.createDirectory(saveDir) end

local function asset(name)
 if name:sub(1,5)=='app0:' or name:sub(1,4)=='ux0:' then return name end
 return 'app0:/'..name
end

local Image={}
function Image.load(filename)
 local im=nativeGraphics.loadImage(asset(filename))
 if not im then error('Imagem nao abriu: '..filename) end
 -- Pixel-perfect sprites and 2x integer scaling, no linear blur.
 if FILTER_POINT then nativeGraphics.setImageFilters(im,FILTER_POINT,FILTER_POINT) end
 return im
end
function Image.free(im)
 if im then nativeGraphics.freeImage(im) end
end
_G.Image=Image

local screen={}
function screen:clear(color) nativeScreen.clear(color) end
function screen:slowClear() nativeScreen.clear() end
function screen:fillRect(x,y,w,h,color)
 if w<=0 or h<=0 then return end
 nativeGraphics.fillRect(x,x+w,y,y+h,color)
end
function screen:blit(x,y,img,alpha,sx,sy,w,h)
 if not img then return end
 if sx~=nil then
  nativeGraphics.drawPartialImage(x,y,img,sx,sy,w,h)
 else
  nativeGraphics.drawImage(x,y,img)
 end
end
function screen:print(x,y,t,color)
 nativeGraphics.debugPrint(x,y,t,color)
end
function screen.flip()
 nativeScreen.flip()
 nativeScreen.waitVblankStart()
end
_G.screen=screen

function System.draw()
 nativeGraphics.initBlend()
 nativeGraphics.initRescaler(0,0,2.0,2.0)
end
function System.endDraw()
 nativeGraphics.termRescaler()
 nativeGraphics.termBlend()
end
function System.quit()
 nativeExit()
end

local buttons={
 up=SCE_CTRL_UP,down=SCE_CTRL_DOWN,left=SCE_CTRL_LEFT,right=SCE_CTRL_RIGHT,
 cross=SCE_CTRL_CROSS,circle=SCE_CTRL_CIRCLE,square=SCE_CTRL_SQUARE,
 triangle=SCE_CTRL_TRIANGLE,l=SCE_CTRL_LTRIGGER,r=SCE_CTRL_RTRIGGER,
 start=SCE_CTRL_START,select=SCE_CTRL_SELECT
}
local Controls={}
function Controls.read()
 local mask=nativeRead()
 local pad={}
 for key,bit in pairs(buttons) do
  local value=nativeCheck(mask,bit)
  pad[key]=function() return value end
 end
 local ax,ay=nativeAnalog()
 ax=ax or 128;ay=ay or 128
 -- LPP-Vita analog ranges 0..255, center 128. PSP game expects -128..127.
 function pad:analogX() return ax-128 end
 function pad:analogY() return ay-128 end
 return pad
end
_G.Controls=Controls

local Timer={}
function Timer.new()
 local id=nativeTimer.new()
 local obj={id=id}
 function obj:time() return nativeTimer.getTime(self.id) end
 return obj
end
_G.Timer=Timer

-- Ogg channels from the PSP edition become one streaming Vita Sound handle.
local Ogg={}
local soundId=nil
local soundInitialized=false
function Ogg.load(path,channel)
 if not soundInitialized then Sound.init();soundInitialized=true end
 if soundId~=nil then pcall(Sound.close,soundId);soundId=nil end
 soundId=Sound.open(asset(path))
 if soundId==nil then error('Musica indisponivel: '..path) end
end
function Ogg.volume(v,channel)
 if soundId~=nil then Sound.setVolume(soundId,math.floor(math.max(0,math.min(1,v))*32767)) end
end
function Ogg.play(loop,channel)
 if soundId~=nil then Sound.play(soundId,not not loop) end
end
function Ogg.stop(channel)
 if soundId~=nil then Sound.pause(soundId) end
end
function Ogg.unload(channel)
 if soundId~=nil then Sound.close(soundId);soundId=nil end
end
function Ogg.shutdown()
 Ogg.unload(0)
 if soundInitialized then Sound.term();soundInitialized=false end
end
_G.Ogg=Ogg

return {app=asset,save=saveDir}
