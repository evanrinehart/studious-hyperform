{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveFunctor #-}
module Main where

import Data.IORef
import Control.Monad
import Control.Applicative
import Data.Foldable
import Data.Char
import Data.Maybe

import qualified Graphics.UI.GLFW as GLFW
--import Graphics.GL

import Common
import Glue
import Event
import Ticks
import Rainbow

import CmdLine

import CardGame


-- concentrate on getting widgets to work
-- repaint: a number of graphics resources are aquired and then needed for repainting later
-- user action: user actions must 1. map to the widget's actions 2. 
data Widget = Widget
  { --wdgArea :: Float4
--  , depth :: Int -- auto computed from stacking order
--  , hidden :: Bool
--  , myID :: Int
    widgetRepaint :: IO (),
    widgetCanvas  :: Canvas,
    widgetActions :: UserActions (IO ()),
    widgetTime :: IO (),
    widgetFinalize :: IO (),
    widgetArea :: Float4
  }


-- the arena test widget doesn't animate, doesn't cause any side effects
-- doesn't make any external requests
makeArena :: GFX -> Float4 -> IO Widget
makeArena gfx (F4 x y w h) = do
  -- gfx resources
  canvas <- newCanvas (floor w) (floor h)
  (sheet,_) <- loadTextureFromFile "dungeon.png"

  -- initial state data
  let deck = map (\i -> let (x,y) = divMod i 13 in Card i (F4 (fi x * 32 - 160) (fi y * 32 - 240) 32 32) True) [0..168]

  -- evil mutable variables
  var1 <- newIORef deck
  var2 <- newIORef (F2 0 0)

  -- action wrapper maps "arena actions" to/from user actions properly
  let shift (F2 mx my) = F2 (mx - (x + w/2)) (my - (y + h/2))

  let actionWrapper = -- some of this is common to all widgets, foo is "custom"
        shiftMouse shift .  -- shift mouse a fixed amount
        cacheMouse var2 .   -- cache mouse locations to ref, provide mouse location
        foo .            -- remap useractions to cardgame actions, always require mouse location
        cachedState var1 -- IORef s + s->s = IO ()  (inner action API)
  let render gfx canvas sheet cards = do
        withSprites gfx sheet canvas $ \torch -> do
          forM_ (reverse cards) $ \(Card face (F4 x y w h) hidden) -> do
            torch (if hidden then 2 else face) (F2 x y)
  
  return $ Widget{
    widgetRepaint=readIORef var1 >>= render gfx canvas sheet,
    widgetCanvas=canvas,
    widgetTime=return (),
    widgetArea=F4 x y w h,
    widgetActions=actionWrapper basicGame,
    widgetFinalize=deleteCanvas canvas
  }

-- cache any mouse motion, then provide it to the wrapped actions
cacheMouse :: IORef Float2 -> UserActions (Float2 -> IO ()) -> UserActions (IO ())
cacheMouse ref actionf = action{uaMouse = g} where
  action = fmap h actionf
  h f = do
    xy <- readIORef ref
    f xy
  g x y = do
    writeIORef ref (F2 x y)
    uaMouse action x y


  
  

blitWidget :: GFX -> Widget -> IO ()
blitWidget gfx wid = let F4 x y _ _ = widgetArea wid in blitCanvas gfx (widgetCanvas wid) (F2 x y)

-- the debugger holds resources:
--   a canvas (texture, fbo)
--   an ioref with the current state

makeDebugger gfx = do
  canvas <- newCanvas 320 480
  var <- newIORef (0,"")
  return $ Widget{
    widgetCanvas=canvas,
    widgetFinalize=deleteCanvas canvas,
    widgetArea=F4 (-320) (-240) 320 480,
    widgetTime=return (),
    widgetRepaint=do
      (cur,buf) <- readIORef var

      useFBO (canvasFbo canvas)
      clearColorBuffer 1 1 1
      useFBO (FBO 0)

      let white = F3 1 1 1
      let black = F3 0 0 0

      withFont gfx canvas $ \torch -> do
        forM_ (zip [0..] (buf ++ " ")) $ \(i,c) -> do
          if cur==i
            then torch c white black (I2 i 36)
            else torch c black white (I2 i 36),
    widgetActions=
      cacheStateDoMsg var (fromMaybe (return ()) . fmap print) cmdLine
  }




data MainLoop = MainLoop
  { mlClock :: IO Int
  , mlDoEvents :: IO ()
  , mlDead :: IO Bool
  , mlRender :: IO ()
  , mlDoTick :: IO ()
  }

mainLoop :: MainLoop -> IO ()
mainLoop md = mlClock md >>= loop where
  loop prev = do
    mlDoEvents md

    now <- mlClock md
    let delta = now - prev
    replicateM_ delta (mlDoTick md)

    mlRender md

    dead1 <- mlDead md
    let dead2 = False
    when (not (dead1 || dead2)) (loop now)


mainAction win arena debugger = root (pair a b) where
  root = globalMouseTranslator win . quitter win
  a = blockKeyboard noop (widgetActions arena)
  b = blockMouse noop (widgetActions debugger)
  noop = return ()

main = do
  let scale = 1
  -- let there be a window plus graphics
  (win,gfx) <- rainbow "o_O" (floor logicalW) (floor logicalH) scale -- create window load graphics

  debugger <- makeDebugger gfx
  arena    <- makeArena gfx (F4 (-320) (-240) 640 480)
  --anim     <- makeAnimation gfx

--  masterActionVar <- newIORef undefined
--  writeIORef masterActionVar act

  -- let there be a connection between the user and... something
  jackIn win (mainAction win arena debugger)

  -- a clock used by the main loop
  ticker <- newTicker

    --blitCanvas gfx canvas (F2 0 (-240))

  mainLoop $ MainLoop{
    mlClock=ticker,
    mlDoEvents=GLFW.pollEvents,
    mlDoTick=do
      widgetTime debugger
      widgetTime arena,
    mlRender=do
      clearColorBuffer 0 1 0
      widgetRepaint debugger
      widgetRepaint arena
      blitWidget gfx debugger
      blitWidget gfx arena
      GLFW.swapBuffers win,
    mlDead=GLFW.windowShouldClose win
  }


{-
masterAction :: IORef (UserActions (IO ())) -> UserActions (IO ())
masterAction var = UserActions
  { uaKeydown  = (\x y -> readIORef var >>= \z -> uaKeydown z x y)
  , uaKeyup    = (\x y -> readIORef var >>= \z -> uaKeyup z x y)
  , uaKeyagain = (\x y -> readIORef var >>= \z -> uaKeyagain z x y)
  , uaTyping   = (\x ->   readIORef var >>= \z -> uaTyping z x)
  , uaMouse    = (\x y -> readIORef var >>= \z -> uaMouse z x y)
  , uaClick    = (\x ->   readIORef var >>= \z -> uaClick z x)
  , uaUnclick  = (\x ->   readIORef var >>= \z -> uaUnclick z x)
  , uaScroll   = (\x y -> readIORef var >>= \z -> uaScroll z x y) }
-}

quitter :: GLFW.Window -> UserActions (IO ()) -> UserActions (IO ())
quitter win orig = orig{uaKeydown = g} where
  g key mods = do
    case key of
      KBEscape -> GLFW.setWindowShouldClose win True
      _        -> return ()
    uaKeydown orig key mods

weird :: IORef (UserActions (IO ())) -> UserActions (IO ()) -> UserActions (IO ())
weird ref orig = orig{uaKeydown = g} where
  g key mods = do
    case key of
      KBNumPlus -> writeIORef ref (pure (pure ()))
      _         -> return ()
    uaKeydown orig key mods

cacheStateDoMsg :: Functor f => IORef a -> (b -> IO ()) -> f (a -> (a,b)) -> f (IO ())
cacheStateDoMsg var send ua = fmap f ua where
  f g = do
    msg <- atomicModifyIORef' var g
    send msg

cachedState :: Functor f => IORef a -> f (a -> a) -> f (IO ())
cachedState var ua = fmap f ua where
  f g = modifyIORef' var g

planB :: a -> UserActions (Maybe a) -> UserActions a
planB d ua = fmap (fromMaybe d) ua

-- mouse actions stop here
blockMouse :: a -> UserActions a -> UserActions a
blockMouse d orig =
  let f _ = d in
  let g _ _ = d in
  orig{uaMouse=g, uaClick=f, uaUnclick=f, uaScroll=g}

-- keyboard stops here
blockKeyboard :: a -> UserActions a -> UserActions a
blockKeyboard d orig =
  let f _ = d in
  let g _ _ = d in
  orig{uaTyping=f, uaKeydown=g, uaKeyup=g, uaKeyagain=g}

-- simply control two things at once
pair :: UserActions (IO ()) -> UserActions (IO ()) -> UserActions (IO ())
pair = liftA2 (>>)



-- glfw gives mouse coords [0,480] x [0,640] where y=0 is at the top of the window
-- we want [-320,320] x [-240,240] where 0 is in the middle of the window and y=-240 is at the bottom
-- also factor in scale factor so physical size increase doesn't change these numbers
globalMouseTranslator :: GLFW.Window -> UserActions (IO ()) -> UserActions (IO ())
globalMouseTranslator win orig = orig{uaMouse = g} where
  g x y = do
    (w,h) <- GLFW.getWindowSize win
    let halfW = fi (w `div` 2)
    let halfH = fi (h `div` 2)
    let xfactor = halfW / (logicalW / 2)
    let yfactor = halfH / (logicalH / 2)
    let x' = (x - halfW) / xfactor
    let y' = (halfH - y) / yfactor
    --print ((x,y),(x',y'))
    uaMouse orig x' y'

logicalW = 640
logicalH = 480



-- each widget needs their mouse positions shifted according to canvas location
shiftMouse :: (Float2 -> Float2) -> UserActions (IO ()) -> UserActions (IO ())
shiftMouse f orig = orig{ uaMouse = g } where
  g x y = do
    let F2 x' y' = f (F2 x y)
    uaMouse orig x' y'


{-
if actions at some point are directed to "all widgets in this box"
and the renderer looks at "all widgets in this box"
and resources for a widget are only referenced through the widget

then you can add and remove widgets by modifying the box
-}
