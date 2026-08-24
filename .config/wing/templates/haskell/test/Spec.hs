module Main (main) where

import Control.Monad (unless)
import {{PascalName}} (greeting)
import System.Exit (exitFailure)

main :: IO ()
main = do
  unless (greeting == "hello from {{kebab_name}}") exitFailure
  putStrLn "ok"
