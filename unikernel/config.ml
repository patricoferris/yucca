open Mirage

(* Keys *)
let port =
  let doc =
    Key.Arg.info ~doc:"Port number for HTTP (defaults to 8000)" ~docv:"PORT"
      [ "port" ]
  in
  Key.(create "port" Arg.(opt ~stage:`Both int 8000 doc))

let tls_port =
  let doc =
    Key.Arg.info ~doc:"Port number for HTTPS" ~docv:"PORT" [ "https-port" ]
  in
  Key.(create "https-port" Arg.(opt ~stage:`Both (some int) None doc))

let git_remote =
  let doc = Key.Arg.info ~doc:"Git remote URI" [ "git-remote" ] in
  Key.(
    create "git-remote"
      Arg.(
        opt ~stage:`Both string "https://github.com/patricoferris/___blog.git"
          doc))

let tls_key = Key.(value @@ kv_ro ~group:"certs" ())

let fs_key = Key.(value @@ kv_ro ~group:"static" ())

let host_key =
  let doc =
    Key.Arg.info ~doc:"Hostname of the unikernel." ~docv:"URL" ~env:"HOST"
      [ "host" ]
  in
  Key.(create "host" Arg.(opt string "localhost" doc))

let keys =
  Key.
    [ abstract host_key; abstract port; abstract tls_port; abstract git_remote ]

let packages =
  [
    package "httpaf";
    package "irmin";
    package "irmin-mirage-git";
    package "irmin-mirage-graphql";
    package "ptime";
    (* For markdown to JSON transform *)
    package "yaml";
    package "ezjsonm";
    package "re";
    package "omd";
    package ~min:"2.0.0" "mirage-kv";
  ]

(********* Setting up implementations *********)
let stack = generic_stackv4 default_network

let cond_tls = conduit_direct ~tls:true stack

let resolver = resolver_dns stack

let static = generic_kv_ro ~key:fs_key "./static"

let secrets = generic_kv_ro ~key:tls_key "./secrets"

(******** MAIN FUNCTIONS *********)
let main =
  foreign ~keys ~packages "Yucca.Make"
    (http
    @-> kv_ro
    @-> kv_ro
    @-> Mirage.resolver
    @-> Mirage.conduit
    @-> pclock
    @-> job)

let () =
  let tls_server = cohttp_server @@ conduit_direct ~tls:true stack in
  register "yucca"
    [
      main
      $ tls_server
      $ static
      $ secrets
      $ resolver
      $ cond_tls
      $ default_posix_clock;
    ]
