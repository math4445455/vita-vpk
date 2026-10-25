-- Vita standalone game entrypoint. Lua Player Plus Vita loads app0:/index.lua.
-- Error handling is kept in the runtime, so Vita errors show a screen instead
-- of silently powering off the device.
local ok, err=pcall(function()
 dofile('app0:/vita_compat.lua')
 local game=dofile('app0:/game.lua')
 game.run()
end)
if not ok then
 -- LPP-Vita's own runtime displays the error when we raise here.
 error('O ULTIMO ENDERECO VITA: '..tostring(err))
end
