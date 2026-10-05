-- The web, as the launcher reaches it: the search engines (each with a
-- bang: `?gh morf` searches GitHub), opening an address in $BROWSER, and
-- telling an address from a search.

local morf = require("morf")

local M = {}

M.ENGINES = {
  { id = "duckduckgo", bang = "d", name = "DuckDuckGo", url = "https://duckduckgo.com/?q=%s" },
  { id = "google", bang = "g", name = "Google", url = "https://www.google.com/search?q=%s" },
  { id = "github", bang = "gh", name = "GitHub", url = "https://github.com/search?q=%s" },
  { id = "youtube", bang = "yt", name = "YouTube", url = "https://www.youtube.com/results?search_query=%s" },
  { id = "wikipedia", bang = "w", name = "Wikipedia", url = "https://en.wikipedia.org/w/index.php?search=%s" },
  { id = "archwiki", bang = "aw", name = "ArchWiki", url = "https://wiki.archlinux.org/index.php?search=%s" },
  { id = "aur", bang = "aur", name = "AUR", url = "https://aur.archlinux.org/packages?K=%s" },
  { id = "archpkg", bang = "arch", name = "Arch packages", url = "https://archlinux.org/packages/?q=%s" },
  { id = "crates", bang = "cr", name = "crates.io", url = "https://crates.io/search?q=%s" },
  { id = "docsrs", bang = "rs", name = "docs.rs", url = "https://docs.rs/releases/search?query=%s" },
  { id = "nixpkgs", bang = "nix", name = "Nix packages", url = "https://search.nixos.org/packages?query=%s" },
  { id = "flathub", bang = "fh", name = "Flathub", url = "https://flathub.org/apps/search?q=%s" },
  { id = "stackoverflow", bang = "so", name = "Stack Overflow", url = "https://stackoverflow.com/search?q=%s" },
  { id = "reddit", bang = "r", name = "Reddit", url = "https://www.reddit.com/search/?q=%s" },
  { id = "pkgs", bang = "pkg", name = "pkgs.org", url = "https://pkgs.org/search/?q=%s" },
  { id = "maps", bang = "m", name = "Maps", url = "https://www.openstreetmap.org/search?query=%s" },
  { id = "translate", bang = "tr", name = "Translate", url = "https://translate.google.com/?sl=auto&tl=en&text=%s" },
}

function M.engine(id_or_bang)
  for _, e in ipairs(M.ENGINES) do
    if e.id == id_or_bang or e.bang == id_or_bang then return e end
  end
  return nil
end

function M.search_url(engine, query)
  return (engine.url:gsub("%%s", function() return morf.http.url_encode(query) end))
end

--- Whether `text` reads as an address rather than words to search for.
function M.is_address(text)
  return text:match("^https?://%S+$") ~= nil or text:match("^[%w%-]+%.[%a][%a]+[%S]*$") ~= nil
end

function M.address(text)
  return text:match("^https?://") and text or ("https://" .. text)
end

function M.browser() return (morf.env and morf.env("BROWSER")) or "xdg-open" end

return M
