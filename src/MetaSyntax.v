Require Import Syntax Wf Struct List Inline SimpleInline Coq.Arith.Peano_dec Lib.Indexer
FunctionalExtensionality String Equiv.

Set Implicit Arguments.

Fixpoint concat A (ls: list (list A)) :=
  match ls with
    | x :: xs => x ++ concat xs
    | nil => nil
  end.

Section MetaDefns.
  Variable A: Type.

  Inductive MetaDefn :=
  | One (_: Attribute A)
  | Rep (_: string) (_: nat -> A) (_: nat).

  Fixpoint getListFromRep s (f: nat -> A) n :=
    match n with
      | 0 => nil
      | S i => {| attrName := s __ i;
                  attrType := f i |} :: getListFromRep s f i
    end.

  Definition getListFromMeta m :=
    match m with
      | One a => a :: nil
      | Rep s f n => getListFromRep s f n
    end.
  
  Fixpoint getFullListFromMeta m  :=
    match m with
      | x :: xs => getListFromMeta x ++ getFullListFromMeta xs
      | nil => nil
    end.

  Fixpoint getNamesOfMeta m :=
    match m with
      | One a => attrName a
      | Rep s _ _ => s
    end.
End MetaDefns.

Definition MetaReg := MetaDefn (sigT ConstFullT).

Definition MetaRule := MetaDefn (Action Void).

Definition MetaMeth := MetaDefn (sigT MethodT).

Record MetaModule :=
  { metaRegs: list MetaReg;
    metaRules: list MetaRule;
    metaMeths: list MetaMeth
  }.

Definition makeModule (m: MetaModule) :=
  Mod (getFullListFromMeta (metaRegs m))
      (getFullListFromMeta (metaRules m))
      (getFullListFromMeta (metaMeths m)).

Definition metaInlineDmToRule (inDm: MetaMeth) (r': MetaRule) :=
  match r', inDm with
    | One r, One dm => One (inlineDmToRule r dm) :: nil
    | Rep sr fr n, Rep sf ff m =>
      match eq_nat_dec n m with
        | left _ => Rep sr (fun i ty => inlineDm (fr i ty) {| attrName := sf __ i;
                                                              attrType := ff i |}) n :: nil
        | right _ => map (@One _) (fold_left inlineDmToRules (getListFromMeta inDm)
                                             (getListFromMeta r'))
      end
    | Rep sr fr n, One dm => Rep sr (fun i ty => inlineDm (fr i ty) dm) n :: nil
    | One r, Rep sf ff m => One (fold_left inlineDmToRule (getListFromMeta inDm) r) :: nil
  end.

Definition metaInlineDmToDm (inDm: MetaMeth) (g': MetaMeth) :=
  match g', inDm with
    | One g, One dm => One (inlineDmToDm g dm) :: nil
    | Rep sg fg n, Rep sf ff m =>
      match eq_nat_dec n m with
        | left _ =>
          Rep sg (fun i =>
                    existT MethodT (projT1 (fg i))
                           (fun ty argv =>
                              inlineDm (projT2 (fg i) ty argv)
                                       {| attrName := sf __ i;
                                          attrType := ff i |})) n :: nil
        | right _ => map (@One _) (fold_left inlineDmToDms (getListFromMeta inDm)
                                             (getListFromMeta g'))
      end
    | Rep sg fg n, One dm =>
      Rep sg (fun i =>
                existT MethodT (projT1 (fg i))
                       (fun ty argv =>
                          inlineDm (projT2 (fg i) ty argv) dm)) n :: nil
    | One g, Rep sf ff m => One (fold_left inlineDmToDm (getListFromMeta inDm) g) :: nil
  end.

Lemma commuteInlineDmRules:
  forall rules meths,
    fold_left inlineDmToRules meths rules =
    map (fun rule => fold_left inlineDmToRule meths rule) rules.
Proof.
  induction rules; simpl in *; intros.
  - induction meths; simpl in *.
    + reflexivity.
    + assumption.
  - specialize (IHrules meths).
    rewrite <- IHrules.
    clear IHrules.
    generalize a rules; clear.
    induction meths; simpl in *; intros.
    + reflexivity.
    + specialize (IHmeths (inlineDmToRule a0 a) (inlineDmToRules rules a)).
      assumption.
Qed.

Lemma commuteInlineDmMeths:
  forall rs meths,
    fold_left inlineDmToDms meths rs =
    map (fun r => fold_left inlineDmToDm meths r) rs.
Proof.
  induction rs; simpl in *; intros.
  - induction meths; simpl in *.
    + reflexivity.
    + assumption.
  - specialize (IHrs meths).
    rewrite <- IHrs.
    clear IHrs.
    generalize a rs; clear.
    induction meths; simpl in *; intros.
    + reflexivity.
    + specialize (IHmeths (inlineDmToDm a0 a) (inlineDmToDms rs a)).
      assumption.
Qed.

Definition getCallsMAction (dm: sigT MethodT) :=
  getCallsA (projT2 dm typeUT tt).

Definition metaRuleEquiv (t1 t2: Kind -> Type) (r: MetaRule) : Prop :=
  match r with
    | One r' => forall G,
                  ActionEquiv G (attrType r' t1) (attrType r' t2)
    | Rep s f n => forall i G, ActionEquiv G (f i t1) (f i t2)
  end.

Definition metaMethEquiv (t1 t2: Kind -> Type) (f: MetaMeth) : Prop :=
  match f with
    | One g => forall (argV1: fullType t1 (SyntaxKind (arg (projT1 (attrType g)))))
                      (argV2: fullType t2 (SyntaxKind (arg (projT1 (attrType g))))) G,
                 ActionEquiv (vars argV1 argV2 :: G)
                             (projT2 (attrType g) t1 argV1)
                             (projT2 (attrType g) t2 argV2)
    | Rep s g n => forall i
                          (argV1: fullType t1 (SyntaxKind (arg (projT1 (g i)))))
                          (argV2: fullType t2 (SyntaxKind (arg (projT1 (g i))))) G,
                     ActionEquiv (vars argV1 argV2 :: G)
                                 (projT2 (g i) t1 argV1)
                                 (projT2 (g i) t2 argV2)
  end.

Lemma getFullListFromMetaCommute A (ls: list (Attribute A)):
  getFullListFromMeta (map (@One _) ls) = ls.
Proof.
  induction ls; simpl in *.
  - reflexivity.
  - f_equal; assumption.
Qed.

Section NoBadCalls.
  Variable m: MetaModule.
  Variable rulesEquiv: forall ty r, In r (metaRules m) -> metaRuleEquiv ty typeUT r.
  Variable methsEquiv: forall ty f, In f (metaMeths m) -> metaMethEquiv ty typeUT f.

  Variable noBadCallsInRules:
    forall sr fr n , In (Rep sr fr n) (metaRules m) ->
                     forall s i j,
                       In (s __ j) (getCallsA (fr i typeUT)) ->
                       i = j.

  Variable noBadCallsInMeths:
    forall sr fr n , In (Rep sr fr n) (metaMeths m) ->
                     forall s i j,
                       In (s __ j) (getCallsMAction (fr i)) ->
                       i = j.

  Lemma singleInlineRule:
    forall sr fr sg fg n,
      In (Rep sr fr n) (metaRules m) ->
      In (Rep sg fg n) (metaMeths m) ->
      (fun i ty => inlineDm (fr i ty) (sg __ i :: fg i)%struct) =
      fun i =>
        attrType (fold_left inlineDmToRule (getListFromRep sg fg n) (sr __ i :: fr i)%struct).
  Proof.
    admit.
  Qed.

  Lemma singleInlineMeth:
    forall sr fr sg fg n,
      In (Rep sr fr n) (metaMeths m) ->
      In (Rep sg fg n) (metaMeths m) ->
      (fun i =>
         existT MethodT (projT1 (fr i))
                (fun ty argv =>
                   inlineDm (projT2 (fr i) ty argv) (sg __ i :: fg i)%struct)) =
      fun i =>
        attrType (fold_left inlineDmToDm (getListFromRep sg fg n) (sr __ i :: fr i)%struct).
  Proof.
    admit.
  Qed.
      
  Lemma metaInlineDmToRule_matches inDm r:
    In r (metaRules m) ->
    In inDm (metaMeths m) ->
    getFullListFromMeta (metaInlineDmToRule inDm r) =
    fold_left inlineDmToRules (getListFromMeta inDm) (getListFromMeta r).
  Proof.
    intros.
    unfold metaInlineDmToRule.
    destruct inDm, r; subst; auto; simpl in *.
    - clear; rewrite app_nil_r.
      induction n; simpl in *.
      + intuition.
      + f_equal.
        intuition.
    - clear; generalize a; clear a.
      induction (getListFromRep s s0 n); simpl in *; intros.
      + reflexivity.
      + apply (IHl (inlineDmToRule a0 a)).
    - destruct (eq_nat_dec n0 n); subst; simpl in *.
      specialize (@noBadCallsInRules s1 a n).
      + rewrite app_nil_r.
        rewrite commuteInlineDmRules; simpl in *.
        rewrite singleInlineRule with (sr := s1) (n := n) by assumption.
        clear.
        generalize (getListFromRep s s0 n).
        induction n; intros; simpl in *.
        * reflexivity.
        * { f_equal.
            - assert (sth: s1 __ n = attrName (s1 __ n :: a n)%struct) by reflexivity.
              rewrite sth at 1.
              generalize (s1 __ n :: a n)%struct.
              clear; induction l; simpl in *; intros.
              + destruct a; reflexivity.
              + apply (IHl (inlineDmToRule a0 a)).
            - apply IHn.
          }
      + clear.
        induction (fold_left inlineDmToRules (getListFromRep s s0 n)
                             (getListFromRep s1 a n)); simpl in *.
        * rewrite commuteInlineDmRules; simpl in *.
          rewrite getFullListFromMetaCommute.
          reflexivity.
        * assumption.
  Qed.

  Lemma metaInlineDmToDm_matches inDm r:
    In r (metaMeths m) ->
    In inDm (metaMeths m) ->
    getFullListFromMeta (metaInlineDmToDm inDm r) =
    fold_left inlineDmToDms (getListFromMeta inDm) (getListFromMeta r).
  Proof.
    intros.
    unfold metaInlineDmToDm.
    destruct inDm, r; subst; auto; simpl in *.
    - clear; rewrite app_nil_r.
      induction n; simpl in *.
      + intuition.
      + f_equal.
        intuition.
    - clear; generalize a; clear a.
      induction (getListFromRep s s0 n); simpl in *; intros.
      + reflexivity.
      + apply (IHl (inlineDmToDm a0 a)).
    - destruct (eq_nat_dec n0 n); subst; simpl in *.
      specialize (@noBadCallsInMeths s1 s2 n).
      + rewrite app_nil_r.
        rewrite commuteInlineDmMeths; simpl in *.
        rewrite singleInlineMeth with (sr := s1) (n := n) by assumption.
        clear.
        generalize (getListFromRep s s0 n).
        induction n; intros; simpl in *.
        * reflexivity.
        * { f_equal.
            - assert (sth: s1 __ n = attrName (s1 __ n :: s2 n)%struct) by reflexivity.
              rewrite sth at 1.
              generalize (s1 __ n :: s2 n)%struct.
              clear; induction l; simpl in *; intros.
              + destruct a; reflexivity.
              + apply (IHl (inlineDmToDm a0 a)).
            - apply IHn.
          }
      + clear.
        induction (fold_left inlineDmToDms (getListFromRep s s0 n)
                             (getListFromRep s1 s2 n)); simpl in *.
        * rewrite commuteInlineDmMeths; simpl in *.
          rewrite getFullListFromMetaCommute.
          reflexivity.
        * assumption.
  Qed.

  Definition metaInlineDmToMod inDm :=
    {| metaRegs := metaRegs m;
       metaRules := concat (map (metaInlineDmToRule inDm) (metaRules m));
       metaMeths := concat (map (metaInlineDmToDm inDm) (metaMeths m)) |}.

End NoBadCalls.

Fixpoint metaInlineDmsToMod m (inDms: list MetaMeth) :=
  match inDms with
    | x :: xs => metaInlineDmsToMod (metaInlineDmToMod m x) xs
    | nil => m
  end.

Definition metaInline m :=
  metaInlineDmsToMod m (metaMeths m).

(*
Lemma simpleInlineDmsToMod_app dms1:
  forall dms2 m,
    simpleInlineDmsToMod (Modm (dms1 ++ dms2) =
    simpleInlineDmsToMod (simpleInlineDmsToMod m dms1) dms2.
Proof.
  induction dms1; simpl in *; intros.
  - intuition.
  - specialize (IHdms1 dms2 (simpleInlineDmToMod m a)).
    assumption.
Qed.
*)

Section MetaModule.
  Lemma metaInline_matches dms:
    forall m,
      makeModule (metaInlineDmsToMod m dms) =
      simpleInlineDmsToMod (makeModule m) (getFullListFromMeta dms).
  Proof.
    unfold makeModule; simpl in *.
    induction dms; simpl in *; intros.
    - reflexivity.
    - (* rewrite simpleInlineDmsToMod_app.
      specialize (IHdms (metaInlineDmToMod m a)); simpl in *.
      rewrite IHdms.
      f_equal.
      clear.
      unfold simpleInlineDmsToMod, simpleInlineDmToMod. *)
      admit.
  Qed.

  Variable m: MetaModule.
  Variable rulesEquiv: forall ty r, In r (metaRules m) -> metaRuleEquiv ty typeUT r.
  Variable methsEquiv: forall ty f, In f (metaMeths m) -> metaMethEquiv ty typeUT f.

  Variable noBadCallsInRules:
    forall sr fr n , In (Rep sr fr n) (metaRules m) ->
                     forall s i j,
                       In (s __ j) (getCallsA (fr i typeUT)) ->
                       i = j.

  Variable noBadCallsInMeths:
    forall sr fr n , In (Rep sr fr n) (metaMeths m) ->
                     forall s i j,
                       In (s __ j) (getCallsMAction (fr i)) ->
                       i = j.

  Variable noOneInteralCallsInRepMeth:
    forall sr fr n, In (Rep sr fr n) (metaMeths m) ->
                    forall s i,
                      In s (getCallsMAction (fr i)) ->
                      In s (map (@getNamesOfMeta _) (metaMeths m)) ->
                      False.

  Variable noRepInteralCallsInRepMeth:
    forall sr fr n, In (Rep sr fr n) (metaMeths m) ->
                    forall s i,
                      In (s __ i) (getCallsMAction (fr i)) ->
                      In s (map (@getNamesOfMeta _) (metaMeths m)) ->
                      False.

  Variable noOneInteralCallsInOneMeth:
    forall r, In (One r) (metaMeths m) ->
              forall s,
                In s (getCallsMAction (attrType r)) ->
                In s (map (@getNamesOfMeta _) (metaMeths m)) ->
                False.

  Variable noRepInteralCallsInOneMeth:
    forall r, In (One r) (metaMeths m) ->
              forall s i,
                In (s __ i) (getCallsMAction (attrType r)) ->
                In s (map (@getNamesOfMeta _) (metaMeths m)) ->
                False.

End MetaModule.