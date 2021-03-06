module Ticks where

import Data.IORef
import System.Clock

getCurrentTick :: Integer -> IO Int
getCurrentTick t0 = do
  t <- fmap toNanoSecs (getTime Monotonic)
  let timeNs = t - t0
  let tickPerSec = 60
  let nanoPerSec = 1000000000
  let (tick,r) = (timeNs * tickPerSec) `divMod` nanoPerSec
  --print ["t0="++show t0, "t="++show t, "tick="++show tick, "r="++show r]
  return (fromIntegral tick)

newTicker :: IO (IO Int)
newTicker = do
  t0 <- fmap toNanoSecs (getTime Monotonic)
  return (getCurrentTick t0)

-- returns milliseconds
stopwatch :: IO a -> IO (a, Double)
stopwatch action = do
  t0 <- fmap toNanoSecs (getTime Monotonic)
  x <- action
  t1 <- fmap toNanoSecs (getTime Monotonic)
  return (x, fromIntegral (t1 - t0) / 1e6)
