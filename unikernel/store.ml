open Lwt.Infix

(* Unfortunately Irmin-mirage-grapqhl only exposes a way to make a server.
     This means we have to copy how they make it and expose more of the server *)

(* Copied from https://github.com/mirage/irmin/blob/master/src/irmin-mirage/graphql/irmin_mirage_graphql.ml *)
module GraphqlMake
    (Http : Cohttp_lwt.S.Server)
    (Store : Irmin.S with type Private.Sync.endpoint = Git_mirage.endpoint)
    (Pclock : Mirage_clock.PCLOCK) =
struct
  module Store = Store
  module Pclock = Pclock
  module Http = Http

  let init () =
    let module Config = struct
      let info ?(author = "irmin-graphql") fmt =
        let module I = Irmin_mirage.Info (Pclock) in
        I.f ~author fmt

      let remote =
        Some
          (fun ?headers uri ->
            let e = Git_mirage.endpoint ?headers (Uri.of_string uri) in
            Store.E e)
    end in
    (module Irmin_graphql.Server.Make (Http) (Config) (Store)
    : Irmin_graphql.Server.S
      with type server = Http.t
       and type repo = Store.repo)

  let execute_request repo =
    let (module G) = init () in
    Lwt.return (G.schema repo) >>= fun schema ->
    let response req body =
      G.execute_request schema req body >>= function
      | `Response resp -> Lwt.return resp
      | `Expert _ -> failwith "Not a response"
    in
    Lwt.return response

  let start ~http store =
    let (module G) = init () in
    let server = G.v store in
    http server
end

module Make (Ser : Cohttp_lwt.S.Server) (C : Mirage_clock.PCLOCK) = struct
  module Store = Irmin_mirage_git.Mem.KV (Irmin.Contents.String)
  module Sync = Irmin.Sync (Store)
  module Graphql_S = GraphqlMake (Ser) (Store) (C)
  module Info = Irmin_mirage.Info (C)

  let log_src = Logs.Src.create "rory.store" ~doc:"server"

  module Log = (val Logs.src_log log_src : Logs.LOG)

  type git_store = { store : Store.t; remote : Irmin.remote }

  let err fmt = Fmt.kstrf failwith fmt

  let concat ss = String.concat "/" ss

  let info message = Info.f ~author:"Yucca" "%s" message

  let content_read store name =
    Store.find store name >|= function
    | Some data -> data
    | None -> err "%s" ("Could not find: " ^ concat name)

  (* Transform the data *)
  let transform k pred f msg repo =
    Store.of_branch repo "trunk" >>= fun t ->
    Store.list t k >|= fun lst ->
    Lwt_list.iter_s
      (fun (step, kind) ->
        Lwt.return (Log.info (fun f -> f "Mutating: %s" step)) >>= fun _ ->
        match kind with
        | `Contents -> (
            Store.find t (k @ [ step ]) >>= function
            | Some content ->
                Log.info (fun f -> f "%s" content);
                if pred step then (
                  Store.of_branch repo "data" >>= fun d ->
                  Store.set d
                    (Store.Key.v (k @ [ step ]))
                    (f content) ~info:(info msg)
                  >>= function
                  | Ok _ ->
                      Log.info (fun f -> f "Successfully transformed data");
                      Lwt.return ()
                  | Error (`Conflict msg) ->
                      Log.info (fun f -> f "Conflict: %s" msg);
                      Lwt.return ()
                  | Error _ ->
                      Log.info (fun f -> f "Something went wrong");
                      Lwt.return ())
                else (
                  Log.info (fun f -> f "Pred unsatisfied: %s" step);
                  Lwt.return ())
            | None ->
                Log.info (fun f -> f "No content for: %s" step);
                Lwt.return ())
        | `Node ->
            Log.info (fun f -> f "Node at: %s\n" step);
            Lwt.return ())
      lst
    >>= fun _ -> Lwt.return ()

  (* Syncing the contents of the store *)
  let sync ~resolver ~conduit ~transform =
    let uri = Key_gen.git_remote () in
    let upstream = Store.remote ~conduit ~resolver uri in
    Store.Repo.v (Irmin_mem.config ()) >>= fun repo ->
    Store.of_branch repo "trunk" >>= fun t ->
    Log.info (fun f -> f "pulling repository");
    Lwt.catch
      (fun () ->
        Sync.pull_exn t upstream `Set >|= fun _ ->
        Log.info (fun f -> f "repository pulled"))
      (fun e ->
        Log.warn (fun f -> f "failed pull %a" Fmt.exn e);
        Lwt.return ())
    >>= fun _ ->
    Log.info (fun f -> f "Mutating Repository");
    transform repo >>= fun _ -> Lwt.return { store = t; remote = upstream }

  let graphql_callback gs = Graphql_S.execute_request (Store.repo gs.store)
end
