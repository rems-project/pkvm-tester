
let rec last = function [] -> None | [x] -> Some x | _::xs -> last xs

(** LLVM symbolizer's idea of symbols. *)
module Symbols = struct
  [@@@ warning "-69"]
  type symbol = {
    column: int; discriminator: int; filename: Fpath.t;
    functionname: string; line: int; startaddress: int64 option;
    startfilename: Fpath.t; startline: int
  }
  type address = { address: int64; modulename: string; symbols: symbol list }

  type opts = { demangle: string -> string; unfold_inlines: bool }
  let default_opts = { demangle = Fun.id; unfold_inlines = true }

  open Json.Q

  let int64_ =
    let f s = try Scanf.sscanf s "0x%Lx%!" (fun x -> Ok x) with
    | End_of_file | Scanf.Scan_failure _ -> Error (`Msg ("expected 0x-hex found: " ^ s))
    in
    map f string
  let int64, int64_o  = to_err int64_, map Result.to_option int64_
  let path = map Fpath.(fun s -> normalize (v s)) string
  let symbol opts =
    obj (fun column discriminator filename functionname line startaddress startfilename startline ->
      { column; discriminator; filename; line; startaddress; startfilename; startline
      ; functionname = opts.demangle functionname})
    |> mem "Column" int
    |> mem "Discriminator" int
    |> mem "FileName" path
    |> mem "FunctionName" string
    |> mem "Line" int
    |> mem "StartAddress" int64_o
    |> mem "StartFileName" path
    |> mem "StartLine" int
  let address opts = 
    obj (fun address modulename symbols -> { address; modulename; symbols })
    |> mem "Address" int64
    |> mem "ModuleName" string
    |> mem "Symbol" (array (symbol opts))
  let of_json ?(opts = default_opts) json =
    match Json.Q.query (address opts) json with
    | Error (`Msg e) -> Fmt.failwith "%s: %s" e (Json.to_string json)
    | Ok v -> v

  open Lcov

  let sym_to_info { filename; functionname = func; line; startline; startfilename; _} count  =
    (* per-function count *)
    func_hit ~file:startfilename ~startline ~func count ++
    (* LCOV needs the first line of the function to have _something_ *)
    (if (filename <> startfilename || line <> startline) then
      line_hit ~file:startfilename ~line:startline count
      else no_info) ++
    (* per-line count, if the line was found *)
    (match line with 0 -> no_info | _ -> line_hit ~file:filename ~line:line count)
  let to_info ?(opts = default_opts) (addr, count) =
    match opts.unfold_inlines with
    | true ->
        List.fold_left (fun i s -> i ++ sym_to_info s count) no_info addr.symbols
    | false ->
        last addr.symbols
        |> Option.fold ~none:no_info ~some:(fun s -> sym_to_info s count)
  let to_infos ?opts = Iters.fold (fun i a -> i ++ to_info ?opts a) no_info
end

let bracket ~release v f =
  Fun.protect (fun () -> f v) ~finally:(fun () -> release v)

module Read = struct
  let in_file path f = Iters.of_iter @@ fun it ->
    let ic = open_in path in
    Fun.protect (fun () -> Iters.iter it (f ic)) ~finally:(fun () -> close_in ic)
  let out_file path = bracket (open_out path) ~release:close_out
  let lines ic =
    let rec go it = match input_line ic with
    | exception End_of_file -> ()
    | line -> it line; go it in
    Iters.of_iter go
  let is_white = String.for_all (function ' '|'\t'|'\r'|'\n' -> true | _ -> false)
  let jsons ?(buf = 4096) ic =
    let ibuf = Bytes.create buf in
    let rec go suff it =
      match Json.of_string_prefix suff with
      | Ok (json, suff) ->
          it json;
          go suff it
      | Error (`Msg e) ->
          match input ic ibuf 0 buf with
          | 0 -> if not (is_white suff) then invalid_arg e
          | n -> go (suff ^ Bytes.sub_string ibuf 0 n) it
    in
    Iters.of_iter (go "")
  let llvm_symbols ?opts ic =
    jsons ic |> Iters.map (Symbols.of_json ?opts)
  let kcov ic =
    let of_line line = try Scanf.sscanf line "0x%Lx %d%!" (fun a b -> a, b) with
    | End_of_file | Scanf.Scan_failure _ -> Fmt.invalid_arg "KCOV: expecting ‘0x%%Lx %%d’ got: %s" line
    in
    lines ic |> Iters.map of_line
end

let pp_process_status ppf = function
| Unix.WEXITED n -> Fmt.pf ppf "WEXITED %d" n
| Unix.WSIGNALED n -> Fmt.pf ppf "WSIGNALED %d" n
| Unix.WSTOPPED n -> Fmt.pf ppf "WSTOPPED %d" n

let process_success = function
| Unix.WEXITED 0 -> ()
| st -> Fmt.failwith "process: %a" pp_process_status st

let strip_prefix ~prefix s =
  if String.starts_with ~prefix s then
    let n = String.length prefix in
    String.(sub s n (length s - n))
  else s

let demangle__kvm_nvhe = strip_prefix ~prefix:"__kvm_nvhe_" 

let llvm_symbolizer ?opts ~exe addrs = Iters.of_iter @@ fun it ->
  let ic, oc =
    Unix.open_process_args "llvm-symbolizer"
    [| "llvm-symbolizer"; "--output-style"; "JSON"; "--exe"; exe |]
  in
  let th = Domain.spawn @@ fun () ->
    Iters.iter it (Read.llvm_symbols ?opts ic) in
  Fmt.pf (Format.formatter_of_out_channel oc) "@[<v>%a@]@."
    Fmt.(iter ~sep:cut Iters.iter (fmt "0x%Lx")) addrs;
  close_out oc;
  Domain.join th;
  Unix.close_process (ic, oc) |> process_success

module Amap = struct
  include Map.Make(Int64)
  let find_def ~default k m = find_opt k m |> Option.value ~default
end

let addr2lcov ?opts ~exe kcov =
  let add m (addr, cnt) = Amap.(add addr (cnt + find_def addr m ~default:0)) m in
  let kmap = Iters.fold add Amap.empty kcov in
  let cover = Iters.(ii Amap.iter kmap |> map fst) in
  llvm_symbolizer ?opts ~exe cover
    |> Iters.map (fun s -> s, Amap.find s.Symbols.address kmap)
    |> Symbols.to_infos ?opts

let main ?(inln = true) ~exe ?out srcs =
  let kcov = match srcs with
  | [] -> Read.kcov stdin
  | srcs -> Iters.(of_list srcs |> map (Fun.flip Read.in_file Read.kcov) |> join)
  in
  let info = addr2lcov kcov ~exe ~opts:{
    demangle = demangle__kvm_nvhe;
    unfold_inlines = inln;
  } in
  let pr ppf = Fmt.pf ppf "%a@." Lcov.pp_info info in
  match out with
  | None -> pr Fmt.stdout
  | Some out ->
      Read.out_file out @@ fun oc -> pr (Format.formatter_of_out_channel oc)

open Cmdliner

let ($$) f a = Term.(const f $ a)

let info = Cmd.info "addr2lcov"
  ~doc:"Convert KCOV addresses to LCOV trace files"
  ~man:[
    `S "KCOV format"
  ; `P "$(mname) consumes an informal KCOV format. Each line in a KCOV file has \
       an address, in hex, and a count, in decimal, separated by space. E.g."
  ; `Pre "0xcafebabe 42"
  ; `P "The address is the PC address, and the count is the number of \
       occurrences (hits). A single address can be mentioned by more than one \
       line, in which case the counts are aggregated. No other data can be \
       present."
  ]
let term =
  let open Arg in
  let exe = required @@ opt (some non_dir_file) None @@ info ["exe"]
            ~docv:"OBJ"
            ~doc:"Path to object file to analyse for symbols."
  and out = value @@ opt (some string) None @@ info ["o"; "out"]
            ~docv:"TRACEFILE"
            ~doc:"Path to LCOV trace file (.info) to output. Outputs to stdout if missing." 
  and src = value @@ pos_all non_dir_file [] @@ info []
            ~docv:"KCOV"
            ~doc:"KCOV dump file(s) to convert. Any number of files can be \
                  given, as counts are aggregated. Inputs from stdin if missing."
  and inln = value @@ opt bool true @@ info ["i"; "inlines"]
             ~docv:"BOOL"
             ~doc:"Attribute each hit to the stack of inlines ($(b,true)) or \
                  just the outermost function ($(b,false))."
  in
  Term.((fun exe inln out -> main ~exe ?out ~inln)
    (* $$ (Logs.set_level ~all:true $$ Logs_cli.level ()) *)
    $$ exe $ inln $ out $ src)

let _ =
  Fmt_tty.setup_std_outputs ();
  (* Logs.set_reporter (Logs_fmt.reporter ()); *)
  Cmd.v info term |> Cmd.eval
