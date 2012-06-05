-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------

-- hide the status bar
display.setStatusBar( display.HiddenStatusBar )

-- include the Corona "storyboard" module
local storyboard = require "storyboard"

local drumHandle = audio.loadStream("drumbeat.wav")
audio.play(drumHandle, { channel=1, loops=-1, fadein=1000 })

-- load menu screen
storyboard.gotoScene( "menu" )