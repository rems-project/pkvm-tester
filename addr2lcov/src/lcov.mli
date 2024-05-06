type record =
| TestName of string
  (** TN:<test name> *)
| SourceFile of string
  (** SF:<path to the source file> *)
| FunctionName of { name: string; start_line: int; end_line: int option }
  (** FN:<line number of function start>,[<line number of  function end>,]<function name> *)
| FunctionData of { name: string; count: int }
  (** FNDA:<execution count>,<function name> *)
| FunctionsFound of int
  (** FNF:<number of functions found> *)
| FunctionsHit of int
  (** FNH:<number of function hit> *)
| BranchData of { line: int; block: int; branch: int; taken: int option }
  (** BRDA:<line_number>,[<exception>]<block>,<branch>,<taken> *)
| BranchesFound of int
  (** BRF:<number of branches found> *)
| BranchesHit of int
  (** BRH:<number of branches hit> *)
| LineData of { line: int; count: int; checksum: string option }
  (** DA:<line number>,<execution count>[,<checksum>] *)
| LinesFound of int
  (** LF:<number of instrumented lines> *)
| LinesHit of int
  (** LH:<number of lines with a non-zero execution count> *)
| EndOfRecord
  (** end_of_record *)

val pp_record : record Fmt.t

type info

val no_info : info
val (++) : info -> info -> info

val line_hit : file:Fpath.t -> line:int -> int -> info
(** [line_hit ~file ~line count] records [count] execution hits on the line
    [line] of file [file]. *)

val func_hit : file:Fpath.t -> func:string -> startline:int -> int -> info
(** [func_hit ~file ~func ~startline count] records [count] execution hits of
    the function [func] defined in [file], starting at [startline]. *)

val to_records : info -> record Iters.t
val pp_info : info Fmt.t
