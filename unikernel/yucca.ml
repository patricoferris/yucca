open Lwt.Infix
open Cohttp

module Make
    (S : Cohttp_lwt.S.Server)
    (FS : Mirage_kv.RO)
    (SEC : Mirage_kv.RO)
    (R : Resolver_lwt.S)
    (C : Conduit_mirage.S)
    (Clock : Mirage_clock.PCLOCK) =
struct
  let log_src = Logs.Src.create "yucca" ~doc:"server"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  module X509 = Tls_mirage.X509 (SEC) (Clock)
  module Store = Store.Make (S) (Clock)

  let concat ss = String.concat "/" ss

  let err fmt = Fmt.kstrf failwith fmt

  let get_headers hdr_type length =
    Cohttp.Header.of_list
      [
        ("content-length", string_of_int length);
        ("content-type", hdr_type);
        ("connection", "close");
      ]

  let fs_read fs filename =
    let fn = concat filename in
    FS.get fs (Mirage_kv.Key.v fn) >>= function
    | Error _ -> (
        FS.get fs (Mirage_kv.Key.v "index.html") >>= function
        | Ok body -> Lwt.return body
        | Error _ ->
            err "Tried to replace %s with index.html but couldn't find it!" fn)
    | Ok body -> Lwt.return body

  let rec static_file_handler store filename =
    fs_read store filename >>= function
    | body -> (
        match Fpath.get_ext (Fpath.v (concat filename)) with
        | ".html" ->
            let headers = get_headers "text/html" (String.length body) in
            S.respond_string ~headers ~body ~status:`OK ~flush:false ()
        | ".css" ->
            let headers = get_headers "text/css" (String.length body) in
            S.respond_string ~headers ~body ~status:`OK ~flush:false ()
        | ".jpg" ->
            let headers = get_headers "image/jpg" (String.length body) in
            S.respond_string ~headers ~body ~status:`OK ~flush:false ()
        | ".svg" ->
            let headers = get_headers "image/svg+xml" (String.length body) in
            S.respond_string ~headers ~body ~status:`OK ~flush:false ()
        | ".yml" ->
            let headers = get_headers "text/yml" (String.length body) in
            S.respond_string ~headers ~body ~status:`OK ~flush:false ()
        | _ -> static_file_handler store [ "index.html" ])

  let sync_success () =
    let body = "Data synced!" in
    let headers =
      Cohttp.Header.of_list
        [ ("content-length", string_of_int (String.length body)) ]
    in
    S.respond_string ~headers ~body ~status:`OK ~flush:false ()

  let router fs gql gs resolver conduit req body uri =
    match uri with
    (* Graphql Endpoint *)
    | [ "graphql" ] ->
        Log.info (fun f -> f "Graphql Request");
        fun () -> gql gs >>= fun g -> g req body
    (* Netlify CMS endpoints *)
    | [ "admin"; "" ] ->
        fun () -> static_file_handler fs [ "admin"; "index.html" ]
    | "admin" :: tl -> fun () -> static_file_handler fs uri
    | [ "config.yml" ] ->
        fun () -> static_file_handler fs [ "admin"; "config.yml" ]
    | [ "" ] | [ "/" ] | [ "index.html" ] ->
        fun () -> static_file_handler fs [ "index.html" ]
    | file -> fun () -> static_file_handler fs file

  (* ~ TLS Configurations ~ *)
  let tls_init secrets =
    X509.certificate secrets `Default >>= fun cert ->
    let configuration = Tls.Config.server ~certificates:(`Single cert) () in
    Lwt.return configuration

  let split_path path =
    let (dom :: p) = String.split_on_char '/' path in
    p

  (* Server responses *)
  let create domain router =
    let hdr = match fst domain with `Http -> "HTTP" | `Https -> "HTTPS" in
    let callback _conn req body =
      let uri = Request.uri req |> Uri.path |> split_path in
      router req body uri ()
    in
    let conn_closed (_, conn_id) =
      let cid = Cohttp.Connection.to_string conn_id in
      Log.debug (fun f -> f "[%s %s] OK, closing" hdr cid)
    in
    S.make ~callback ~conn_closed ()

  (* Data transformation *)
  let transform repo =
    Store.transform [ "blogs" ]
      (fun f -> Filename.extension f = ".md")
      (fun s -> Transform.markdown_to_json s)
      "markdown from html" repo

  let start server fs secrets resolver conduit _clock =
    let host = Key_gen.host () in
    let remote = Key_gen.git_remote () in
    Store.sync ~resolver ~conduit ~transform >>= fun gs ->
    match Key_gen.https_port () with
    | Some port ->
        (* TLS Version *)
        tls_init secrets >>= fun cfg ->
        let tls = `TLS (cfg, `TCP port) in
        let domain = (`Https, host) in
        let gql = Store.graphql_callback in
        let callback = create domain (router fs gql gs resolver conduit) in
        Log.info (fun f -> f "listening on port %d" port);
        server tls callback
    | None ->
        (* HTTP version *)
        let domain = (`Http, host) in
        let port = Key_gen.port () in
        let tcp = `TCP port in
        let gql = Store.graphql_callback in
        let callback = create domain (router fs gql gs resolver conduit) in
        Log.info (fun f -> f "listening on port %d" port);
        server tcp callback
end
