-----------------------------------------------------------------------------------------
--
-- level1.lua
--
-----------------------------------------------------------------------------------------

system.activate( "multitouch" )


local storyboard = require( "storyboard" )
local scene = storyboard.newScene()

-- include Corona's "physics" library
local physics = require "physics"
physics.start(); physics.pause()

local widget = require "widget"
local mathlibapi = require("mathlib")

--------------------------------------------

-- forward declarations and other locals
local debug = false

local scoreSound = audio.loadSound("planethit.wav")
local winSound = audio.loadSound("glitchyi.wav")

local screenW, screenH, halfW, halfH = display.contentWidth, display.contentHeight, display.contentWidth*0.5, display.contentHeight*0.5

local leftPlayer, rightPlayer

local leftPlayerX, leftPlayerY = screenW / 12, screenH / 2
local rightPlayerX, rightPlayerY = screenW - leftPlayerX, leftPlayerY

local playerRadius = 10

local leftPlayerTouchRect = display.newRect(0, 0, halfW, screenH)
local rightPlayerTouchRect = display.newRect(halfW, 0, halfW, screenH)
rightPlayerTouchRect:setFillColor(0,0,0,0)
leftPlayerTouchRect:setFillColor( 0,0,0, 0 )

local transitions = {}

local players = display.newGroup()
local objects = display.newGroup()
local bullets = display.newGroup()
local walls = display.newGroup()
local trophiesLeft = display.newGroup()
local trophiesRight = display.newGroup()

local menuBtn, pauseBtn, playAgainBtn

local scoreText1, scoreText2
local score1, score2
local scoreSize = 25

local scoreHeading1X, scoreHeading1Y = 10, 0
local scoreHeading2X, scoreHeading2Y = screenW - 85, scoreHeading1Y
local scoreHeadingSize = 25

local scoreTextXOffset = 50
local scoreText1X, scoreText1Y = scoreHeading1X + scoreTextXOffset, scoreHeading1Y
local scoreText2X, scoreText2Y = scoreHeading2X + scoreTextXOffset, scoreHeading1Y

local pauseScreen
local pauseText
local pausePhrase = "Paused"
local pauseFontSize = 100
local pauseAlpha = 150

local scoreBoardScreen
local scoreBoardText
local scoreBoardTextX, scoreBoardTextY = halfW, screenH / 3
local playAgainBtnY = 2 * screenH / 3
local scoreBoardFontSize = 25
local scoreBoardAlpha = 150

-- Game state

local paused = false
-- leftPlayer and rightPlayer have .isShooting, .shootingX, .shootingY, .timeLastShot, .rightNeg (right is -1)

-- Bullet dynamic constants
local refractoryMin, refractoryMax = 200, 220
local bulletRadius = 7
local bulletOffset = 40 -- distance from center of player to bullet origin

local bulletDensity = .8
local bulletSpeed = 2

-- Object dynamic constants
local objectSize = 50
local objectDensity = 2.0
local objectBounce = 0.3

-- Trophy cases layout
local trophyHeight = 20
local trophyWidth = 20

local trophyMarginTop = 5 -- top margin for trophies
local trophyXMargin = 10 -- seperation
local trophyTransitionTime = 1000
local trophyScoreTextXOffset = 20

local trophyStartXOrigin = 80

-----------------------------------------------------------------------------------------
-- BEGINNING OF YOUR IMPLEMENTATION
-- 
-- NOTE: Code outside of listener functions (below) will only be executed once,
--		 unless storyboard.removeScene() is called.
-- 
-----------------------------------------------------------------------------------------

local function gameLoop(event)
    if not paused then
        -- each player, check for isShooting and proper refractory period
        for i=players.numChildren,1,-1 do
            local player = players[i]

            if player.isShooting and event.time - player.timeLastShot >= math.random(refractoryMin, refractoryMax) then
                player.timeLastShot = event.time -- TODO: maybe make bullet grow in size, weight and velocity as you wait?
                if debug then print("Player "..player.name.." is shooting at " .. player.shootingX .. " " .. player.shootingY) end

                local playerCoords = {x = player.x, y = player.y }
                local mouseCoords = { x = player.shootingX, y = player.shootingY }
--                player.rotation = angleBetweenPoints(playerCoords, mouseCoords) + 90

                local relativeBulletOriginCoordsX, relativeBulletOriginCoordsY = calcCirclePoint(playerCoords, mouseCoords, bulletOffset)
                local bulletOriginCoords = { x = mouseCoords.x + relativeBulletOriginCoordsX, y = mouseCoords.y + relativeBulletOriginCoordsY }
                local scaledImpulse = rotatePoint({ x = bulletSpeed, y = 0 }, angleBetweenPoints(playerCoords, bulletOriginCoords))


--                local newBullet = display.newCircle(bulletOriginCoords.x, bulletOriginCoords.y, bulletRadius)
                local newBullet = display.newImage("ball.png", bulletOriginCoords.x, bulletOriginCoords.y)
                newBullet.width, newBullet.height = bulletRadius, bulletRadius
                newBullet.x = bulletOriginCoords.x
                newBullet.y = bulletOriginCoords.y

                physics.addBody(newBullet, { radius = bulletRadius, density = bulletDensity })
                newBullet.isBullet = true
                newBullet:applyLinearImpulse(scaledImpulse.x, scaledImpulse.y, newBullet.x, newBullet.y)

                bullets:insert(newBullet)
            end
        end

        for i=bullets.numChildren,1,-1 do
            local bullet = bullets[i]

            local dx, dy = bullet:getLinearVelocity()

            if dx < 0 and bullet.x < 80 then
                bullet:removeSelf()
                -- Give bullet to one side?
--                leftPlayer.bullets = leftPlayer.bullets + 1
            elseif dx > 0 and bullet.x > screenW - 80 then
                bullet:removeSelf()
--                rightPlayer.bullets = rightPlayer.bullets + 1
            end

            -- apply gravity away from center of screen?
        end

        for i=objects.numChildren,1,-1 do
            local object = objects[i]

            if object.x < 100 then
                -- right player score increase
                object:setReferencePoint(display.CenterRightReferencePoint)
                table.insert(transitions, transition.to(object, { time = trophyTransitionTime, x = screenW - trophyStartXOrigin - trophiesRight.numChildren * (trophyWidth + trophyXMargin), y = (trophyHeight / 2) + trophyMarginTop }))
                -- don't want to delete this transition:
                transition.to(object, {rotation = 0, width = trophyWidth, height = trophyHeight})
                physics.removeBody(object)
                objects:remove(object)
                trophiesRight:insert(object)
                scored(rightPlayer)
            elseif object.x > screenW - 100 then
                -- left player score increase
                object:setReferencePoint(display.CenterLeftReferencePoint)
                transition.to(object, { time = trophyTransitionTime, x = trophyStartXOrigin + trophiesLeft.numChildren * (trophyWidth + trophyXMargin), y = (trophyHeight / 2) + trophyMarginTop, rotation = 0, width = trophyWidth, height = trophyHeight })
                physics.removeBody(object)
                objects:remove(object)
                trophiesLeft:insert(object)
                scored(leftPlayer)
            end
        end

        if objects.numChildren < 1 then
            -- if no objects left, declare a winner
            onGameOver()
        end
    end
end

-- Called when the scene's view does not exist:
function scene:createScene( event )
	local group = self.view

	-- create a grey rectangle as the backdrop
	local background = display.newImageRect( "bg2.png", screenW, screenH )
    background:setReferencePoint( display.TopLeftReferencePoint )
    background.x, background.y = 0,0

--	background:setFillColor( 128 )

    -- create a left and right score heading
    local scoreHeading1 = display.newText("P1: ", scoreHeading1X, scoreHeading1Y, native.systemFont, scoreHeadingSize)
    local scoreHeading2 = display.newText("P2: ", scoreHeading2X, scoreHeading2Y, native.systemFont, scoreHeadingSize)

    -- create a left left and right score
    scoreText1 = display.newText("0", scoreText1X, scoreText1Y, native.systemFont, scoreSize )
    scoreText2 = display.newText("0", scoreText2X, scoreText2Y, native.systemFont, scoreSize )

    -- create a menu button
    menuBtn = widget.newButton{
        label="Menu",
        labelColor = { default={255}, over={128} },
        default="button.png",
        over="button-over.png",
        width=60, height=40,
        onRelease = onMenuBtnRelease	-- event listener function
    }
    menuBtn:setReferencePoint( display.BottomLeftReferencePoint )
    menuBtn.x = 5
    menuBtn.y = screenH - 5

    -- create a pause button
    pauseBtn = widget.newButton{
        label="Pause",
        labelColor = { default={255}, over={128} },
        default="button.png",
        over="button-over.png",
        width=60, height=40,
        onRelease = onPauseBtnRelease	-- event listener function
    }
    pauseBtn:setReferencePoint( display.BottomRightReferencePoint )
    pauseBtn.x = display.contentWidth - 5
    pauseBtn.y = display.contentHeight - 5
    
    -- create a "play again" high score board button
    playAgainBtn = widget.newButton{
        label="Play Again!",
        labelColor = { default={255}, over={128} },
        default="button.png",
        over="button-over.png",
        width=100, height=40,
        onRelease = onPlayAgainBtnRelease -- event listener function
    }
    playAgainBtn.isVisible = false
    playAgainBtn:setReferencePoint( display.CenterReferencePoint )
    playAgainBtn.x = halfW
    playAgainBtn.y = playAgainBtnY

    -- create pause overlay
    pauseScreen = display.newRect(0,0,screenW, screenH)
    pauseScreen:setFillColor(255, 255, 255, pauseAlpha) -- transparent
    pauseScreen.isVisible = false

    pauseText = display.newText(pausePhrase, 0, 0, native.systemFont, pauseFontSize)
    pauseText:setReferencePoint( display.CenterMiddleReferencePoint)
    pauseText.x, pauseText.y = halfW, halfH
    pauseText:setTextColor(0,0,0)
    pauseText.isVisible = false
    
    -- create scoreboard overlay
    scoreBoardScreen = display.newRect(0,0,screenW, screenH)
    scoreBoardScreen:setFillColor(255, 255, 255, scoreBoardAlpha) -- transparent
    scoreBoardScreen.isVisible = false

    scoreBoardText = display.newText("Scoreboard", 0, 0, native.systemFont, scoreBoardFontSize)
    scoreBoardText:setReferencePoint( display.CenterMiddleReferencePoint)
    scoreBoardText.x, scoreBoardText.y = scoreBoardTextX, scoreBoardTextY
    scoreBoardText:setTextColor(0,0,0)
    scoreBoardText.isVisible = false

    -- all display objects must be inserted into group
    group:insert(background)
    group:insert(walls)
    group:insert(players)
    group:insert(objects)
    group:insert(bullets)
    group:insert(scoreHeading1)
    group:insert(scoreHeading2)
    group:insert(scoreText1)
    group:insert(scoreText2)
    group:insert(leftPlayerTouchRect)
    group:insert(rightPlayerTouchRect)
    group:insert(pauseScreen)
    group:insert(scoreBoardScreen)
    group:insert(scoreBoardText)
    group:insert(pauseText)
    group:insert(pauseBtn)
    group:insert(menuBtn)
    group:insert(playAgainBtn)
    group:insert(trophiesLeft)
    group:insert(trophiesRight)
end

function cancelTransitions()
    for i, v in ipairs(transitions) do
        transition.cancel(v)
    end
end

function onGameOver()
    audio.play(winSound)
    local winner = "Absolutely nobody"
    cancelTransitions()

    if trophiesLeft.numChildren > trophiesRight.numChildren then
        winner = "Player 1"
    elseif trophiesRight.numChildren > trophiesLeft.numChildren then
        for i=trophiesRight.numChildren,1,-1 do
            local child = trophiesRight[i]
            -- Maybe perform a scoring operation here
            child:setReferencePoint(display.CenterReferencePoint)
            transition.to(child, {time = 500, x = screenW / 2 + i * (trophyXMargin + trophyWidth) - .5 * trophiesRight.numChildren * (trophyXMargin + trophyWidth) - trophyXMargin,  y = screenH / 2})
            transition.to(child, { time = 10000000, rotation = 2000000})
        end
        winner = "Player 2"
    end

    scoreBoardText.text = winner .. " is the winner!"

    scoreBoardText.isVisible = true
    scoreBoardScreen.isVisible = true

    pauseBtn.isVisible = false
    playAgainBtn.isVisible = true

    if paused then physics:start() else physics:pause() end
    paused = not paused
end

function onMenuBtnRelease ( event )
    print("Menu button pressed, going to menu scene")
    storyboard.gotoScene( "menu", "fade", 500 )
end

function onPauseBtnRelease ( event )
    print("Toggling pause")
    if paused then physics:start() else physics:pause() end
    paused = not paused

    pauseScreen.isVisible, pauseText.isVisible = paused, paused

    -- TODO: add scratch sound
end

function onPlayAgainBtnRelease ( event )
    print("play again!")
    storyboard.reloadScene()
--    storyboard.gotoScene( "menu", "fade", 500 )
end

-- Called immediately after scene has moved onscreen:
function scene:enterScene( event )
	local group = self.view

    if(debug) then physics.setDrawMode( "hybrid" ) end

    physics.start()
    paused = false
    pauseScreen.isVisible, pauseText.isVisible = false, false

    scoreBoardScreen.isVisible, scoreBoardText.isVisible = false, false

    menuBtn.isVisible, pauseBtn.isVisible = true, true
    playAgainBtn.isVisible = false

    physics.setGravity(0,0)

    -- Set scores
    score1, score2 = 0, 0
    scoreText1.text, scoreText2.text = score1, score2

    -- Add walls
    local topWall = display.newRect(0,0,screenW, 23)
    local bottomWall = display.newRect(0,0,screenW, 23)
    local leftWall = display.newRect(0,0, leftPlayerX, screenH)
    local rightWall = display.newRect(0,0, leftPlayerX, screenH)

    -- clockwise...
    local triangle = display.newImage("ball.png")
    triangle.isVisible = false
    local triangleShape = { 0,80, 0,0, 104,0 }
    triangle.x, triangle.y = 20, 20
    physics.addBody(triangle, {shape = triangleShape, density= objectDensity, friction=0.3, bounce= objectBounce })
    triangle.bodyType = "static"

    local triangleTR = display.newImage("ball.png")
    triangleTR.isVisible = false
    local triangleTRShape = { 0,0, 104,0 , 104,80 }
    triangleTR.x, triangleTR.y = screenW - 140, 10
    physics.addBody(triangleTR, {shape = triangleTRShape, density= objectDensity, friction=0.3, bounce= objectBounce })
    triangleTR.bodyType = "static"
    
    local triangleBR = display.newImage("ball.png")
    triangleBR.isVisible = false
    local triangleBRShape = { 0, 80 , 104,0 , 104,80 }
    triangleBR.x, triangleBR.y = screenW - 140, screenH - 90
    physics.addBody(triangleBR, {shape = triangleBRShape, density= objectDensity, friction=0.3, bounce= objectBounce })
    triangleBR.bodyType = "static" 
    
    local triangleBL = display.newImage("ball.png")
    triangleBL.isVisible = false
    local triangleBLShape = { 0,0, 104,80 , 0, 80 }
    triangleBL.x, triangleBL.y = 30, screenH - 90
    physics.addBody(triangleBL, {shape = triangleBLShape, density= objectDensity, friction=0.3, bounce= objectBounce })
    triangleBL.bodyType = "static"

    bottomWall:setReferencePoint(display.BottomLeftReferencePoint)
    bottomWall.x, bottomWall.y = 0, screenH

    rightWall:setReferencePoint(display.CenterLeftReferencePoint)
    rightWall.x = rightPlayerX

    physics.addBody( topWall, "static" )
    physics.addBody(bottomWall, "static")
    physics.addBody(leftWall, "static")
    physics.addBody(rightWall, "static")

    walls:insert(topWall)
    walls:insert(bottomWall)
    walls:insert(leftWall)
    walls:insert(rightWall)
    walls:insert(triangle)
    walls:insert(triangleTR)
    walls:insert(triangleBL)
    walls:insert(triangleBR)

    topWall.isVisible = false
    bottomWall.isVisible = false
    leftWall.isVisible = false
    rightWall.isVisible = false

    -- Add players
--    leftPlayer = display.newCircle(leftPlayerX, leftPlayerY, playerRadius)
    leftPlayer = display.newImageRect("cannon.png", 50,73)
    leftPlayer.x = leftPlayerX
    leftPlayer.y = leftPlayerY
    leftPlayer.rotation = 90

    rightPlayer = display.newImageRect("cannon.png", 50,73)
    rightPlayer.x = rightPlayerX
    rightPlayer.y = rightPlayerY
    rightPlayer.rotation = -90

    leftPlayer.name = "left"
    rightPlayer.name = "right"

    -- Modify touch rects
    leftPlayerTouchRect.player = leftPlayer
    rightPlayerTouchRect.player = rightPlayer

    -- Player shooting state
    leftPlayer.isShooting, rightPlayer.isShooting = false, false
    leftPlayer.shootingX, leftPlayer.shootingY, rightPlayer.shootingX, rightPlayer.shootingY = 0,0,0,0
    leftPlayer.timeLastShot, rightPlayer.timeLastShot = 0, 0
    leftPlayer.rightNeg = 1
    rightPlayer.rightNeg = -1

    players:insert(leftPlayer)
    players:insert(rightPlayer)

    -- Add objects
    local crate = display.newImageRect( "crate.png", objectSize, objectSize )
    crate.x, crate.y = halfW, screenH / 4
    crate.rotation = 15
    physics.addBody( crate, { density= objectDensity, friction=0.3, bounce= objectBounce } )
    objects:insert(crate)
    
    local crate2 = display.newImageRect( "crate.png", objectSize, objectSize )
    crate2.x, crate2.y = halfW, 2 * screenH / 4
    crate2.rotation = 15
    physics.addBody( crate2, { density= objectDensity, friction=0.3, bounce= objectBounce } )
    objects:insert(crate2)
    
    local crate3 = display.newImageRect( "crate.png", objectSize, objectSize )
    crate3.x, crate3.y = halfW, 3 * screenH / 4
    crate3.rotation = 15
    physics.addBody( crate3, { density= objectDensity, friction=0.3, bounce= objectBounce } )
    objects:insert(crate3)

    -- Call the gameLoop function every frame (i.e., 30 times per second)
    Runtime:addEventListener("enterFrame", gameLoop)
end

function scored(player)
    if player == leftPlayer then
        score1 = score1 + 1
    elseif player == rightPlayer then
        score2 = score2 + 1
    end

    audio.play(scoreSound)

    scoreText1.text, scoreText2.text = score1, score2
end

-- Called when scene is about to move offscreen:
function scene:exitScene( event )
	local group = self.view
	
	physics.stop()

    -- Remove all game play pieces
    scene:removeAllPlayers( )
    Runtime:removeEventListener("enterFrame", gameLoop)
end

function scene:removeAllPlayers( )
    -- backwards iteration; useful for removing objects manually
    for i=players.numChildren,1,-1 do
        local child = players[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
    for i=bullets.numChildren,1,-1 do
        local child = bullets[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
    for i=objects.numChildren,1,-1 do
        local child = objects[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
    for i=walls.numChildren,1,-1 do
        local child = walls[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
    for i=trophiesLeft.numChildren,1,-1 do
        local child = trophiesLeft[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
    for i=trophiesRight.numChildren,1,-1 do
        local child = trophiesRight[i]
        -- Maybe perform a scoring operation here
        child:removeSelf()
    end
end

-- If scene's view is removed, scene:destroyScene() will be called just prior to:
function scene:destroyScene( event )
	local group = self.view
	
	package.loaded[physics] = nil
	physics = nil
end


-- Display the Event info on the screen
local function showEvent( event )
    print( "Phase: " .. event.phase)
    print( "(" .. event.x .. "," .. event.y .. ")")
    print("Id: " .. tostring( event.id ) )
end

-- Handle player touch area events
local function onTouch( event )
    local t = event.target
    showEvent( event )

    local player = t.player

    local phase = event.phase

    if "began" == phase then
        player.isShooting = true
    elseif "moved" == phase then
        -- x/y movement is always recorded
    elseif "ended" == phase or "cancelled" == phase then
        player.isShooting = false
    end

    -- set location of press
    player.shootingX, player.shootingY = event.x, event.y

    print("Player is " .. player.shootingX .. player.shootingY)

    local playerCoords = {x = player.x, y = player.y }
    local mouseCoords = { x = player.shootingX, y = player.shootingY }
    player.rotation = angleBetweenPoints(playerCoords, mouseCoords) + 90

    return false -- return false, continue propagating touch
end

leftPlayerTouchRect:addEventListener("touch", onTouch)
rightPlayerTouchRect:addEventListener("touch", onTouch)

-----------------------------------------------------------------------------------------
-- END OF YOUR IMPLEMENTATION
-----------------------------------------------------------------------------------------

-- "createScene" event is dispatched if scene's view does not exist
scene:addEventListener( "createScene", scene )

-- "enterScene" event is dispatched whenever scene transition has finished
scene:addEventListener( "enterScene", scene )

-- "exitScene" event is dispatched whenever before next scene's transition begins
scene:addEventListener( "exitScene", scene )

-- "destroyScene" event is dispatched before view is unloaded, which can be
-- automatically unloaded in low memory situations, or explicitly via a call to
-- storyboard.purgeScene() or storyboard.removeScene().
scene:addEventListener( "destroyScene", scene )


-----------------------------------------------------------------------------------------

return scene