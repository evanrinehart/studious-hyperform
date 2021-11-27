module Common where

import Data.Vector.Storable as V (Vector, fromList)
import Graphics.GL

data Float2 = F2 !Float !Float
data Float3 = F3 !Float !Float !Float
data Rect a = Rect !a !a !a !a
type RGB = Float3

newtype Glyph = Glyph Int

white   = F3 1 1 1
black   = F3 0 0 0
red     = F3 1 0 0
yellow  = F3 1 1 0

fi :: (Integral a, Num b) => a -> b
fi = fromIntegral

{-  a01   b11
 -  c00   d10  -}
tileData :: Vector Float
tileData =
  let a = [0, 1] in
  let b = [1, 1] in
  let c = [0, 0] in
  let d = [1, 0] in
  V.fromList (concat [c,d,b,b,a,c])

data ULegend1 = UL1
  { ul1WinWH :: GLint
  , ul1SrcXY :: GLint
  , ul1SrcWH :: GLint
  , ul1DstXY :: GLint
  , ul1DstWH :: GLint }