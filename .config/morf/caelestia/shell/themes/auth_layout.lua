-- Geometry shared by lock and greet; role-specific content stays in their
-- controllers and layouts, while the visual scale and clock stay identical.
return function(W,H,s)
  local short=H<s(500)
  return {
    border=s(10),round=s(25),short=short,
    sheet_width=math.min(s(600),W-2*s(20)),
    avatar=s(96),field_width=math.min(s(380),math.min(s(600),W-2*s(20))-s(48)),field_height=s(58),
    clock_y=math.floor(H*(short and .05 or H>W and .12 or .18)),
    clock_size=math.min(H>W and s(132) or s(160),math.floor((W-s(64))/3.4),math.floor(H*(short and .18 or .28))),
    clock_sheet_offset=s(110),
  }
end
