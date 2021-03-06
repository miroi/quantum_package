open Qputils;;
open Qptypes;;
open Core.Std;;

(*
 * Command-line arguments
 * ----------------------
 *)

let build_mask from upto n_int =
  let from  = MO_number.to_int from
  and upto  = MO_number.to_int upto
  and n_int = N_int_number.to_int n_int
  in
  let rec build_mask bit = function
    | 0 -> []
    | i -> 
        if ( i = upto ) then
          Bit.One::(build_mask Bit.One (i-1))
        else if ( i = from ) then
          Bit.One::(build_mask Bit.Zero (i-1))
        else
          bit::(build_mask bit (i-1))
  in
  let starting_bit = 
    if ( (upto >= n_int*64) || (upto < 0) ) then Bit.One
    else Bit.Zero
  in
  build_mask starting_bit (n_int*64)
  |> List.rev
;;


type t = 
  | Core
  | Inactive
  | Active
  | Virtual
  | Deleted
  | None
;;

let t_to_string = function
  | Core -> "core"
  | Inactive -> "inactive"
  | Active -> "active"
  | Virtual -> "virtual"
  | Deleted -> "deleted"
  | None -> assert false
;;

let set ~core ~inact ~act ~virt ~del =

  let mo_tot_num =
     Ezfio.get_mo_basis_mo_tot_num ()
  in
  let n_int =
     try  N_int_number.of_int (Ezfio.get_determinants_n_int ())
     with _ -> Bitlist.n_int_of_mo_tot_num mo_tot_num 
  in


  let mo_class =
     Array.init mo_tot_num ~f:(fun i -> None)
  in

  (* Check input data *)
  let apply_class l = 
    let rec apply_class t = function
    | [] -> ()
    | k::tail -> let i = MO_number.to_int k in
        begin
          match mo_class.(i-1) with
          | None -> mo_class.(i-1) <- t ;
            apply_class t tail;
          | x -> failwith
             (Printf.sprintf "Orbital %d is defined both in the %s and %s spaces"
             i (t_to_string x) (t_to_string t))
        end
    in
    match l with
    | MO_class.Core     x -> apply_class Core      x
    | MO_class.Inactive x -> apply_class Inactive  x
    | MO_class.Active   x -> apply_class Active    x
    | MO_class.Virtual  x -> apply_class Virtual   x
    | MO_class.Deleted  x -> apply_class Deleted   x
  in

  let core  = MO_class.create_core     core in
  let inact = MO_class.create_inactive inact in
  let act   = MO_class.create_active   act in
  let virt  = MO_class.create_virtual  virt in
  let del   = MO_class.create_deleted  del in

  apply_class core  ;
  apply_class inact ;
  apply_class act   ;
  apply_class virt  ;
  apply_class del   ;

  for i=1 to (Array.length mo_class)
  do
    if (mo_class.(i-1) = None) then
      failwith (Printf.sprintf "Orbital %d is not specified (mo_tot_num = %d)" i mo_tot_num)
  done;
  
  
  (* Debug output *)
  MO_class.to_string core  |> print_endline ;
  MO_class.to_string inact |> print_endline ;
  MO_class.to_string act   |> print_endline ;
  MO_class.to_string virt  |> print_endline ;
  MO_class.to_string del   |> print_endline ;

  (* Create masks *)
  let ia = Excitation.create_single inact act 
  and aa = Excitation.create_single act act 
  and av = Excitation.create_single act virt
  in
  let single_excitations = [ ia ; aa ; av ]
    |> List.map ~f:Excitation.(fun x ->
       match x with
       | Single (x,y) -> 
         ( MO_class.to_bitlist n_int (Hole.to_mo_class x),
           MO_class.to_bitlist n_int (Particle.to_mo_class y) ) 
       | Double _ -> assert false
       )
       
  and double_excitations = [
    Excitation.double_of_singles ia ia ;
    Excitation.double_of_singles ia aa ;
    Excitation.double_of_singles ia av ;
    Excitation.double_of_singles aa aa ;
    Excitation.double_of_singles aa av ;
    Excitation.double_of_singles av av ]
    |> List.map ~f:Excitation.(fun x ->
       match x with
       | Single _ -> assert false
       | Double (x,y,z,t) -> 
         ( MO_class.to_bitlist n_int (Hole.to_mo_class x),
           MO_class.to_bitlist n_int (Particle.to_mo_class y) , 
           MO_class.to_bitlist n_int (Hole.to_mo_class z),
           MO_class.to_bitlist n_int (Particle.to_mo_class t) )
       )
  in
  
  let extract_hole (h,_) = h 
  and extract_particle (_,p) = p 
  and extract_hole1 (h,_,_,_) = h 
  and extract_particle1 (_,p,_,_) = p 
  and extract_hole2 (_,_,h,_) = h 
  and extract_particle2 (_,_,_,p) = p 
  in
  let result = [
    List.map ~f:extract_hole single_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
    List.map ~f:extract_particle single_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
    List.map ~f:extract_hole1 double_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
    List.map ~f:extract_particle1 double_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
    List.map ~f:extract_hole2 double_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
    List.map ~f:extract_particle2 double_excitations
    |>  List.fold ~init:(Bitlist.zero n_int) ~f:Bitlist.or_operator ;
  ]
  in

  List.iter ~f:(fun x-> print_endline (Bitlist.to_string x)) result;

  (* Write masks *)
  let result =  List.map ~f:(fun x ->
     let y = Bitlist.to_int64_list x in y@y )
     result 
  |> List.concat
  in

  Ezfio.set_bitmasks_n_int (N_int_number.to_int n_int);
  Ezfio.set_bitmasks_bit_kind 8;
  Ezfio.set_bitmasks_n_mask_gen 1;
  Ezfio.ezfio_array_of_list ~rank:4 ~dim:([| (N_int_number.to_int n_int) ; 2; 6; 1|]) ~data:result
  |> Ezfio.set_bitmasks_generators ; 

  let result =
    let open Excitation in 
    match aa with
    | Double _ -> assert false
    | Single (x,y) -> 
        ( MO_class.to_bitlist n_int (Hole.to_mo_class x) ) @
        ( MO_class.to_bitlist n_int (Particle.to_mo_class y) )
        |> Bitlist.to_int64_list
  in
  Ezfio.set_bitmasks_n_mask_cas 1;
  Ezfio.ezfio_array_of_list ~rank:3 ~dim:([| (N_int_number.to_int n_int) ; 2; 1|]) ~data:result
  |> Ezfio.set_bitmasks_cas; 
;;

let get () =

  let mo_tot_num =
     Ezfio.get_mo_basis_mo_tot_num ()
  in
  let n_int =
     try  N_int_number.of_int (Ezfio.get_determinants_n_int ())
     with _ -> Bitlist.n_int_of_mo_tot_num mo_tot_num 
  in

  let bitmasks = 
    match Input.Bitmasks.read () with
    | Some x -> x
    | None -> failwith "No data to print"
  in
  assert (bitmasks.Input.Bitmasks.n_mask_gen |> Bitmask_number.to_int = 1);
  assert (bitmasks.Input.Bitmasks.n_mask_cas |> Bitmask_number.to_int = 1);

  let (generators,cas) =
    Bitlist.of_int64_array bitmasks.Input.Bitmasks.generators,
    Bitlist.of_int64_array bitmasks.Input.Bitmasks.cas
  in

  Printf.printf "MO  : %d\n" mo_tot_num;
  Printf.printf "n_int: %d\n" (N_int_number.to_int n_int);
  Printf.printf "Gen : %s\nCAS : %s\n"
    (Bitlist.to_string generators)
    (Bitlist.to_string cas)
  
;;

let run ~print ?(core="[]") ?(inact="[]") ?(act="[]") ?(virt="[]") ?(del="[]") ezfio_filename =

  Ezfio.set_file ezfio_filename ;
  if not (Ezfio.has_mo_basis_mo_tot_num ()) then
    failwith "mo_basis/mo_tot_num not found" ;

  if print then
     get ()
  else
     set ~core ~inact ~act ~virt ~del
;;

let ezfio_file =
  let failure filename = 
        eprintf "'%s' is not an EZFIO file.\n%!" filename;
        exit 1
  in
  Command.Spec.Arg_type.create
  (fun filename ->
    match Sys.is_directory filename with
    | `Yes -> 
        begin
          match Sys.is_file (filename ^ "/.version") with
          | `Yes -> filename
          | _ -> failure filename
        end
    | _ -> failure filename
  )
;;

let default range =
  let failure filename = 
        eprintf "'%s' is not a regular file.\n%!" filename;
        exit 1
  in
  Command.Spec.Arg_type.create
  (fun filename ->
    match Sys.is_directory filename with
    | `Yes -> 
        begin
          match Sys.is_file (filename^"/.version") with
          | `Yes -> filename
          | _ -> failure filename
        end
    | _ -> failure filename
  )
;;

let spec =
  let open Command.Spec in
  empty 
  +> flag "core"   (optional string) ~doc:"range Range of core orbitals"
  +> flag "inact"  (optional string) ~doc:"range Range of inactive orbitals"
  +> flag "act"    (optional string) ~doc:"range Range of active orbitals"
  +> flag "virt"   (optional string) ~doc:"range Range of virtual orbitals"
  +> flag "del"    (optional string) ~doc:"range Range of deleted orbitals"
  +> flag "print"  no_arg ~doc:" Print the current masks"
  +> anon ("ezfio_filename" %: ezfio_file)
;;

let command = 
    Command.basic 
    ~summary: "Quantum Package command"
    ~readme:(fun () ->
     "Set the orbital classes in an EZFIO directory
      The range of MOs has the form : \"[36-53,72-107,126-131]\"
        ")
    spec
    (fun core inact act virt del print ezfio_filename () -> run ~print ?core ?inact ?act ?virt ?del ezfio_filename )
;;

let () =
    Command.run command


