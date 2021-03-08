Require Export toString.
Require Export CalculusSM.

From mathcomp.ssreflect
Require Import ssreflect ssrbool ssrnat seq ssrfun eqtype bigop fintype choice tuple finfun.

Require Import Reals (*Fourier FunctionalExtensionality*).

From infotheo
Require Import fdist proba (*pproba*) (*ssrR*) Reals_ext (*logb ssr_ext ssralg_ext bigop_ext*) Rbigop.


(* We assume that if a message is not lost, it gets received by some time [R+1] *)
Class ProbaParams :=
  MkProbaParams {
      (* probability that a message gets lots *)
      LostDist : prob;

      (* probability distribution that messages are received over a finite event
         set of size R+1 (i.e., R+1 discrete time points *)
      RcvdDist : forall (R : nat), fdist [finType of 'I_R.+1];
    }.

Class BoundsParams :=
  MkBoundsParams {
      (* time by which a message is considered lost *)
      maxRound : nat;

      (* To get finite types we can only reason up to so maximal time *)
      maxTime  : nat;

      (* To get finite types again: *)
      maxMsgs  : nat;
    }.

Class ProcParams :=
  MkProcParams {
      numNodes : nat;
      message  : finType;
      state    : finType;
  }.


(* Inspired by probachain *)
Section Comp.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.


  Inductive Comp : finType -> Type :=
  | Ret  : forall (A : finType) (a : A), Comp A
  | Bind : forall (A B : finType), Comp B -> (B -> Comp A) -> Comp A
  | Pick : forall (n : nat), Comp [finType of 'I_n.+1]
  | Lost : Comp [finType of bool].

  (* from probachain *)
  Lemma size_enum_equiv :
    forall n: nat, size(enum (ordinal n.+1)) = n.+1 -> #|ordinal_finType n.+1| = n.+1.
  Proof.
    move=> n H.
      by rewrite unlock H.
  Qed.

  Definition pickRound : Comp [finType of 'I_(maxRound.+1)] :=
    Pick maxRound.

  Fixpoint getSupport {A : finType} (c : Comp A) : list A :=
    match c with
    | Ret _ a => [a]
    | Bind _ _ c1 c2 =>
      flat_map
        (fun b => (getSupport (c2 b)))
        (getSupport c1)
    | Pick n => ord_enum n.+1
    | Lost => [true, false]
    end.

  Fixpoint evalDist {A : finType} (c : Comp A) : fdist A :=
    match c with
    | Ret _ a => FDist1.d a
    | Bind _ _ c f => FDistBind.d (evalDist c) (fun b => evalDist (f b))
    | Pick n => RcvdDist n
    | Lost => Binary.d card_bool LostDist true (* i.e., LostDist if true and 1-LostDist if false *)
    end.

  Definition distRound : fdist [finType of 'I_(maxRound.+1)] := RcvdDist maxRound.

End Comp.

Arguments Ret [A] _.
Arguments Bind [A] [B] _ _.


Section finList.

  Variables (n : nat) (T : finType).

  Structure finList_of : Type := FinList {fLval :> seq T; _ : length fLval <= n}.
  Canonical finList_subType := Eval hnf in [subType for fLval].

  Definition finList_eqMixin  := Eval hnf in [eqMixin of finList_of by <:].
  Canonical finList_eqType    := Eval hnf in EqType finList_of finList_eqMixin.
  Canonical finList_of_eqType := Eval hnf in [eqType of finList_of].

  Definition finList_choiceMixin  := [choiceMixin of finList_of by <:].
  Canonical finList_choiceType    := Eval hnf in ChoiceType finList_of finList_choiceMixin.
  Canonical finList_of_choiceType := Eval hnf in [choiceType of finList_of].

  Definition finList_countMixin  := [countMixin of finList_of by <:].
  Canonical finList_countType    := Eval hnf in CountType finList_of finList_countMixin.
  Canonical finList_subCountType := Eval hnf in [subCountType of finList_of].
  Canonical finList_of_countType := Eval hnf in [countType of finList_of].
End finList.

Notation "n .-finList" := (finList_of n)
  (at level 2, format "n .-finList") : type_scope.


Section finList2.
  Definition extendN {T : finType} (e : seq (seq T)) := flatten (codom (fun (x : T) => map (List.cons x) e)).

  Definition seqN (T : finType) (n : nat) : seq (seq T) :=
    iter n extendN [::[::]].

  Definition enumN (T : finType) (n : nat) : seq (finList_of n T) :=
    pmap insub (seqN T n).

  Definition toFL {T n s} (h : length s <= n) : finList_of n T :=
    FinList _ _ s h.

  Lemma seqN_prop :
    forall T n s,
      s \in (seqN T n)
      -> length s = n.
  Proof.
    induction n; introv i; simpl in *.

    { destruct s; simpl in *; auto.
      unfold in_mem in *; simpl in *; inversion i. }

    unfold extendN, codom in i.
    move/flatten_imageP in i.
    destruct i as [t x i j].
    move/mapP in i.
    destruct i as [z w i]; subst; simpl in *.
    f_equal; apply IHn; auto.
  Qed.

  Lemma enumN_prop :
    forall T n s,
      s \in (enumN T n)
      -> length s = n.
  Proof.
    introv i.
    rewrite mem_pmap_sub in i; simpl in *.
    apply seqN_prop in i; auto.
  Qed.

  Definition incFinList {T : finType} {n : nat} (s : finList_of n T) : finList_of (S n) T.
  Proof.
    destruct s as [s c].
    exists s; auto.
  Defined.

  Definition incFinListSeq {T : finType} {n : nat} (s : seq (finList_of n T)) : seq (finList_of (S n) T).
  Proof.
    exact (map incFinList s).
  Defined.

  Fixpoint enumUpToN (T : finType) (n : nat) : seq (finList_of n T) :=
    match n with
    | 0 => enumN T 0
    | S m => enumN T (S m) ++ incFinListSeq (enumUpToN T m)
    end.

  Lemma enumUpToN_prop :
    forall T n s,
      s \in (enumUpToN T n)
      -> length s <= n.
  Proof.
    induction n; introv i; simpl in *.

    { apply enumN_prop in i; rewrite i; auto. }

    rewrite mem_cat in i.
    move/orP in i; destruct i as [i|i].
    { apply enumN_prop in i; rewrite i; auto. }
    move/mapP in i.
    destruct i as [x w i]; subst; simpl in *.
    apply IHn in w.
    destruct x as [x c]; simpl in *; auto.
  Qed.

  Lemma leq_eq_or :
    forall (a b : nat),
      a <= b
      = (a < b) || (a == b).
  Proof.
    induction a; introv; simpl;
      unfold leq in *; simpl; rewrite <- minusE in *; simpl;
        destruct b; simpl; auto.
    rewrite IHa; simpl; auto.
  Qed.

  (* must be proved already *)
  Lemma implies_notin :
    forall (T : eqType) (x : T) (l : seq T),
      ~(x \in l)
       -> (x \notin l).
  Proof.
    introv i; destruct (x \in l); auto.
  Qed.

  Lemma eqFinList_eq :
    forall (T : finType) n (s1 s2 : seq T) i1 i2,
      (FinList n T s1 i1 == FinList n T s2 i2) = (s1 == s2).
  Proof.
    introv; remember (s1 == s2) as b; symmetry in Heqb; destruct b.
    { move/eqP in Heqb; subst; apply/eqP.
      f_equal.
      apply UIP_dec; apply bool_dec. }

    { allrw <- not_true_iff_false; intro xx; destruct Heqb.
      move/eqP in xx; apply/eqP.
      inversion xx; auto. }
  Qed.

  Lemma count_incFinListSeq_enumUptoN_eq :
    forall T n x (c : Datatypes.length x <= n.+1) (d : Datatypes.length x < n.+1),
      count_mem (FinList n.+1 T x c) (incFinListSeq (enumUpToN T n))
      = count_mem (FinList n T x d) (enumUpToN T n).
  Proof.
    introv.
    unfold incFinListSeq.
    rewrite count_map.
    unfold preim,SimplPred; auto.
    apply eq_in_count; introv i; simpl.
    destruct x0 as [s z]; simpl in *.
    repeat rewrite eqFinList_eq; auto.
  Qed.

  Lemma count_mem_smaller :
    forall T n (x : finList_of n.+1 T),
      length x < n.+1
      -> count_mem x (enumN T n.+1) = 0.
  Proof.
    introv i.
    apply/count_memPn.
    apply implies_notin; intro j.
    apply enumN_prop in j; rewrite j in i.
    rewrite ltnn in i; inversion i.
  Qed.

  Lemma count_incFinListSeq_0 :
    forall T n (x : finList_of n.+1 T) (c : Datatypes.length x == n.+1),
      count_mem x (incFinListSeq (enumUpToN T n))
      = 0.
  Proof.
    introv c.
    apply/count_memPn.
    apply implies_notin; intro j.
    unfold incFinListSeq in j.
    move/mapP in j.
    destruct j as [s w i]; subst.
    apply enumUpToN_prop in w.
    unfold incFinList in *; simpl in *.
    destruct s as [s cs]; simpl in *.
    move/eqP in c; rewrite c in w.
    rewrite ltnn in w; inversion w.
  Qed.

  Lemma pmap_flatten :
    forall A B (f : A -> option B) (s : seq (seq A)),
      pmap f (flatten s) = flatten (map (pmap f) s).
  Proof.
    induction s; introv; simpl; auto.
    rewrite pmap_cat; rewrite IHs; auto.
  Qed.

  Lemma count_enumN_as_count_seqN :
    forall T n (x : finList_of T n),
      count_mem x (enumN n T)
      = count (pred1 (fLval _ _ x)) (seqN n T).
  Proof.
    introv.
    unfold enumN.
    repeat rewrite <- size_filter.
    pose proof (seqN_prop n T) as p.
    remember (seqN n T) as l; clear Heql.
    induction l; simpl in *; auto.
    unfold oapp; simpl.
    pose proof (p a) as q; autodimp q hyp; tcsp; try apply mem_head.
    autodimp IHl hyp.
    { introv i; apply p; rewrite in_cons; apply/orP; auto. }
    unfold insub at 1; destruct idP; tcsp;[|rewrite q in n0; destruct n0; auto];[].
    simpl.
    destruct x as [x c]; simpl in *.
    rewrite eqFinList_eq.
    destruct (a == x); simpl; auto.
  Qed.

  Lemma notin_cons :
    forall (T : eqType) t a (l : seq T),
      (t \notin a :: l) = ((t != a) && (t \notin l)).
  Proof.
    introv.
    unfold in_mem; simpl.
    rewrite negb_orb; tcsp.
  Qed.

  Lemma notin_app :
    forall (T : eqType) t (l k : seq T),
      (t \notin l ++ k) = ((t \notin l) && (t \notin k)).
  Proof.
    introv.
    rewrite mem_cat.
    rewrite negb_orb; tcsp.
  Qed.

  Lemma in_uniq_decompose :
    forall (T : eqType) t (l : seq T),
      (t \in l)
      -> uniq l
      -> exists a b, l = a ++ t :: b /\ (t \notin a) /\ (t \notin b).
  Proof.
    induction l; introv i u; simpl in *.
    { inversion i. }
    rewrite in_cons in i.
    move/andP in u; repnd.
    move/orP in i; destruct i as [i|i].

    { move/eqP in i; subst.
      exists ([] : seq T) l; simpl; dands; auto. }

    repeat (autodimp IHl hyp); exrepnd; subst.
    exists (a :: a0) b; simpl; dands; auto.
    rewrite notin_cons.
    rewrite notin_app in u0.
    rewrite notin_cons in u0.
    repeat (move/andP in u0; repnd).
    apply/andP; dands; auto.
    apply/eqP; intro xx; subst.
    move/eqP in u2; tcsp.
  Qed.

  Lemma count_cons_flatten_codom :
    forall (T : finType) (t : T) l K,
      count_mem (t :: l) (flatten (codom (fun z => [seq z :: i | i <- K])))
      = count_mem l K.
  Proof.
    introv.
    rewrite count_flatten.
    rewrite codomE; simpl.
    rewrite <- map_comp.
    unfold ssrfun.comp; simpl.

    rewrite <- deprecated_filter_index_enum.
    pose proof (mem_index_enum t) as i.
    pose proof (index_enum_uniq T) as u.
    apply in_uniq_decompose in i; auto; exrepnd.
    rewrite i0.
    rewrite filter_cat; simpl.
    rewrite map_cat; simpl.
    rewrite sumn_cat; simpl.

    assert (sumn [seq count_mem (t :: l) [seq x :: i | i <- K] | x <- a & T x] = 0) as ha.
    { rewrite map_comp; simpl.
      rewrite <- count_flatten.
      apply/count_memPn.
      apply/negP.
      introv i.
      move/flattenP in i.
      destruct i as [s i z]; simpl in *.
      move/mapP in i.
      destruct i as [w i v]; subst.
      rewrite mem_filter in i; move/andP in i; repnd.
      move/mapP in z.
      destruct z as [s j k]; subst; ginv.
      move/negP in i2; tcsp. }

    assert (sumn [seq count_mem (t :: l) [seq x :: i | i <- K] | x <- b & T x] = 0) as hb.
    { rewrite map_comp; simpl.
      rewrite <- count_flatten.
      apply/count_memPn.
      apply/negP.
      introv i.
      move/flattenP in i.
      destruct i as [s i z]; simpl in *.
      move/mapP in i.
      destruct i as [w i v]; subst.
      rewrite mem_filter in i; move/andP in i; repnd.
      move/mapP in z.
      destruct z as [s j k]; subst; ginv.
      move/negP in i1; tcsp. }

    rewrite ha hb; clear ha hb; simpl; autorewrite with nat.
    rewrite <- plusE; rewrite Nat.add_0_l.

    rewrite count_map; simpl.
    unfold preim; simpl.
    unfold pred1, SimplPred; simpl.
    apply eq_in_count; introv i; simpl.
    rewrite eqseq_cons; simpl.
    apply/andP.
    destruct (x == l); auto.
    intro xx; repnd; inversion xx.
  Qed.

  Lemma count_enumN_1 :
    forall T n (x : finList_of n T),
      length x == n
      -> count_mem x (enumN T n) = 1.
  Proof.
    introv len.
    rewrite count_enumN_as_count_seqN.
    destruct x as [x c]; simpl in *; clear c.
    revert dependent x.
    induction n; introv len; simpl.

    { destruct x; simpl in *; tcsp; inversion len. }

    unfold extendN; simpl.
    destruct x as [|t x]; simpl in *.
    { inversion len. }
    pose proof (IHn x) as IHn; autodimp IHn hyp.
    rewrite count_cons_flatten_codom; auto.
  Qed.

  Lemma enumUpToNFL : forall T n, Finite.axiom (enumUpToN T n).
  Proof.
    induction n; repeat introv; simpl in *.

    { unfold enumN; simpl; unfold oapp, insub; simpl.
      destruct idP; simpl; introv.

      { destruct x as [s c].
        destruct s; simpl in *; auto.
        rewrite ltn0 in c; inversion c. }

      destruct n; auto. }

    unfold enum; simpl.
    rewrite count_cat.
    assert (length x <= n.+1) as len by (destruct x as [x c]; simpl in *; auto).
    rewrite leq_eq_or in len.
    move/orP in len; destruct len as [len|len].

    { rewrite count_mem_smaller; auto.
      unfold Finite.axiom in IHn.
      destruct x as [x c]; simpl in *.
      pose proof (IHn (FinList _ _ x len)) as IHn.
      unfold enum in IHn.
      rewrite count_incFinListSeq_enumUptoN_eq; auto. }

    { rewrite count_incFinListSeq_0; auto; simpl.
      rewrite count_enumN_1; auto. }
  Qed.

  Variables (T : finType) (n : nat).

  Definition enum : seq (finList_of n T) := enumUpToN T n.

  Lemma enumFL : Finite.axiom enum.
  Proof.
    apply enumUpToNFL.
  Qed.

  Definition finList_finMixin  := Eval hnf in FinMixin enumFL.
  Canonical finList_finType    := Eval hnf in FinType (finList_of n T) finList_finMixin.
  Canonical finList_subFinType := Eval hnf in [subFinType of finList_of n T].
  Canonical finList_of_finType := Eval hnf in [finType of finList_of n T].

  Implicit Type l : finList_of n T.

  Definition sizeFL l  := length l.

  Lemma splitFL_cond :
    forall (hd : T) (tl : seq T) (p : length (hd :: tl) <= n),
      length tl <= n.
  Proof.
    auto.
  Qed.

  Definition splitFL l : option T * finList_of n T :=
    match l with
    | FinList [] p => (None, l)
    | FinList (hd :: tl) p => (Some hd, FinList _ _ tl (splitFL_cond hd tl p))
    end.

  Lemma rotateFL_cond :
    forall (hd : T) (tl : seq T) (p : length (hd :: tl) <= n),
      length (snoc tl hd) <= n.
  Proof.
    introv h; simpl in *; rewrite length_snoc; auto.
  Qed.

  Definition rotateFL l : finList_of n T :=
    match l with
    | FinList [] p => l
    | FinList (hd :: tl) p => FinList _ _ (snoc tl hd) (rotateFL_cond hd tl p)
    end.

  Definition emFL : finList_of n T := FinList _ _ [] is_true_true.

End finList2.


Section Msg.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.

  Definition location := 'I_numNodes.
  Definition time     := 'I_maxTime.+1.


  Record DMsg :=
    MkDMsg
      {
        dmsg_src : location;   (* sender *)
        dmsg_dst : location;   (* receiver *)
        dmsg_snd : time; (* time it was sent *)
(*        dmsg_rcv : 'I_maxTime; (* time it is received *)*)
        dmsg_msg : message;    (* payload message *)
      }.

  Definition DMsg_prod (d : DMsg) :=
    (dmsg_src d,
     dmsg_dst d,
     dmsg_snd d,
(*     dmsg_rcv d,*)
     dmsg_msg d).

  Definition prod_DMsg prod :=
    let: (dmsg_src,
          dmsg_dst,
          dmsg_snd,
(*          dmsg_rcv,*)
          dmsg_msg) := prod in
    MkDMsg
      dmsg_src
      dmsg_dst
      dmsg_snd
(*      dmsg_rcv*)
      dmsg_msg.

  Lemma DMsg_cancel : cancel DMsg_prod prod_DMsg .
  Proof.
      by case.
  Qed.

  Definition DMsg_eqMixin      := CanEqMixin DMsg_cancel.
  Canonical DMsg_eqType        := Eval hnf in EqType (DMsg) DMsg_eqMixin.
  Canonical dmsg_of_eqType     := Eval hnf in [eqType of DMsg].
  Definition DMsg_choiceMixin  := CanChoiceMixin DMsg_cancel.
  Canonical DMsg_choiceType    := Eval hnf in ChoiceType (DMsg) DMsg_choiceMixin.
  Canonical dmsg_of_choiceType := Eval hnf in [choiceType of DMsg].
  Definition DMsg_countMixin   := CanCountMixin DMsg_cancel.
  Canonical DMsg_countType     := Eval hnf in CountType (DMsg) DMsg_countMixin.
  Canonical dmsg_of_countType  := Eval hnf in [countType of DMsg].
  Definition DMsg_finMixin     := CanFinMixin DMsg_cancel.
  Canonical DMsg_finType       := Eval hnf in FinType (DMsg) DMsg_finMixin.
  Canonical dmsg_of_finType    := Eval hnf in [finType of DMsg].

End Msg.


Section Status.

  Inductive Status :=
  | StCorrect
  | StFaulty.

  Definition leSt (s1 s2 : Status) : bool :=
    match s1,s2 with
    | StCorrect,_ => true
    | StFaulty,StFaulty => true
    | StFault,StCorrect => false
    end.

  Definition isCorrectStatus (s : Status) :=
    match s with
    | StCorrect => true
    | StFaulty => false
    end.

  Definition Status_bool (s : Status) :=
    match s with
    | StCorrect => true
    | StFaulty => false
    end.

  Definition bool_Status b :=
    match b with
    | true => StCorrect
    | false => StFaulty
    end.

  Lemma Status_cancel : cancel Status_bool bool_Status .
  Proof.
      by case.
  Qed.

  Definition Status_eqMixin      := CanEqMixin Status_cancel.
  Canonical Status_eqType        := Eval hnf in EqType (Status) Status_eqMixin.
  Canonical status_of_eqType     := Eval hnf in [eqType of Status].
  Definition Status_choiceMixin  := CanChoiceMixin Status_cancel.
  Canonical Status_choiceType    := Eval hnf in ChoiceType (Status) Status_choiceMixin.
  Canonical status_of_choiceType := Eval hnf in [choiceType of Status].
  Definition Status_countMixin   := CanCountMixin Status_cancel.
  Canonical Status_countType     := Eval hnf in CountType (Status) Status_countMixin.
  Canonical status_of_countType  := Eval hnf in [countType of Status].
  Definition Status_finMixin     := CanFinMixin Status_cancel.
  Canonical Status_finType       := Eval hnf in FinType (Status) Status_finMixin.
  Canonical status_of_finType    := Eval hnf in [finType of Status].

End Status.


Section Point.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.

  (* Points *)
  Record Point :=
    MkPoint
      {
        point_state  : state;
        point_status : Status;
      }.

  Definition update_state (p : Point) (s : state) :=
    MkPoint
      s
      (point_status p).

  Definition Point_prod (p : Point) :=
    (point_state p,
     point_status p).

  Definition prod_Point prod :=
    let: (point_state,
          point_status) := prod in
    MkPoint
      point_state
      point_status.

  Lemma Point_cancel : cancel Point_prod prod_Point .
  Proof.
      by case.
  Qed.

  Definition Point_eqMixin      := CanEqMixin Point_cancel.
  Canonical Point_eqType        := Eval hnf in EqType (Point) Point_eqMixin.
  Canonical point_of_eqType     := Eval hnf in [eqType of Point].
  Definition Point_choiceMixin  := CanChoiceMixin Point_cancel.
  Canonical Point_choiceType    := Eval hnf in ChoiceType (Point) Point_choiceMixin.
  Canonical point_of_choiceType := Eval hnf in [choiceType of Point].
  Definition Point_countMixin   := CanCountMixin Point_cancel.
  Canonical Point_countType     := Eval hnf in CountType (Point) Point_countMixin.
  Canonical point_of_countType  := Eval hnf in [countType of Point].
  Definition Point_finMixin     := CanFinMixin Point_cancel.
  Canonical Point_finType       := Eval hnf in FinType (Point) Point_finMixin.
  Canonical point_of_finType    := Eval hnf in [finType of Point].

End Point.


Section History.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.

  (* a global state is a tuple of 1 point per node *)
  Definition Global : finType := [finType of {ffun location -> Point}].
  (* A history is a mapping from timestamps to global states - None if not assigned yet *)
  Definition History : finType := [finType of {ffun time -> option Global}].

End History.


Section Queue.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.

  (* a queue is a list of messages *)
  Definition Queue : finType := [finType of maxMsgs.-finList [finType of DMsg]].
  (* 1 queue per node -- messages are sorted by receiver and are tagged with the time they should be delivered *)
  Definition Queues : finType := [finType of {ffun location -> Queue}].
  (* In Transit messages *)
  Definition InTransit : finType := [finType of {ffun time -> Queues}].


  (* truncates the sequence to maxMsgs *)
  Definition seq2queue (s : seq DMsg) : Queue :=
    FinList
      _ _
      (firstn maxMsgs s)
      ([eta introTF (c:=true) leP] (firstn_le_length maxMsgs s)).

  Definition app_queue (q1 q2 : Queue) : Queue := seq2queue (q1 ++ q2).
  Definition snoc_queue (m : DMsg) (q : Queue) : Queue := seq2queue (snoc q m).

End Queue.


Section World.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pProc   : ProcParams   }.

  Definition StateFun := location -> state.
  Definition MsgFun   := location -> Queue.
  Definition UpdFun   := forall (t : time) (l : location) (m : message) (s : state), state ## Queue.

  Class SMParams :=
    MkSMParams {
        InitStates   : StateFun;
        InitMessages : MsgFun;
        Upd          : UpdFun;
      }.

  Context { pSM  : SMParams  }.


  Record World :=
    MkWorld
      {
        (* current "real" time *)
        world_time : time;

        (* history *)
        world_history : History;

        (* messages in transit *)
        world_intransit : InTransit;
        (* The way we compute those in the [step] function is that those are the delivered messages *)
      }.

  (* ********* *)
  (* initial world *)
  Definition initGlobal : Global :=
    finfun (fun l => MkPoint (InitStates l) StCorrect).

  (* Initially only the first world is set *)
  Definition initHistory : History :=
    finfun (fun t => if t == ord0 then Some initGlobal else None).

  Definition emQueue : Queue := emFL _ _.

  Definition emQueues : Queues :=
    finfun (fun _ => emQueue).

  Definition initInTransit : InTransit :=
    finfun (fun t => if t == ord0 then finfun InitMessages else emQueues).

  Definition initWorld : World :=
    MkWorld
      ord0
      initHistory
      initInTransit.
  (* ********* *)

  Definition inc {n} (i : 'I_n) : option 'I_n :=
    match lt_dec i.+1 n with
    | left h => Some ([eta Ordinal (n:=n) (m:=i.+1)] (introT ltP h))
    | right h => None
    end.

  Definition inck {n} (i : 'I_n) (k : nat) : option 'I_n :=
    match lt_dec (k+i) n with
    | left h => Some ([eta Ordinal (n:=n) (m:=k+i)] (introT ltP h))
    | right h => None
    end.

  Definition toI {i n} (h : i < n) : 'I_n :=
    [eta Ordinal (n:=n) (m:=i)] h.

  Definition increment_time (w : World) : option World :=
    option_map
      (fun t =>
         MkWorld
           t
           (world_history w)
           (world_intransit w))
      (inc (world_time w)).

(*  Definition upd_intransit (w : World) (l : maxPoints.-finList [finType of DMsg]) :=
    MkWorld
      (world_global  w)
      (world_history w)
      l.*)

  Definition World_prod w :=
    (world_time w,
     world_history w,
     world_intransit w).

  Definition prod_World prod :=
    let: (world_time,
          world_history,
          world_intransit) := prod in
    MkWorld
      world_time
      world_history
      world_intransit.

  Lemma World_cancel : cancel World_prod prod_World .
  Proof.
      by case.
  Qed.

  Definition World_eqMixin      := CanEqMixin World_cancel.
  Canonical World_eqType        := Eval hnf in EqType (World) World_eqMixin.
  Canonical world_of_eqType     := Eval hnf in [eqType of World].
  Definition World_choiceMixin  := CanChoiceMixin World_cancel.
  Canonical World_choiceType    := Eval hnf in ChoiceType (World) World_choiceMixin.
  Canonical world_of_choiceType := Eval hnf in [choiceType of World].
  Definition World_countMixin   := CanCountMixin World_cancel.
  Canonical World_countType     := Eval hnf in CountType (World) World_countMixin.
  Canonical world_of_countType  := Eval hnf in [countType of World].
  Definition World_finMixin     := CanFinMixin World_cancel.
  Canonical World_finType       := Eval hnf in FinType (World) World_finMixin.
  Canonical world_of_finType    := Eval hnf in [finType of World].


  Fixpoint run_point (t : time) (l : location) (s : state) (q : seq DMsg) : state ## seq DMsg :=
    match q with
    | [] => (s, [])
    | msg :: msgs =>
    let (s1,q1) := Upd t l (dmsg_msg msg) s in
    let (s2,q2) := run_point t l s1 msgs in
    (s2, q1 ++ q2)
    end.

  Definition zip_global
             (t  : time)
             (ps : Global)
             (qs : Queues)
    : {ffun location -> (Point ## Queue)} :=
    finfun
      (fun i =>
         let (s,o) := run_point t i (point_state (ps i)) (qs i) in
         (update_state (ps i) s, seq2queue o)).

  Definition get_msgs_to_in_queue (i : location) (t : Queue) : Queue :=
    seq2queue (filter (fun m => (dmsg_dst m) == i) t).

  Fixpoint get_msgs_to (i : location) (t : seq Queue) : Queue :=
    match t with
    | [] => seq2queue []
    | q :: qs => app_queue (get_msgs_to_in_queue i q) (get_msgs_to i qs)
    end.

  (* the function [f] is organized by senders, while we want it organized by receivers *)
  Definition senders2receivers (f : Queues) : Queues :=
    finfun (fun i => get_msgs_to i (fgraph f)).

  Fixpoint flat_seq_flist {m T} (t : seq (m.-finList T)) : seq T :=
    match t with
    | [] => []
    | x :: xs => x ++ flat_seq_flist xs
    end.

  Definition flatten_queues (qs : Queues) : seq DMsg :=
    flat_seq_flist (fgraph qs).

  Definition run_global
             (t  : time)
             (ps : Global)
             (qs : Queues)
    : Global ## seq DMsg :=
    let f := zip_global t ps qs in
    let points := finfun (fun i => fst (f i)) in
    (* Queues of outgoing messages *)
    let out := flatten_queues (finfun (fun i => snd (f i))) in
    (points,out).

  Definition upd_finfun {A B : finType} (f : {ffun A -> B}) (c : A) (u : B -> B) :=
    finfun (fun a => if a == c then u (f a) else f a).

  (* Adds a message to the queues by adding it to the queue for the recipient of the message *)
  Definition add_to_queues (d : DMsg) (qs : Queues) : Queues :=
    upd_finfun qs (dmsg_dst d) (snoc_queue d).

  (* This is used when messages are produced.
     - Messages can either get lost or be delayed or arrive on time
     - Messages are stored in the in-transit list under the time they should be delivered
     - Messages are stored under the location of the recipient
   *)
  Fixpoint deliver_messages (t : time) (s : seq DMsg) (I : InTransit) : Comp [finType of option InTransit] :=
    match s with
    | [] => Ret (Some I)
    | m :: ms =>
      Bind Lost
           (fun b =>
              if b (* lost *)
              then deliver_messages t ms I
              else (* message is received by t+maxRound *)
                Bind pickRound
                     (fun (r : 'I_(maxRound.+1)) =>
                        (* messages is supposed to be delivered by t+r *)
                        match inck t r with
                        | Some t' => deliver_messages t ms (upd_finfun I t' (add_to_queues m))
                        (* we stop when the time bound is not large enough to deliver a message *)
                        | None => Ret None
                        end))
    end.

  Definition step (w : World) : Comp [finType of option World] :=
    (* current time *)
    let t := world_time w in
    let H := world_history w in
    let I := world_intransit w in
    match H t with
    | Some ps => (* [ps] is the world at the current time [t] *)
      (* we compute the messages that need to be computed at time [t] *)
      let qs := I t in
      (* We now apply the points in [ps] to the queues in [qs].
         We obtain new points and outgoing messages *)
      let (ps',out) := run_global t ps qs in
      match inc t with
      | Some t' =>
        (* we compute the new history *)
        let H' := upd_finfun H t' (fun _ => Some ps') in
        (* we compute the new messages in transit *)
        Bind (deliver_messages t out I)
             (fun o => Ret (option_map (fun I' => MkWorld t' H' I') o))
      | None => Ret None
      end

    (* No world recorded at time [t] *)
    | None => Ret (increment_time w)
    end.

  Fixpoint steps (n : nat) (w : World) : Comp [finType of option World] :=
    match n with
    | 0 => Ret (Some w)
    | S m =>
      Bind (step w)
           (fun o => match o with
                     | Some w' => steps m w'
                     | None => Ret None
                     end)
    end.

  (* [false] if we want the probabilities of faulty executions to not count *)
  Definition steps2dist (n : nat) (F : World -> bool) : fdist [finType of bool] :=
    evalDist (Bind (steps n initWorld)
                   (fun o => match o with
                             | Some w => Ret (F w)
                             | None => Ret false
                             end)).

  (* [true] when proving lower bounds, to set the probability of halted executions to 1 *)
  Definition steps2dist' (n : nat) (F : World -> bool) : fdist [finType of bool] :=
    evalDist (Bind (steps n initWorld)
                   (fun o => match o with
                             | Some w => Ret (F w)
                             | None => Ret true
                             end)).

End World.


(* A simple example with only one initial message (could be a broadcast)
   sent by one node, and all the other nodes, simply relay that message. *)
Section Ex1.

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.

  Definition p_numNodes : nat := 4.

  Inductive p_message :=
  | MsgStart
  | MsgBcast (l : 'I_p_numNodes)
  | MsgEcho  (l : 'I_p_numNodes).

  Definition p_message_nat (s : p_message) : 'I_3 * 'I_p_numNodes :=
    match s with
    | MsgStart => (@Ordinal 3 0 is_true_true, ord0)
    | MsgBcast l => (@Ordinal 3 1 is_true_true, l)
    | MsgEcho  l => (@Ordinal 3 2 is_true_true, l)
    end.

  Definition nat_p_message (n : 'I_3 * 'I_p_numNodes) :=
    let (i,j) := n in
    if nat_of_ord i == 0 then MsgStart else
    if nat_of_ord i == 1 then MsgBcast j
    else MsgEcho j.

  Lemma p_message_cancel : cancel p_message_nat nat_p_message .
  Proof.
      by case.
  Qed.

  Definition p_message_eqMixin      := CanEqMixin p_message_cancel.
  Canonical p_message_eqType        := Eval hnf in EqType (p_message) p_message_eqMixin.
  Canonical p_message_of_eqType     := Eval hnf in [eqType of p_message].
  Definition p_message_choiceMixin  := CanChoiceMixin p_message_cancel.
  Canonical p_message_choiceType    := Eval hnf in ChoiceType (p_message) p_message_choiceMixin.
  Canonical p_message_of_choiceType := Eval hnf in [choiceType of p_message].
  Definition p_message_countMixin   := CanCountMixin p_message_cancel.
  Canonical p_message_countType     := Eval hnf in CountType (p_message) p_message_countMixin.
  Canonical p_message_of_countType  := Eval hnf in [countType of p_message].
  Definition p_message_finMixin     := CanFinMixin p_message_cancel.
  Canonical p_message_finType       := Eval hnf in FinType (p_message) p_message_finMixin.
  Canonical p_message_of_finType    := Eval hnf in [finType of p_message].

  Inductive p_state :=
  (* records the number of received echos *)
  | StateEchos (n : 'I_p_numNodes).

  Definition num_echos (s : p_state) :=
    match s with
    | StateEchos n => n
    end.

  Definition inc_state (s : p_state) : p_state :=
    match inc (num_echos s) with
    | Some m => StateEchos m
    | None => s
    end.

  Definition p_state_nat (s : p_state) : 'I_p_numNodes := num_echos s.

  Definition nat_p_state (n : 'I_p_numNodes) := StateEchos n.

  Lemma p_state_cancel : cancel p_state_nat nat_p_state .
  Proof.
      by case.
  Qed.

  Definition p_state_eqMixin      := CanEqMixin p_state_cancel.
  Canonical p_state_eqType        := Eval hnf in EqType (p_state) p_state_eqMixin.
  Canonical p_state_of_eqType     := Eval hnf in [eqType of p_state].
  Definition p_state_choiceMixin  := CanChoiceMixin p_state_cancel.
  Canonical p_state_choiceType    := Eval hnf in ChoiceType (p_state) p_state_choiceMixin.
  Canonical p_state_of_choiceType := Eval hnf in [choiceType of p_state].
  Definition p_state_countMixin   := CanCountMixin p_state_cancel.
  Canonical p_state_countType     := Eval hnf in CountType (p_state) p_state_countMixin.
  Canonical p_state_of_countType  := Eval hnf in [countType of p_state].
  Definition p_state_finMixin     := CanFinMixin p_state_cancel.
  Canonical p_state_finType       := Eval hnf in FinType (p_state) p_state_finMixin.
  Canonical p_state_of_finType    := Eval hnf in [finType of p_state].

  Global Instance ProcParamsEx1 : ProcParams :=
    MkProcParams
      p_numNodes
      [finType of p_message]
      [finType of p_state].


  (* 0 echos *)
  Definition e0 := @Ordinal p_numNodes 0 is_true_true.
  (* 1 echo *)
  Definition e1 := @Ordinal p_numNodes 1 is_true_true.

  Definition p_InitStates : StateFun :=
    fun l => StateEchos e0.

  Definition loc0  : location := ord0.
  Definition time0 : time := ord0.

  Definition start : DMsg := MkDMsg loc0 loc0 time0 MsgStart.

  Definition p_InitMessages : MsgFun :=
    fun l => seq2queue (if l == loc0 then [start] else []).

  Definition p_Upd : UpdFun :=
    fun t l m s =>
      match m with
      | MsgStart =>
        (* send a bcast to everyone *)
        (s, seq2queue (fgraph (finfun (fun i => MkDMsg l i t (MsgBcast l)))))
      | MsgBcast i =>
        (* send an echo to bcast's sender *)
        (s, seq2queue [MkDMsg l i t (MsgEcho l)])
      | MsgEcho j =>
        (* count echos *)
        (inc_state s, emQueue)
      end.

  Global Instance SMParamsEx1 : SMParams :=
    MkSMParams
      p_InitStates
      p_InitMessages
      p_Upd.

  Definition received_1_echo (w : World) : bool :=
    let t := world_time w in
    match world_history w t with
    | Some g =>
      (* [loc0]'s state (the sender of the broadcast) *)
      let st := point_state (g loc0) in
      num_echos st == e1
    | None => false
    end.

  Lemma ex1 :
    exists (s : nat),
      forall (n : nat),
        (maxTime > n)%nat ->
        (n > s)%nat ->
        ((\sum_(i in 'I_p_numNodes) (1-LostDist) * (1-LostDist))%R
                         < Pr (steps2dist' n received_1_echo) (finset.set1 true))%R.
  Proof.
    exists (2 * (maxRound + 1))%nat; introv gtn ltn.
    destruct n; simpl in *.
    { assert False; tcsp. }

    { unfold steps2dist'; simpl.
      unfold Pr.
      rewrite finset.big_set1; simpl.
      rewrite FDistBindA; simpl.
      unfold step; simpl; unfold initHistory; simpl.
      rewrite ffunE; simpl.


  Abort.

  (* TODO: probability to receive 1 echo by some time *)
  Lemma ex2 :
    forall n,
      Pr (steps2dist'(*?*) n received_1_echo) (finset.set1 true)
      = (\sum_(t in 'I_maxRound.+1) (distRound t) * R1)%R.
  Proof.
  Abort.

(*  Lemma ex1 :
    forall n,
      Reals_ext.pos_ff (FDist.f (prb n received_1_echo)) true = R0.*)

End Ex1.


Section Ex2.

  (* ------------------------------------- *)
  (* Let us now prove properties of Pistis *)

  Context { pProba  : ProbaParams  }.
  Context { pBounds : BoundsParams }.
  Context { pSM     : SMParams     }.
  (* Instead of defining a concrete state machine, we assume one,
     and we will add constraints on its behavior *)


  Definition msgObs := message -> bool.

  (* True if a message satisfying [c] is sent at time [t] by node [n] in world [w]
   *)
  Definition disseminate (w : World) (n : location) (t : time) (c : msgObs) : bool :=
    let H := world_history w in
    let I := world_intransit w in
    match H t with
    | Some ps => (* [ps] is the world at the current time [t] *)
      (* we compute the messages that need to be computed at time [t] *)
      let qs := I t in
      (* We now apply the points in [ps] to the queues in [qs].
         We obtain new points and outgoing messages *)
      let (ps',out) := run_global t ps qs in
      existsb (fun d => (dmsg_src d == n) && c (dmsg_msg d)) out
    | None => false
    end.

  Definition startDisseminate (w : World) (n : location) (t : time) (c : msgObs) : Prop :=
    disseminate w n t c
    /\ forall (u : time), u < t -> ~disseminate w n u c.

  Definition startDisseminateDec (w : World) (n : location) (t : time) (c : msgObs) : bool :=
    disseminate w n t c
    && [forall (u : time | u < t), ~~disseminate w n u c].

  Lemma startDisseminateP :
    forall w n t c,
      reflect (startDisseminate w n t c) (startDisseminateDec w n t c).
  Proof.
    introv.
    remember (startDisseminateDec w n t c); symmetry in Heqb; destruct b;[left|right].

    { unfold startDisseminateDec, startDisseminate in *.
      move/andP in Heqb; repnd; dands; auto.
      move/forallP in Heqb; simpl in *.
      introv i.
      pose proof (Heqb u) as Heqb.
      move/implyP in Heqb.
      apply Heqb in i.
      apply/negP; auto. }

    unfold startDisseminateDec, startDisseminate in *.
    move/negP in Heqb.
    intro xx; destruct Heqb; apply/andP; repnd; dands;auto.
    apply/forallP.
    introv; apply/implyP; introv i; apply xx in i.
    apply/negP; auto.
  Qed.

  Definition startDisseminateBetween (w : World) (n : location) (t T : time) (c : msgObs) : Prop :=
    exists (u : time),
      t <= u
      /\ u < t + T
      /\ startDisseminate w n u c.

  Lemma startDisseminate_implies_disseminate :
    forall w n t c,
      startDisseminate w n t c
      -> disseminate w n t c.
  Proof.
    introv diss; destruct diss; auto.
  Qed.
  Hint Resolve startDisseminate_implies_disseminate : pistis.

  (* n disseminates [del] [K] times every [d] starting from [t] *)
  Fixpoint disseminateFor (w : World) (t : time) (n : location) (K d : nat) (c : msgObs) :=
    match K with
    | 0 => disseminate w n t c
    | S k =>
      disseminate w n t c
      && match inck t d with
         | Some u => disseminateFor w u n k d c
         | None => true (* if we ran out of time, we just assume that the predicate is true afterwards *)
         end
    end.

  (* [n] receives [c] as time [t] *)
  Definition receiveAt (w : World) (n : location) (t : time) (c : msgObs) : Prop :=
    Exists (fun m => c (dmsg_msg m)) (world_intransit w t n).

  (* [n] receives [c] between [t] and [t+T] *)
  Definition receiveBetween (w : World) (n : location) (t T : time) (c : msgObs) : Prop :=
    exists (u : time),
      t < u
      /\ u < t + T
      /\ receiveAt w n u c.

  Definition isCorrectAt (w : World) (n : location) (t : time) : bool :=
    let H := world_history w in
    match H t with
    | Some G => isCorrectStatus (point_status (G n))
    (* [G n] is cthe point at space time coordinate [n]/[t] *)
    | None => true
    end.

  Definition isCorrect (w : World) (n : location) : bool :=
    [forall t, isCorrectAt w n t].

  (*Definition isQuorum (l : list location) (Q : nat) :=
    length l = Q
    /\ no_repeats l.*)

  Definition Quorum (F : nat) := [finType of ((2*F)+1).-finList [finType of location]].

  (* [Q] is the size of quorums
     [K] is the number of times nodes disseminate [del] every [d] *)
  Definition IntersectingQuorum (w : World) (F K d : nat) (del : msgObs) :=
    forall (t : time) (n : location),
      isCorrect w n
      -> startDisseminate w n t del
      -> exists (Q : Quorum F) (u : time),
          u <= t + (K * d)
          /\ forall m,
            List.In m Q
            -> isCorrect w m
            -> exists (v : time),
                u <= v
                /\ v < u + d
                /\ disseminateFor w v m K d del.

  (* This is a property of the PISTIS's proof-of-connectivity component, where
     nodes become passive (considered faulty), when they don't receive answers
     back from a quorum of nodes, when sending a message.  Therefore, it must
     be that a Quorum received a message sent by a correct node by the time it
     was sent [t] plus [T], where [T] is the time bound by which a message is
     supposed to be received
   *)
  Definition proof_of_connectivity_condition (w : World) (F : nat) (T : time) :=
    forall (n : location) (t : time) (c : msgObs),
      isCorrect w n
      -> startDisseminate w n t c
      -> exists (A : Quorum F),
          forall (m : location),
            List.In m A
            -> receiveBetween w m t T c.

  Definition exStartDisseminateBefore (w : World) (t : time) (c : msgObs) : Prop :=
    exists (n : location) (u : time),
      (u < t)%coq_nat
      /\ isCorrect w n
      /\ startDisseminate w n u c.

  Definition exStartDisseminateBeforeDec (w : World) (t : time) (c : msgObs) : bool :=
    [exists n : location, exists u : time,
          (u < t)
          && isCorrect w n
          && startDisseminateDec w n u c].

  Lemma ex_node_start_del_dec :
    forall (w : World) (t : time) (c : msgObs),
      decidable (exStartDisseminateBefore w t c).
  Proof.
    introv.
    apply (@decP _ (exStartDisseminateBeforeDec w t c)).
    remember (exStartDisseminateBeforeDec w t c); symmetry in Heqb.
    destruct b;[left|right].

    { unfold exStartDisseminateBeforeDec, exStartDisseminateBefore in *.
      move/existsP in Heqb; simpl in *; exrepnd.
      exists x.
      move/existsP in Heqb0; simpl in *; exrepnd.
      exists x0.
      move/andP in Heqb1; repnd.
      move/andP in Heqb0; repnd.
      dands; auto.
      { apply/ltP; auto. }
      apply/startDisseminateP; auto. }

    unfold exStartDisseminateBeforeDec, exStartDisseminateBefore in *.
    move/existsP in Heqb.
    intro xx; destruct Heqb; simpl in *; exrepnd.
    exists n.
    apply/existsP; exists u.
    apply/andP; dands; auto.
    { apply/andP; dands; auto.
      apply/ltP; auto. }
    apply/startDisseminateP; auto.
  Qed.

  (* If a correct node receives a deliver it should start delivering
     if it hasn't started already doing so *)
  Definition mustStartDelivering (w : World) (del : msgObs) :=
    forall (n : location) (t : time),
      isCorrect w n
      -> receiveAt w n t del
      -> exists (u : time),
          u <= t
          /\ startDisseminate w n u del.

  (* If a node starts disseminating a message [c] at time [t]
     then it must do so until [t+(K*d)] *)
  Definition startDisseminateUntil (w : World) (c : msgObs) (K d : nat) :=
    forall (n : location) (t : time),
      isCorrect w n
      -> startDisseminate w n t c
      -> disseminateFor w t n K d c.

  (* For simplicity, we assume long enough worlds, where there is still some time
     (namely [T]), after a node starts disseminating
*)
  Definition longEnoughWorld (w : World) (c : msgObs) (T : nat) :=
    forall n t,
      startDisseminate w n t c
      -> t + T <= maxTime.

  Lemma existsNextStep :
    forall (t u : time) (K d : nat),
      d <> 0
      -> t <= u
      -> u < t + (K*d)
      -> exists (J : nat),
          t + (J*d) <= u
          /\ u < t + ((J+1)*d)
          /\ J + 1 <= K.
  Proof.
    introv dd0 h q.
    destruct t as [t ct].
    destruct u as [u cu].
    simpl in *.
    clear ct cu.
    assert (K <> 0) as kd0.
    { destruct K; simpl in *; auto.
      rewrite <- multE in q; simpl in *.
      rewrite <- plusE in q; simpl in *.
      rewrite Nat.add_0_r in q; auto.
      assert (t < t) as z by (eapply leq_ltn_trans; eauto).
      rewrite ltnn in z; tcsp. }

    exists ((u - t)/d); dands.
    { pose proof (Nat.mul_div_le (u - t) d dd0) as p.
      eapply (@leq_trans (t + (u - t)));[|rewrite subnKC; auto].
      rewrite leq_add2l.
      apply/leP; auto.
      rewrite Nat.mul_comm in p; auto. }
    { pose proof (Nat.mul_succ_div_gt (u-t) d dd0) as z; simpl in *.
      eapply (@leq_ltn_trans (t + (u - t)));[rewrite subnKC; auto|].
      rewrite ltn_add2l.
      apply/ltP; auto.
      rewrite Nat.mul_comm in z; auto.
      rewrite addn1; auto. }

    apply (@ltn_sub2r t) in q; auto.

    { rewrite <- addnBAC in q; auto.
      assert (t - t = 0) as w by (apply/eqP; rewrite subn_eq0; auto).
      rewrite w in q; clear w; simpl in q.
      rewrite <- plusE in q.
      rewrite Nat.add_0_l in q.
      rewrite <- multE in q.
      rewrite Nat.mul_comm in q.
      assert (u - t < (d * K)%coq_nat)%coq_nat as z by (apply/ltP; auto).
      apply Nat.div_lt_upper_bound in z; auto; clear q.
      rewrite addn1; apply/leP; auto. }

    remember (t + K *d); rewrite (plus_n_O t); subst.
    rewrite ltn_add2l; auto.
    destruct K, d; auto.
  Qed.

  Lemma eq_nat_of_ord_implies :
    forall (u v : time),
      nat_of_ord u = nat_of_ord v
      -> u = v.
  Proof.
    introv h.
    destruct u, v; simpl in *; subst; auto.
    assert (i = i0) by (apply UIP_dec; apply bool_dec); subst; auto.
  Qed.

  Lemma disseminateForLess :
    forall (w : World) (n : location) (K J d : nat) (u : time) (c : msgObs),
      J <= K
      -> disseminateFor w u n K d c
      -> disseminateFor w u n J d c.
  Proof.
    induction K; introv h diss.
    { assert (J = 0) as j0.
      { destruct J; auto.
        rewrite ltn0 in h; inversion h. }
      subst; simpl in *; auto. }

    simpl in *; move/andP in diss; repnd.
    destruct J; simpl in *; auto; apply/andP; dands; auto.
    remember (inck u d) as iu; destruct iu; symmetry in Heqiu; auto.
  Qed.

  Lemma disseminateForCovered :
    forall (w : World) (n : location) (K : nat) (u v : time) (c : msgObs) (I J d : nat),
      nat_of_ord v = (nat_of_ord u)+(I*d)
      -> I + J <= K
      -> disseminateFor w u n K d c
      -> disseminateFor w v n J d c.
  Proof.
    induction K; introv h q diss.
    { assert (I = 0) as i0.
      { destruct I; auto.
        rewrite <- plusE in q; simpl in q.
        rewrite ltn0 in q; inversion q. }
      assert (J = 0) as j0.
      { destruct J; auto.
        rewrite <- plusE, Nat.add_comm in q; simpl in q.
        rewrite ltn0 in q; inversion q. }
      subst; simpl in *.
      rewrite <- multE, <- plusE in h; simpl in h.
      rewrite Nat.add_0_r in h; subst.
      apply eq_nat_of_ord_implies in h; subst; auto. }

    destruct I.

    { rewrite <- plusE in q; simpl in q.
      rewrite <- plusE, <- multE in h; simpl in h.
      rewrite Nat.add_0_r in h; subst.
      apply eq_nat_of_ord_implies in h; subst; auto.
      eapply disseminateForLess; eauto. }

    simpl in *; move/andP in diss; repnd.
    remember (inck u d) as iu; destruct iu; symmetry in Heqiu.

    { pose proof (IHK o v c I J d) as IHK.
      repeat (autodimp IHK hyp).
      rewrite h.
      unfold inck in Heqiu.
      destruct (lt_dec (d + u) (maxTime.+1)); ginv; simpl in *.
      rewrite <- multE, <- plusE; simpl.
      rewrite <- (plus_comm u d).
      rewrite plus_assoc; auto. }

    unfold inck in *.
    destruct (lt_dec (d + u) (maxTime.+1)); ginv; simpl in *.
    destruct v as [v cv].
    destruct u as [u cu].
    simpl in *; subst.
    destruct n0.
    rewrite <- multE, <- plusE in cv; simpl in cv.
    apply/ltP.
    eapply leq_ltn_trans;[|eauto].
    rewrite <- plusE.
    rewrite plus_assoc.
    rewrite plus_comm.
    apply leq_addr.
  Qed.

  (* This is one of main properties required to prove timeliness.
   *)
  Lemma IntersectingQuorum_true (del : msgObs) :
    forall (w : World) (F K d : nat) (p : K*d < maxTime.+1),
      (* assuming that there are 3F+1 nodes *)
      numNodes = (3*F)+1
      (* the maximum transmission delay [d] is not 0 *)
      -> d <> 0
      (* that the world is long enough to allow for deliveries to end *)
      -> longEnoughWorld w del (2*(K*d))
      (* that we're running proof of connectivity *)
      -> proof_of_connectivity_condition w F (toI(p))
      (* that received nodes are eventually relayed *)
      -> mustStartDelivering w del
      (* that deliver messages are delivered twice as long as the PoC, which is used in 'IntersectingQuorum' *)
      -> startDisseminateUntil w del (2*K) d
      (* then the 'IntersectingQuorum' property holds *)
      -> IntersectingQuorum w F K d del.
  Proof.
    introv nnodes dd0 lw poc startD dissU.
    introv.
    destruct t as [t ct].
    revert dependent n.
    induction t as [? ind] using comp_ind; introv cor diss.
    destruct (ex_node_start_del_dec w (toI ct) del) as [z|z].

    { unfold exStartDisseminateBefore in z; exrepnd.
      pose proof (ind u) as ind; simpl in *.
      autodimp ind hyp.
      destruct u as [u cu].
      pose proof (ind cu n0) as ind.
      repeat (autodimp ind hyp; auto).

      exrepnd.
      exists Q u0; dands; auto.
      eapply leq_trans; eauto.
      apply leq_add; auto.
      apply/leP; apply Nat.lt_le_incl; auto. }

    assert (forall (n : location) (u : time),
               (u < t)%coq_nat -> isCorrect w n -> ~startDisseminate w n u del) as z'.
    { introv ltu corn dis; destruct z; exists n0 u; auto. }
    clear z; rename z' into z.

    pose proof (poc n (toI ct) del) as poc; simpl in *.
    repeat (autodimp poc hyp); eauto 3 with pistis.
    exrepnd.

    (* since no correct nodes start disseminating before [t] it must be that
       all correct nodes in A start disseminating starting from [t]
     *)
    assert (forall (n : location),
               isCorrect w n
               -> List.In n A
               -> startDisseminateBetween w n (toI ct) (toI p) del) as z'.
    { introv isc i.
      pose proof (poc0 _ i) as poc0.
      unfold receiveBetween in poc0; exrepnd.
      pose proof (startD n0 u) as startD.
      repeat (autodimp startD hyp); exrepnd.
      destruct (lt_dec u0 t) as [ltu|ltu].
      { pose proof (z _ _ ltu isc) as z; tcsp. }
      assert (~(u0 < t)) as ltu' by (intro xx; destruct ltu; apply/ltP; auto).
      assert (t <= u0) as leu by (rewrite leqNgt; apply/negP; auto).
      clear ltu ltu'.
      exists u0.
      dands; auto.
      eapply leq_ltn_trans; eauto. }

    pose proof (lw n (toI ct) diss) as lw0.

    assert (t + (K*d) < maxTime.+1) as ct'.
    { assert (t + (K*d) <= maxTime) as ct'; auto.
      eapply leq_trans;[|eauto]; simpl.
      rewrite leq_add2l.
      apply leq_pmull; auto. }

    exists A (toI ct'); dands; simpl; auto; try apply leq_addr.
    introv i isc.

    pose proof (z' _ isc i) as z'.
    unfold startDisseminateBetween in z'; exrepnd.
    pose proof (dissU _ _ isc z'0) as dissU.

    pose proof (existsNextStep (toI ct) u K d) as ens.
    repeat (autodimp ens hyp); exrepnd.

    pose proof (lw m u z'0) as lw1.
    rewrite addn1 in ens0; auto.

    assert (u + ((K-J)*d) < maxTime.+1) as cu.
    { assert (u + ((K-J)*d) <= maxTime) as cu; auto.
      eapply leq_trans;[|eauto]; simpl.
      rewrite leq_add2l.
      rewrite <- (Nat.mul_1_l ((K-J)*d)).
      apply leq_mul; auto.
      apply leq_mul; auto.
      apply leq_subr. }

    exists (toI cu); simpl in *.
    dands; auto.

    { apply (@leq_add _ ((K-J)*d) _ ((K-J)*d)) in ens1; auto.
      eapply leq_trans;[|eauto].
      rewrite <- plus_assoc.
      rewrite <- multE.
      rewrite <- Nat.mul_add_distr_r.
      rewrite <- minusE.
      rewrite <- le_plus_minus; auto.
      apply/leP; auto. }

    { rewrite <- (ltn_add2r ((K-J)*d)) in ens2.
      rewrite <- plus_assoc in ens2.
      rewrite <- multE, <- plusE, <- minusE in ens2.
      rewrite <- Nat.mul_add_distr_r in ens2.
      rewrite (Nat.add_comm J 1) in ens2.
      rewrite <- plus_assoc in ens2.
      rewrite <- le_plus_minus in ens2; auto.
      { rewrite Nat.mul_add_distr_r in ens2; simpl in ens2.
        rewrite Nat.add_0_r in ens2.
        rewrite (Nat.add_comm d _) in ens2; auto.
        rewrite <- multE, <- plusE, <- minusE; auto.
        rewrite <- plus_assoc; auto. }
      apply/leP; auto. }

    eapply (disseminateForCovered _ _ _ _ _ _ (K-J)); try exact dissU; simpl; auto.
    rewrite addnBAC; auto.
    rewrite <- multE, <- minusE, <- plusE; simpl.
    rewrite Nat.add_0_r.
    apply/leP; apply Nat.le_sub_l.
  Qed.

End Ex2.


(*
  (* combine loose and deliver and use a binary probability *)
  (* Also combine rotate?  Where we rotate randomly? *)
  Inductive Action :=
  (* loose 1st message in transit *)
  | act_loose (*(n : 'I_maxPoints)*)

  (* rotates the in transit messages *)
  | act_rotate

  (* deliver in transit message*)
  | act_deliver.

  Definition step (w : World) (a : Action) : Comp [finType of (option World)] :=
    match a with
    | act_loose => (* loose the first message in transit *)
      let itr := world_intransit w in
      let (op,k) := splitFL _ _ itr in
      let w' := upd_intransit w k in
      Ret (Some w')

    | act_rotate => (* rotates in transit messages *)
      let itr := world_intransit w in
      let k := rotateFL _ _ itr in
      let w' := upd_intransit w k in
      Ret (Some w')

    | act_deliver => (* deliver 1st message in transit *)
      let itr := world_intransit w in
      let (op,k) := splitFL _ _ itr in
      let w' := upd_intransit w k in
      match op with
      | Some m =>
        Bind pickRound
             (fun (n : 'I_(maxRound.+1)) =>
                let dst := dmsg_dst m in
                Ret (Some w'))
      | None => Ret (Some w')
      end
    end.
*)



  (*Definition maxPoints : nat := maxTime * numNodes.*)

(*
  (* Triggers of points *)
  Inductive Trigger :=
  | TriggerMsg (m : message)
  | TriggerArbitrary.

  Definition Trigger_opt (t : Trigger) :=
    match t with
    | TriggerMsg m => Some m
    | TriggerArbitrary => None
    end.

  Definition opt_Trigger o :=
    match o with
    | Some m => TriggerMsg m
    | None => TriggerArbitrary
    end.

  Lemma Trigger_cancel : cancel Trigger_opt opt_Trigger .
  Proof.
      by case.
  Qed.

  Definition Trigger_eqMixin      := CanEqMixin Trigger_cancel.
  Canonical Trigger_eqType        := Eval hnf in EqType (Trigger) Trigger_eqMixin.
  Canonical trigger_of_eqType     := Eval hnf in [eqType of Trigger].
  Definition Trigger_choiceMixin  := CanChoiceMixin Trigger_cancel.
  Canonical Trigger_choiceType    := Eval hnf in ChoiceType (Trigger) Trigger_choiceMixin.
  Canonical trigger_of_choiceType := Eval hnf in [choiceType of Trigger].
  Definition Trigger_countMixin   := CanCountMixin Trigger_cancel.
  Canonical Trigger_countType     := Eval hnf in CountType (Trigger) Trigger_countMixin.
  Canonical trigger_of_countType  := Eval hnf in [countType of Trigger].
  Definition Trigger_finMixin     := CanFinMixin Trigger_cancel.
  Canonical Trigger_finType       := Eval hnf in FinType (Trigger) Trigger_finMixin.
  Canonical trigger_of_finType    := Eval hnf in [finType of Trigger].
*)


(*
  Record TGlobal :=
    MkTGlobal
      {
        (* global time *)
        tglobal_time : 'I_maxTime;

        (* current state of the nodes *)
        tglobal_points : Global;
      }.

  Definition TGlobal_prod (g : TGlobal) :=
    (tglobal_time g,
     tglobal_points g).

  Definition prod_TGlobal prod :=
    let: (tglobal_time,
          tglobal_points) := prod in
    MkTGlobal
      tglobal_time
      tglobal_points.

  Lemma TGlobal_cancel : cancel TGlobal_prod prod_TGlobal .
  Proof.
      by case.
  Qed.

  Definition TGlobal_eqMixin      := CanEqMixin TGlobal_cancel.
  Canonical TGlobal_eqType        := Eval hnf in EqType (TGlobal) TGlobal_eqMixin.
  Canonical tglobal_of_eqType     := Eval hnf in [eqType of TGlobal].
  Definition TGlobal_choiceMixin  := CanChoiceMixin TGlobal_cancel.
  Canonical TGlobal_choiceType    := Eval hnf in ChoiceType (TGlobal) TGlobal_choiceMixin.
  Canonical tglobal_of_choiceType := Eval hnf in [choiceType of TGlobal].
  Definition TGlobal_countMixin   := CanCountMixin TGlobal_cancel.
  Canonical TGlobal_countType     := Eval hnf in CountType (TGlobal) TGlobal_countMixin.
  Canonical tglobal_of_countType  := Eval hnf in [countType of TGlobal].
  Definition TGlobal_finMixin     := CanFinMixin TGlobal_cancel.
  Canonical TGlobal_finType       := Eval hnf in FinType (TGlobal) TGlobal_finMixin.
  Canonical tglobal_of_finType    := Eval hnf in [finType of TGlobal].
*)



(* TODO:

- Allow external messages
- Separate worlds from computations?

*)
