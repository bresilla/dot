module Main (main) where

import {{PascalName}} (greeting)
import System.Environment (getArgs)

-- | Mirrors the version in the cabal file. Cabal is the one place that holds it; this is what
-- @--version@ prints.
version :: String
version = "0.1.0"

usage :: String
usage =
  unlines
    [ "{{PROJECT_NAME}}",
      "",
      "Usage:",
      "  {{kebab_name}} [--help] [--version]"
    ]

main :: IO ()
main = do
  args <- getArgs
  case args of
    (flag : _) | flag `elem` ["-h", "--help"] -> putStr usage
    (flag : _) | flag `elem` ["-V", "--version"] -> putStrLn version
    _ -> putStrLn greeting
