open Core.Std
open Qptypes

(** New job : Request to create a new multi-tasked job *)

module State : sig
  type t 
  val of_string : string -> t
  val to_string : t -> string 
end = struct
  type t = string
  let of_string x = x
  let to_string x = x
end

module Newjob_msg : sig
  type t = 
  { state: State.t;
    address_tcp: Address.Tcp.t ;
    address_inproc: Address.Inproc.t;
  }
  val create : address_tcp:string -> address_inproc:string -> state:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { state: State.t;
    address_tcp: Address.Tcp.t ;
    address_inproc: Address.Inproc.t;
  }
  let create ~address_tcp ~address_inproc ~state =
    { state = State.of_string state;
      address_tcp = Address.Tcp.of_string address_tcp ;
      address_inproc = Address.Inproc.of_string address_inproc ;
    }
  let to_string t =
    Printf.sprintf "new_job %s %s %s"
     ( State.to_string t.state ) 
     ( Address.Tcp.to_string t.address_tcp ) 
     ( Address.Inproc.to_string t.address_inproc ) 
end

module Endjob_msg : sig
  type t = 
  { state: State.t;
  }
  val create : state:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { state: State.t;
  }
  let create ~state =
    { state = State.of_string state;
    }
  let to_string t =
    Printf.sprintf "end_job %s"
     ( State.to_string t.state ) 
end


(** Connect : connect a new client to the task server *)

module Connect_msg : sig
  type t = Tcp | Inproc | Ipc
  val create : typ:string -> t
  val to_string : t -> string
end = struct
  type t = Tcp | Inproc | Ipc
  let create ~typ = 
    match typ with
    | "tcp" -> Tcp
    | "inproc" -> Inproc
    | "ipc" -> Ipc
    |  _ -> assert false
  let to_string = function
    | Tcp    -> "connect tcp"
    | Inproc -> "connect inproc"
    | Ipc    -> "connect ipc"
end

(** ConnectReply : Reply to the connect messsage *)

module ConnectReply_msg : sig
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
    push_address: Address.t;
  }
  val create : state:State.t -> client_id:Id.Client.t -> push_address:Address.t -> t
  val to_string : t -> string
end = struct
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
    push_address: Address.t;
  }
  let create ~state ~client_id ~push_address = 
    { client_id ; state ; push_address }
  let to_string x =
    Printf.sprintf "connect_reply %s %d %s"
      (State.to_string x.state)
      (Id.Client.to_int x.client_id)
      (Address.to_string x.push_address)
end


(** Disconnect : disconnect a client from the task server *)
module Disconnect_msg : sig
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
  }
  val create : state:string -> client_id:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
  }
  let create ~state ~client_id = 
    { client_id = Id.Client.of_string client_id ; state = State.of_string state }
  let to_string x =
    Printf.sprintf "disconnect %s %d"
      (State.to_string x.state)
      (Id.Client.to_int x.client_id)
end

module DisconnectReply_msg : sig
  type t = 
  { 
    state: State.t ;
  }
  val create : state:State.t -> t
  val to_string : t -> string
end = struct
  type t = 
  { 
    state: State.t ;
  }
  let create ~state = 
    { state }
  let to_string x =
    Printf.sprintf "disconnect_reply %s"
      (State.to_string x.state)
end



(** AddTask : Add a new task to the queue *)
module AddTask_msg : sig
  type t = 
  { state: State.t;
    task:  string;
  }
  val create : state:string -> task:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { state: State.t;
    task:  string;
  }
  let create ~state ~task = { state = State.of_string state ; task }
  let to_string x =
    Printf.sprintf "add_task %s %s" (State.to_string x.state) x.task 
end


(** AddTaskReply : Reply to the AddTask message *)
module AddTaskReply_msg : sig
  type t  
  val create : task_id:Id.Task.t -> t
  val to_string : t -> string
end = struct
  type t = Id.Task.t
  let create ~task_id = task_id
  let to_string x =
    Printf.sprintf "add_task_reply %d" (Id.Task.to_int x)
end


(** DelTask : Remove a task from the queue *)
module DelTask_msg : sig
  type t = 
  { state:  State.t;
    task_id:  Id.Task.t
  }
  val create : state:string -> task_id:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { state:  State.t;
    task_id:  Id.Task.t
  }
  let create ~state ~task_id =
    { state = State.of_string state ; 
      task_id = Id.Task.of_string task_id
    }
  let to_string x =
    Printf.sprintf "del_task %s %d" 
      (State.to_string x.state)
      (Id.Task.to_int x.task_id)
end


(** DelTaskReply : Reply to the DelTask message *)
module DelTaskReply_msg : sig
  type t  
  val create : task_id:Id.Task.t -> more:bool -> t
  val to_string : t -> string
end = struct
  type t = {
    task_id : Id.Task.t ;
    more    : bool;
  }
  let create ~task_id ~more = { task_id ; more }
  let to_string x =
    let more = 
      if x.more then "more"
      else "done"
    in
    Printf.sprintf "del_task_reply %s %d" 
     more (Id.Task.to_int x.task_id) 
end



(** GetTask : get a new task to do *)
module GetTask_msg : sig
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
  }
  val create : state:string -> client_id:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { client_id: Id.Client.t ;
    state: State.t ;
  }
  let create ~state ~client_id = 
    { client_id = Id.Client.of_string client_id ; state = State.of_string state }
  let to_string x =
    Printf.sprintf "get_task %s %d"
      (State.to_string x.state)
      (Id.Client.to_int x.client_id)
end

(** GetTaskReply : Reply to the GetTask message *)
module GetTaskReply_msg : sig
  type t  
  val create : task_id:Id.Task.t -> task:string -> t
  val to_string : t -> string
end = struct
  type t =
  { task_id: Id.Task.t ;
    task   : string ;
  }
  let create ~task_id ~task = { task_id ; task }
  let to_string x =
    Printf.sprintf "get_task_reply %d %s" (Id.Task.to_int x.task_id) x.task
end

(** GetPsi : get the current variational wave function *)
module GetPsi_msg : sig
  type t = 
  { client_id: Id.Client.t ;
  }
  val create : client_id:string -> t
  val to_string : t -> string
end = struct
  type t = 
  { client_id: Id.Client.t ;
  }
  let create ~client_id = 
    { client_id = Id.Client.of_string client_id }
  let to_string x =
    Printf.sprintf "get_psi %d"
      (Id.Client.to_int x.client_id)
end

module Psi : sig
  type t = 
  {
      n_state   :  Strictly_positive_int.t   ;
      n_det     :  Strictly_positive_int.t   ;
      psi_det_size :  Strictly_positive_int.t ;
      n_det_generators : Strictly_positive_int.t option;
      n_det_selectors : Strictly_positive_int.t option;
      psi_det   :  string                    ;
      psi_coef  :  string                    ;
  }
  val create : n_state:Strictly_positive_int.t
     -> n_det:Strictly_positive_int.t 
     -> psi_det_size:Strictly_positive_int.t 
     -> n_det_generators:Strictly_positive_int.t option
     -> n_det_selectors:Strictly_positive_int.t option
     -> psi_det:string -> psi_coef:string -> t
end = struct
  type t = 
  {
      n_state   :  Strictly_positive_int.t   ;
      n_det     :  Strictly_positive_int.t   ;
      psi_det_size :  Strictly_positive_int.t ;
      n_det_generators : Strictly_positive_int.t option;
      n_det_selectors : Strictly_positive_int.t option;
      psi_det   :  string                    ;
      psi_coef  :  string                    ;
  }
  let create ~n_state ~n_det ~psi_det_size
    ~n_det_generators ~n_det_selectors ~psi_det ~psi_coef =
    assert (Strictly_positive_int.to_int n_det <=
            Strictly_positive_int.to_int psi_det_size );
    {  n_state; n_det ; psi_det_size ;
       n_det_generators ; n_det_selectors ;
       psi_det ; psi_coef }
end

(** GetPsiReply_msg : Reply to the GetPsi message *)
module GetPsiReply_msg : sig
  type t =
  { client_id :  Id.Client.t ;
    psi       :  Psi.t }
  val create : client_id:Id.Client.t -> psi:Psi.t -> t
  val to_string_list : t -> string list
  val to_string : t -> string
end = struct
  type t = 
  { client_id :  Id.Client.t ;
    psi       :  Psi.t }
  let create ~client_id ~psi =
    {  client_id ; psi }
  let to_string_list x =
    let g, s = 
      match x.psi.Psi.n_det_generators, x.psi.Psi.n_det_selectors with
      | Some g, Some s -> Strictly_positive_int.to_int g, Strictly_positive_int.to_int s
      | _ -> -1, -1
    in
    [ Printf.sprintf "get_psi_reply %d %d %d %d %d %d"
      (Id.Client.to_int x.client_id)
      (Strictly_positive_int.to_int x.psi.Psi.n_state)
      (Strictly_positive_int.to_int x.psi.Psi.n_det) 
      (Strictly_positive_int.to_int x.psi.Psi.psi_det_size)
      g s ;
      x.psi.Psi.psi_det ; x.psi.Psi.psi_coef ]
  let to_string x =
    let g, s = 
      match x.psi.Psi.n_det_generators, x.psi.Psi.n_det_selectors with
      | Some g, Some s -> Strictly_positive_int.to_int g, Strictly_positive_int.to_int s
      | _ -> -1, -1
    in
    Printf.sprintf "get_psi_reply %d %d %d %d %d %d"
      (Id.Client.to_int x.client_id)
      (Strictly_positive_int.to_int x.psi.Psi.n_state)
      (Strictly_positive_int.to_int x.psi.Psi.n_det) 
      (Strictly_positive_int.to_int x.psi.Psi.psi_det_size) 
      g s
end


(** PutPsi : put the current variational wave function *)
module PutPsi_msg : sig
  type t = 
  { client_id :  Id.Client.t ;
    n_state   :  Strictly_positive_int.t ;
    n_det     :  Strictly_positive_int.t ;
    psi_det_size :  Strictly_positive_int.t ;
    n_det_generators : Strictly_positive_int.t option;
    n_det_selectors  : Strictly_positive_int.t option;
    psi       :  Psi.t option }
  val create : 
     client_id:string ->
     n_state:string ->
     n_det:string ->
     psi_det_size:string ->
     psi_det:string option ->
     psi_coef:string option ->
     n_det_generators: string option -> 
     n_det_selectors:string option ->  t
  val to_string_list : t -> string list
  val to_string : t -> string 
end = struct
  type t = 
  { client_id :  Id.Client.t ;
    n_state   :  Strictly_positive_int.t ;
    n_det     :  Strictly_positive_int.t ;
    psi_det_size :  Strictly_positive_int.t ;
    n_det_generators : Strictly_positive_int.t option;
    n_det_selectors  : Strictly_positive_int.t option;
    psi       :  Psi.t option }
  let create ~client_id ~n_state ~n_det ~psi_det_size ~psi_det ~psi_coef 
    ~n_det_generators ~n_det_selectors  =
    let n_state, n_det, psi_det_size = 
       Int.of_string n_state 
       |> Strictly_positive_int.of_int ,
       Int.of_string n_det
       |> Strictly_positive_int.of_int ,
       Int.of_string psi_det_size
       |> Strictly_positive_int.of_int
    in
    assert (Strictly_positive_int.to_int psi_det_size >=
      Strictly_positive_int.to_int n_det);
    let n_det_generators, n_det_selectors  =
      match n_det_generators, n_det_selectors  with
      | Some x, Some y -> 
         Some (Strictly_positive_int.of_int @@ Int.of_string x), 
         Some (Strictly_positive_int.of_int @@ Int.of_string y)
      | _ -> None, None
    in
    let psi =
      match (psi_det, psi_coef) with
      | (Some psi_det, Some psi_coef) ->
        Some (Psi.create ~n_state ~n_det ~psi_det_size ~psi_det
          ~psi_coef ~n_det_generators ~n_det_selectors)
      | _ -> None
    in
    { client_id = Id.Client.of_string client_id ;
      n_state ; n_det ; psi_det_size ; n_det_generators ;
      n_det_selectors ; psi }
  let to_string_list x =
    match x.n_det_generators, x.n_det_selectors, x.psi with
    | Some g, Some s, Some psi ->
      [ Printf.sprintf "put_psi %d %d %d %d %d %d"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size)  
        (Strictly_positive_int.to_int g)  
        (Strictly_positive_int.to_int s) ; 
          psi.Psi.psi_det ; psi.Psi.psi_coef ]
    | Some g, Some s, None ->
      [ Printf.sprintf "put_psi %d %d %d %d %d %d"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size)  
        (Strictly_positive_int.to_int g)  
        (Strictly_positive_int.to_int s) ; 
          "None" ; "None" ]
    | _ ->
      [ Printf.sprintf "put_psi %d %d %d %d -1 -1"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size) ;
          "None" ; "None" ]
  let to_string x =
    match x.n_det_generators, x.n_det_selectors, x.psi with
    | Some g, Some s, Some psi ->
      Printf.sprintf "put_psi %d %d %d %d %d %d"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size)  
        (Strictly_positive_int.to_int g)  
        (Strictly_positive_int.to_int s) 
    | Some g, Some s, None ->
      Printf.sprintf "put_psi %d %d %d %d %d %d"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size)  
        (Strictly_positive_int.to_int g)  
        (Strictly_positive_int.to_int s) 
    | _, _, _ ->
      Printf.sprintf "put_psi %d %d %d %d %d %d"
        (Id.Client.to_int x.client_id)
        (Strictly_positive_int.to_int x.n_state)
        (Strictly_positive_int.to_int x.n_det) 
        (Strictly_positive_int.to_int x.psi_det_size)  
        (-1) (-1)
end

(** PutPsiReply_msg : Reply to the PutPsi message *)
module PutPsiReply_msg : sig
  type t
  val create : client_id:Id.Client.t -> t
  val to_string : t -> string
end = struct
  type t = 
  { client_id :  Id.Client.t ;
  }
  let create ~client_id =
    { client_id; }
  let to_string x =
    Printf.sprintf "put_psi_reply %d"
      (Id.Client.to_int x.client_id)
end


(** TaskDone : Inform the server that a task is finished *)
module TaskDone_msg : sig
  type t =
    { client_id: Id.Client.t ;
      state:     State.t ;
      task_id:   Id.Task.t ;
    }
  val create : state:string -> client_id:string -> task_id:string -> t
  val to_string : t -> string
end = struct
  type t =
  { client_id: Id.Client.t ;
    state: State.t ;
    task_id:  Id.Task.t;
  }
  let create ~state ~client_id ~task_id = 
    { client_id = Id.Client.of_string client_id ; 
      state = State.of_string state ;
      task_id  = Id.Task.of_string task_id;
    }

  let to_string x =
    Printf.sprintf "task_done %s %d %d"
      (State.to_string x.state)
      (Id.Client.to_int x.client_id)
      (Id.Task.to_int x.task_id)
end

(** Terminate *)
module Terminate_msg : sig
  type t 
  val create : unit -> t
  val to_string : t -> string
end = struct
  type t = Terminate
  let create () = Terminate
  let to_string x = "terminate"
end

(** OK *)
module Ok_msg : sig
  type t 
  val create : unit -> t
  val to_string : t -> string
end = struct
  type t = Ok
  let create () = Ok
  let to_string x = "ok"
end

(** Error *)
module Error_msg : sig
  type t 
  val create : string -> t
  val to_string : t -> string
end = struct
  type t = string
  let create x = x
  let to_string x =
     String.concat ~sep:" "  [ "error" ; x ] 
end



(** Message *)

type t =
| GetPsi              of  GetPsi_msg.t
| PutPsi              of  PutPsi_msg.t
| GetPsiReply         of  GetPsiReply_msg.t
| PutPsiReply         of  PutPsiReply_msg.t
| Newjob              of  Newjob_msg.t
| Endjob              of  Endjob_msg.t
| Connect             of  Connect_msg.t
| ConnectReply        of  ConnectReply_msg.t
| Disconnect          of  Disconnect_msg.t
| DisconnectReply     of  DisconnectReply_msg.t
| GetTask             of  GetTask_msg.t
| GetTaskReply        of  GetTaskReply_msg.t
| DelTask             of  DelTask_msg.t
| DelTaskReply        of  DelTaskReply_msg.t
| AddTask             of  AddTask_msg.t
| AddTaskReply        of  AddTaskReply_msg.t
| TaskDone            of  TaskDone_msg.t
| Terminate           of  Terminate_msg.t
| Ok                  of  Ok_msg.t
| Error               of  Error_msg.t


let of_string s = 
  let l =
    String.split ~on:' ' s
    |> List.filter ~f:(fun x -> (String.strip x) <> "")
    |> List.map ~f:String.lowercase
  in
  match l with
  | "add_task"   :: state :: task ->
       AddTask (AddTask_msg.create ~state ~task:(String.concat ~sep:" " task) )
  | "del_task"   :: state :: task_id :: [] ->
       DelTask (DelTask_msg.create ~state ~task_id)
  | "get_task"   :: state :: client_id :: [] ->
       GetTask (GetTask_msg.create ~state ~client_id)
  | "task_done"  :: state :: client_id :: task_id :: [] ->
       TaskDone (TaskDone_msg.create ~state ~client_id ~task_id)
  | "disconnect" :: state :: client_id :: [] ->
       Disconnect (Disconnect_msg.create ~state ~client_id)
  | "connect"    :: t :: [] -> 
       Connect (Connect_msg.create t)
  | "new_job"    :: state :: push_address_tcp :: push_address_inproc :: [] -> 
       Newjob (Newjob_msg.create push_address_tcp push_address_inproc state)
  | "end_job"    :: state :: [] -> 
       Endjob (Endjob_msg.create state)
  | "terminate"  :: [] ->
       Terminate (Terminate_msg.create () )
  | "get_psi"    :: client_id :: [] ->
       GetPsi   (GetPsi_msg.create ~client_id)
  | "put_psi"    :: client_id :: n_state :: n_det :: psi_det_size :: n_det_generators :: n_det_selectors :: [] ->
       PutPsi   (PutPsi_msg.create ~client_id ~n_state ~n_det ~psi_det_size
                 ~n_det_generators:(Some n_det_generators) ~n_det_selectors:(Some n_det_selectors)
                 ~psi_det:None ~psi_coef:None )
  | "put_psi"    :: client_id :: n_state :: n_det :: psi_det_size :: [] ->
       PutPsi   (PutPsi_msg.create ~client_id ~n_state ~n_det ~psi_det_size ~n_det_generators:None
                ~n_det_selectors:None ~psi_det:None ~psi_coef:None )
  | "ok"         :: [] ->
       Ok (Ok_msg.create ())
  | "error"      :: rest ->
       Error (Error_msg.create (String.concat ~sep:" " rest))
  | _ -> failwith "Message not understood"
    

let to_string = function
| GetPsi              x -> GetPsi_msg.to_string             x
| PutPsiReply         x -> PutPsiReply_msg.to_string        x
| Newjob              x -> Newjob_msg.to_string             x
| Endjob              x -> Endjob_msg.to_string             x
| Connect             x -> Connect_msg.to_string            x
| ConnectReply        x -> ConnectReply_msg.to_string       x
| Disconnect          x -> Disconnect_msg.to_string         x
| DisconnectReply     x -> DisconnectReply_msg.to_string    x
| GetTask             x -> GetTask_msg.to_string            x
| GetTaskReply        x -> GetTaskReply_msg.to_string       x
| DelTask             x -> DelTask_msg.to_string           x
| DelTaskReply        x -> DelTaskReply_msg.to_string      x
| AddTask             x -> AddTask_msg.to_string            x
| AddTaskReply        x -> AddTaskReply_msg.to_string       x
| TaskDone            x -> TaskDone_msg.to_string           x
| Terminate           x -> Terminate_msg.to_string          x
| Ok                  x -> Ok_msg.to_string                 x
| Error               x -> Error_msg.to_string              x
| PutPsi              x -> PutPsi_msg.to_string             x
| GetPsiReply         x -> GetPsiReply_msg.to_string        x


let to_string_list = function
| PutPsi           x -> PutPsi_msg.to_string_list     x
| GetPsiReply      x -> GetPsiReply_msg.to_string_list x
| _                  -> assert false
