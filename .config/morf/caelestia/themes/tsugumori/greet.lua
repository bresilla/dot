-- Keep the shared authentication composition; decorate it without relocating content.
return function(ctx)
  return require("themes.layouts.greet")(require("themes.tsugumori.auth_style")(ctx))
end
