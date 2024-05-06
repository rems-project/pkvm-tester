type +'a t
val ret : 'a -> 'a t
val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
val map : ('a -> 'b) -> 'a t -> 'b t
val join : 'a t t -> 'a t
val nil : 'a t
val ( ++ ) : 'a t -> 'a t -> 'a t
val ( @: ) : 'a -> 'a t -> 'a t
val fold : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a
val iter : ('a -> unit) -> 'a t -> unit
val i : (('a -> unit) -> 'b -> unit) -> 'b -> 'a t
val ii : (('a -> 'b -> unit) -> 'c -> unit) -> 'c -> ('a * 'b) t
val of_list : 'a list -> 'a t
val of_iter : (('a -> unit) -> unit) -> 'a t
