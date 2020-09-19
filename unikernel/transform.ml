let log_src = Logs.Src.create "yucca.transformer" ~doc:"server"

module Log = (val Logs.src_log log_src : Logs.LOG)

let extract_frontmatter content =
  Re.Str.bounded_split (Re.Str.regexp "---") content 2

let replace_all f s =
  let rec aux str =
    let new_str = f str in
    if String.equal new_str str then new_str else aux new_str
  in
  aux s

let markdown_to_json md =
  match extract_frontmatter md with
  | [ meta; content ] ->
      let meta_json =
        match Yaml.yaml_of_string meta with
        | Ok value -> (
            match Yaml.to_json value with
            | Ok json -> Ezjsonm.(to_string (wrap json))
            | Error _ -> failwith "Frontmatter Conversion"
            | Error _ -> failwith "Frontmatter Conversion")
        | Error _ ->
            Log.err (fun f -> f "Failed to generate json bundle");
            failwith "Error"
      in
      let f = Re.Str.(replace_first (regexp "\"") "'") in
      let newline = Re.Str.(replace_first (regexp "\n") "\\\\\\n") in
      let html =
        replace_all f Omd.(to_html (of_string content)) |> replace_all newline
      in
      let meta = Ezjsonm.(value_to_string (string meta_json)) in
      let meta = String.sub meta 1 (String.length meta - 2) in
      let json =
        try
          "\"{ \\\"frontmatter\\\":"
          ^ meta
          ^ ", \\\"html\\\": \\\""
          ^ html
          ^ "\\\" } \""
        with _ ->
          Log.err (fun f -> f "Failed to generate json bundle");
          failwith "Error"
      in
      json
  | _ ->
      Log.err (fun f -> f "Bad Parse of Frontmatter");
      failwith "Error"
