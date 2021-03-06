{-# LANGUAGE DataKinds #-}
module Common where

import Test.QuickCheck
import Data.Vector.Storable as V (Vector, fromList)
--import Graphics.GL

data Int2 = I2 !Int !Int deriving Show
data Int4 = I4 !Int !Int !Int !Int deriving Show
data Float2 = F2 !Float !Float deriving (Eq,Ord,Show,Read)
data Float3 = F3 !Float !Float !Float deriving Show
data Float4 = F4 !Float !Float !Float !Float deriving Show
data Rect a = Rect !a !a !a !a
type RGB = Float3

type XYWH = Float4

newtype Glyph = Glyph Int

fi :: (Integral a, Num b) => a -> b
fi = fromIntegral

i22f2 :: Int2 -> Float2
i22f2 (I2 x y) = F2 (fi x) (fi y)

ffloor :: Double -> Double
ffloor x = fi (floor x :: Int)

{-  a01   b11
 -  c00   d10  -}
tileData :: Vector Float
tileData =
  let a = [0, 1] in
  let b = [1, 1] in
  let c = [0, 0] in
  let d = [1, 0] in
  V.fromList (concat [c,d,b,b,a,c])


  --let box = 33 + 40 * 35 + 30 + 369
  --darkbox = 33 + 40 * 35 + 29

newtype Act = Act (IO ())

instance Monoid Act where
  mempty = Act $ return ()

instance Semigroup Act where
  Act a <> Act b = Act (a >> b)

onFst :: (a -> c) -> (a,b) -> (c,b)
onFst f (x,y) = (f x, y)
onSnd :: (b -> c) -> (a,b) -> (a,c)
onSnd f (x,y) = (x,f y)

deleteAt :: Int -> [a] -> [a]
deleteAt 0 (_:xs) = xs
deleteAt i (x:xs) = x : deleteAt (i - 1) xs
deleteAt _ [] = error "index out of bounds"

insertAt :: Int -> a -> [a] -> [a]
insertAt 0 z (x:xs) = z : x : xs
insertAt i z (x:xs) = x : insertAt (i - 1) z xs
insertAt 0 z [] = [z]
insertAt _ _ [] = error "index out of bounds"

instance Num Float2 where
  F2 a b + F2 c d = F2 (a+c) (b+d)
  F2 a b - F2 c d = F2 (a-c) (b-d)
  negate (F2 a b) = F2 (negate a) (negate b)
  _ * _ = error "can't times Float2, use dot or *."
  abs _ = error "can't abs Float2"
  signum _ = error "can't signum Float2"
  fromInteger i = F2 (fromInteger i) (fromInteger i)

normalize x = x ./ norm x

-- n must be normalized
reflect :: Float2 -> Float2 -> Float2
reflect n v = v - (2 * v `dot` n) *. n

norm (F2 x y) = sqrt (x*x + y*y)
dot (F2 a b) (F2 c d) = a*c + b*d

cross2 (F2 a b) (F2 c d) = a*d - b*c

(F2 x y) ./ s = F2 (x/s) (y/s)
s *. (F2 x y) = F2 (s*x) (s*y)
(F2 x y) .* s = F2 (x*s) (y*s)

infixl 7 .*
infixl 7 *.

instance Arbitrary Float2 where
  arbitrary = do
    x <- arbitrary
    y <- arbitrary
    return (F2 x y)
