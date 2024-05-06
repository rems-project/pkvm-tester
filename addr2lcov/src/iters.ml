type +'a t = (('a -> unit) -> unit)
let ret x it = it x
let ( let* ) seq f it = seq (fun a -> f a it)
let ( let+ ) seq f it = seq (fun a -> it (f a))
let map f seq it = ( let+ ) seq f it
let join xss = let* xs = xss in xs
let nil _ = ()
let ( ++ ) xs ys it = xs it; ys it
let ( @: ) x xs it = it x; xs it
let fold f z seq =
  let acc = ref z in
  seq (fun x -> acc := f !acc x);
  !acc
let iter it seq = seq it
let i iter xs it = iter it xs
let ii iter xs it = iter (fun a b -> it (a, b)) xs
let of_list xs it = List.iter it xs
let of_iter = Fun.id
