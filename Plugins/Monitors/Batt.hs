-----------------------------------------------------------------------------
-- |
-- Module      :  Plugins.Monitors.Batt
-- Copyright   :  (c) Andrea Rossato
-- License     :  BSD-style (see LICENSE)
-- 
-- Maintainer  :  Andrea Rossato <andrea.rossato@unibz.it>
-- Stability   :  unstable
-- Portability :  unportable
--
-- A battery monitor for Xmobar
--
-----------------------------------------------------------------------------

module Plugins.Monitors.Batt where

import qualified Data.ByteString.Lazy.Char8 as B
import qualified Data.Map as M
import Data.Maybe
import Data.Either
import Control.Monad
import Text.ParserCombinators.Parsec
import System.Posix.Files

import Plugins.Monitors.Common

type BattMap = M.Map String Integer

battConfig :: IO MConfig
battConfig = mkMConfig
       "Batt: <left>" -- template
       ["left"]       -- available replacements

fileB1 :: (String, String)
fileB1 = ("/proc/acpi/battery/BAT1/info", "/proc/acpi/battery/BAT1/state")

fileB2 :: (String, String)
fileB2 = ("/proc/acpi/battery/BAT2/info", "/proc/acpi/battery/BAT2/state")

checkFileBatt :: (String, String) -> IO Bool
checkFileBatt (i,_) =
    fileExist i

readFileBatt :: (String, String) -> IO BattMap
readFileBatt (i,s) = 
    do a <- catch (B.readFile i) (const $ return B.empty)
       b <- catch (B.readFile s) (const $ return B.empty)
       return $ mkMap a b

mkMap :: B.ByteString -> B.ByteString -> BattMap
mkMap a b = M.fromList . mapMaybe toAssoc $ concatMap B.lines [a, b]

toAssoc bs = case parse parseLine "" (B.unpack bs) of
                Left _ -> Nothing
                Right a -> Just a

parseLine = do hd <- many1 $ noneOf ":"
               char ':'
               spaces
               tl <- many1 digit
               let t = read tl
               return (hd, t)

parseBATT :: IO Float
parseBATT =
    do m1 <- readFileBatt fileB1
       m2 <- readFileBatt fileB2
       let pr1 = M.findWithDefault 0 remKey m1
           fu1 = M.findWithDefault 0 fullKey m1
           pr2 = M.findWithDefault 0 remKey m2
           fu2 = M.findWithDefault 0 fullKey m2
           pr  = pr1 + pr2
           fu  = fu1 + fu2
           pc  = if fu /= 0 then fromInteger pr / fromInteger fu else 0.0
       return pc
  where
    remKey = "remaining capacity"
    fullKey = "last full capacity"

formatBatt :: Float -> Monitor [String] 
formatBatt x =
    do let f s = floatToPercent (s / 100)
       l <- showWithColors f (x * 100)
       return [l]

runBatt :: [String] -> Monitor String
runBatt _ =
    do c <- io $ parseBATT
       l <- formatBatt c
       parseTemplate l 