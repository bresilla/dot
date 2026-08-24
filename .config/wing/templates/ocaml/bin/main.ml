let usage = "{{PROJECT_NAME}}\n\nUsage:\n  {{kebab_name}} [--help] [--version]"

let () =
  let args = Array.to_list Sys.argv |> List.tl in
  match args with
  | ("-h" | "--help") :: _ -> print_endline usage
  | ("-V" | "--version") :: _ -> print_endline {{Snake_name}}.version
  | _ -> print_endline ({{Snake_name}}.greeting ())
