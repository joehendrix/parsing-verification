
namespace Nat

def forallLt' (n:Nat) (f: ∀(i:Nat), i < n → Bool) : Nat → Bool
| i =>
  if h:i < n then
    f i h && forallLt' n f (i+1)
  else
    true
  termination_by forallLt' n f i => n-i

--set_option pp.all true

--theorem Eq.subst {α : Sort u} {motive : α → Prop} {a b : α} (h₁ : Eq a b) (h₂ : motive a) : motive b :=
--  Eq.ndrec h₂ h₁

theorem forallLtImplies' :
  ∀ (n i j : Nat)
          (f : ∀(k:Nat), k < n → Bool)
          (eq : i+j = n)
          (p:forallLt' n f i = true)
          (k : Nat)
          (lb : i ≤ k)
          (ub : k < n), f k ub = true := by

  intro n i j f
  revert i
  induction j  with
  | zero =>
    intro i eq p k lb ub
    simp at eq
    simp [eq] at lb
    have pr := Nat.not_le_of_gt ub
    contradiction
  | succ j ind =>
    intros i n_eq ltPred k lb ub
    have i_lt_n : i < n := Nat.le_trans (Nat.succ_le_succ lb) ub
    unfold forallLt' at ltPred
    simp [i_lt_n] at ltPred
    cases Nat.eq_or_lt_of_le lb with
    | inl hEq =>
      apply Eq.subst
      apply ltPred.left
      simp only [hEq]
    | inr hLt =>
      have succ_i_add_j : succ i + j = n := by
        simp [Nat.succ_add]
        exact n_eq
      apply ind (succ i) succ_i_add_j ltPred.right _ hLt

def forallLt (n:Nat) (f: ∀(i:Nat), i < n → Bool) : Bool := Nat.forallLt' n f 0

theorem forallLtImplies (p:forallLt n f = true) (i:Nat) (lt : i < n)
  : f i lt = true := forallLtImplies' n 0 n f (Nat.zero_add n) p i (Nat.zero_le i) lt

theorem lt_or_eq_of_succ {i j:Nat} (lt : i < Nat.succ j) : i < j ∨ i = j :=
  match lt with
  | Nat.le.step m => Or.inl m
  | Nat.le.refl => Or.inr rfl

theorem strong_induction_on {p : Nat → Prop} (n:Nat)
  (h:∀n, (∀ m, m < n → p m) → p n) : p n := by
    suffices ∀n m, m < n → p m from this (succ n) n (Nat.lt_succ_self _)
    intros n
    induction n with
    | zero =>
      intros m h
      contradiction
    | succ i ind =>
      intros m h1
      cases Nat.lt_or_eq_of_succ h1 with
      | inl is_lt =>
        apply ind _ is_lt
      | inr is_eq =>
        apply h
        rw [is_eq]
        apply ind

end Nat


theorem Fin.strong_induction_on {P : Fin w → Prop} (i:Fin w)
  (ind : ∀(i:Fin w), (∀(j:Fin w), j < i → P j) → P i)
 : P i := by
   cases i with
   | mk i i_lt =>
     revert i_lt
     apply @Nat.strong_induction_on (λi => ∀ (i_lt : i < w), P { val := i, isLt := i_lt })
     intros j p j_lt_w
     apply ind ⟨j, j_lt_w⟩
     intros z z_lt_j
     apply p _ z_lt_j

inductive Expression (t : Type) (nt : Type) where
| epsilon{} : Expression t nt
| fail : Expression t nt
| any : Expression t nt
| terminal : t → Expression t nt
| seq : (a b : nt) → Expression t nt
| choice : (a b : nt) → Expression t nt
| look : (a : nt) → Expression t nt
| notP : (e : nt) → Expression t nt

open Expression

def Grammar (t nt : Type _) := nt → Expression t nt

structure ProofRecord  (nt : Type) where
  (leftnonterminal : nt)
  (success : Bool)
  (position : Nat)
  (lengthofspan : Nat)
  (subproof1index : Nat)
  (subproof2index : Nat)


inductive Result where
| fail : Result
| success : Nat → Result

namespace ProofRecord

def endposition {nt:Type} (r:ProofRecord nt) : Nat := r.position + r.lengthofspan

def record_result (r:ProofRecord nt) : Result :=
  if r.success then
    Result.success r.lengthofspan
  else
    Result.fail

end ProofRecord

def PreProof (nt : Type) := Array (ProofRecord nt)

section

def record_match [dnt : DecidableEq nt] (r:ProofRecord nt) (n:nt) (i:Nat) : Bool :=
  r.leftnonterminal = n && r.position = i

section

variable {t nt : Type}
variable [dt : DecidableEq t]
variable [dnt : DecidableEq nt]
variable (g : Grammar t nt)
variable (s : Array t)
variable (p : PreProof nt)

def well_formed_record (i:Nat) (i_lt : i < p.size) (r : ProofRecord nt) : Bool :=
  let n := r.leftnonterminal
  match g n with
  | epsilon _ _ => r.success ∧ r.lengthofspan = 0
  | fail => ¬ r.success
  | any =>
    if r.position < s.size then
      r.success && r.lengthofspan = 1
    else
      ¬ r.success
  | terminal t =>
    if r.position < s.size && s.getD r.position t = t then
      r.success && r.lengthofspan = 1
    else
      ¬ r.success
  | seq a b =>
    r.subproof1index < i &&
      let r1 := p.getD r.subproof1index r
      record_match r1 a r.position &&
        if r1.success then
          r.subproof2index < i &&
            let r2 := p.getD r.subproof2index r
            record_match r2 b r1.endposition &&
              if r2.success then
                r.success && r.endposition = r2.endposition
              else
                ¬r.success
        else
          ¬r.success
  | choice a b =>
    r.subproof1index < i &&
      let r1 := p.getD r.subproof1index r
      record_match r1 a r.position &&
        if r1.success then
          r.success && r.lengthofspan = r1.lengthofspan
        else
          r.subproof2index < i &&
            let r2 := p.getD r.subproof2index r
            record_match r2 b r.position &&
              if r2.success then
                r.success && r.lengthofspan = r2.lengthofspan
              else
                ¬r.success
  | look a =>
    r.subproof1index < i &&
      let r1 := p.getD r.subproof1index r
      record_match r1 a r.position &&
        if r1.success then
          r.success && r.lengthofspan = 0
        else
          ¬r.success
  | notP a =>
    r.subproof1index < i &&
      let r1 := p.getD r.subproof1index r
      record_match r1 a r.position &&
        if r1.success then
          ¬r.success
        else
          r.success && r.lengthofspan = 0

end

def well_formed_proof [DecidableEq nt] [DecidableEq t] (g: Grammar t nt) (s : Array t)
      (p : PreProof nt) : Bool :=
  Nat.forallLt p.size (λi lt => well_formed_record g s p i lt (p.get ⟨i, lt⟩))

def Proof {t} {nt} [DecidableEq t] [DecidableEq nt] (g:Grammar t nt) (s: Array t) :=
  { p:PreProof nt // well_formed_proof g s p }

namespace Proof

variable {g:Grammar t nt}
variable {s : Array t}
variable [DecidableEq t]
variable [DecidableEq nt]

def size (p:Proof g s) := p.val.size

def get (p:Proof g s) : Fin p.size → ProofRecord nt := p.val.get

instance : CoeFun (Proof g s) (fun p => Fin p.size → ProofRecord nt) :=
  ⟨fun p => p.get⟩

theorem has_well_formed_record (p:Proof g s) (i:Fin p.size) :
  well_formed_record g s p.val i.val i.isLt (p i) :=
    Nat.forallLtImplies p.property i.val i.isLt

end Proof

variable {g:Grammar t nt}
variable {s : Array t}
variable [h1:DecidableEq t]
variable [h2:DecidableEq nt]

-- Lemma to rewrite from dependent use of proof index to get-with-default
theorem proof_get_to_getD (r:ProofRecord nt) (p:Proof g s) (i:Fin p.size)  :
  p i = p.val.getD i.val r := by
  have isLt : i.val < Array.size p.val := i.isLt
  simp [Proof.get, Array.get, Array.getD, isLt ]
  apply congrArg
  apply Fin.eq_of_val_eq
  trivial

theorem match_same
  : forall (p q : Proof g s) (i: Fin p.size) (j: Fin q.size),
      (p i).leftnonterminal = (q j).leftnonterminal
      → (p i).position      = (q j).position
      → (p i).record_result = (q j).record_result := by
  intros p q i0
  apply @Fin.strong_induction_on _
    (λi =>
      ∀ (j : Fin q.size),
          (p i).leftnonterminal = (q j).leftnonterminal
        → (p i).position        = (q j).position
        → (p i).record_result   = (q j).record_result) i0
  intros i ind j eq_nt p_pos_eq_q_pos
  have p_def := p.has_well_formed_record i
  have q_def := q.has_well_formed_record j
  simp only [well_formed_record, eq_nt, p_pos_eq_q_pos] at p_def q_def
  generalize q_j_eq : q j = q_j
  generalize e_eq : g (q_j.leftnonterminal) = e
  simp only [q_j_eq, e_eq] at p_def q_def p_pos_eq_q_pos
  simp only [ProofRecord.record_result]
  cases e with
  | epsilon =>
     simp at p_def q_def
     simp [p_def, q_def]
  | fail =>
     simp at p_def q_def
     simp [p_def, q_def]
  | any =>
    by_cases is_lt : q_j.position < s.size <;>
      simp [is_lt] at p_def q_def <;>
      simp [p_def, q_def]
  | terminal t =>
    simp only at p_def q_def
    cases Decidable.em (q_j.position < s.size) with
    | inl is_lt =>
      cases Decidable.em (s.getD q_j.position t = t) with
      | inl is_t =>
        simp [is_lt, is_t] at p_def q_def
        simp [p_def, q_def]
      | inr not_t =>
        simp [not_t] at p_def q_def
        simp [p_def, q_def]
    | inr not_lt =>
      simp [not_lt] at p_def q_def
      simp [p_def, q_def]
  | seq a b =>
    simp [record_match, ProofRecord.endposition] at p_def q_def
    generalize p_sub1_eq : (p i).subproof1index = p_sub1
    generalize p_sub2_eq : (p i).subproof2index = p_sub2
    simp only [p_sub1_eq, p_sub2_eq] at p_def
    have p_sub1_bound := p_def.left
    have p_sub1_nt    := p_def.right.left.left
    have p_sub1_pos   := p_def.right.left.right
    have p_def  := p_def.right.right

    generalize q_sub1_eq : q_j.subproof1index = q_sub1
    generalize q_sub2_eq : q_j.subproof2index = q_sub2
    simp only [q_sub1_eq, q_sub2_eq] at q_def
    have q_sub1_bound := q_def.left
    have q_sub1_nt    := q_def.right.left.left
    have q_sub1_pos   := q_def.right.left.right
    have q_def  := q_def.right.right

    have ind1 := ind (Fin.mk p_sub1 (Nat.lt_trans p_sub1_bound i.isLt))
                      p_sub1_bound
                      (Fin.mk q_sub1 (Nat.lt_trans q_sub1_bound j.isLt))
    rw [proof_get_to_getD (p i) p,
        proof_get_to_getD q_j q
        ] at ind1
    simp [p_sub1_nt, q_sub1_nt, p_sub1_pos, q_sub1_pos,
          ProofRecord.record_result]
       at ind1

    cases Decidable.em ((p.val.getD p_sub1 (p i)).success = true) with
    | inr p_sub1_fail =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inl q_sub1_success =>
        simp [p_sub1_fail, q_sub1_success] at ind1
      | inr q_sub1_fail =>
        simp [p_sub1_fail, q_sub1_fail] at p_def q_def
        simp [p_def, q_def]

    | inl p_sub1_success =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inr q_sub1_fail =>
        simp [p_sub1_success, q_sub1_fail] at ind1
      | inl q_sub1_success =>
        simp [p_sub1_success, q_sub1_success] at ind1 p_def q_def
        have p_sub2_bound := p_def.left
        have p_sub2_nt    := p_def.right.left.left
        have p_sub2_pos   := p_def.right.left.right
        simp only [p_sub1_pos, ind1] at p_sub2_pos
        have p_def  := p_def.right.right

        have q_sub2_bound := q_def.left
        have q_sub2_nt    := q_def.right.left.left
        have q_sub2_pos   := q_def.right.left.right
        simp only [q_sub1_pos] at q_sub2_pos
        have q_def  := q_def.right.right

        -- Instantiate second invariant on subterm 2
        have ind2 :=
          ind (Fin.mk p_sub2 (Nat.lt_trans p_sub2_bound i.isLt))
              p_sub2_bound
              (Fin.mk q_sub2 (Nat.lt_trans q_sub2_bound j.isLt))
        rw [proof_get_to_getD (p i) p,
            proof_get_to_getD q_j q
            ] at ind2
        simp [p_sub2_nt, q_sub2_nt,
              p_sub2_pos, q_sub2_pos,
              ProofRecord.record_result]
          at ind2

        cases Decidable.em ((p.val.getD p_sub2 (p i)).success = true) with
        | inr p_sub2_fail =>
          simp [p_sub2_fail] at ind2

          cases Decidable.em ((q.val.getD q_sub2 q_j).success = true) with
          | inl q_sub2_success =>
            simp [q_sub2_success] at ind2
          | inr q_sub2_fail =>
            simp [p_sub2_fail, q_sub2_fail] at p_def q_def
            simp [p_def, q_def]
        | inl p_sub2_success =>
          simp [p_sub2_success] at ind2

          cases Decidable.em ((q.val.getD q_sub2 q_j).success = true) with
          | inr q_sub2_fail =>
            simp [q_sub2_fail] at ind2
          | inl q_sub2_success =>
            simp [p_sub2_success, q_sub2_success] at ind2 p_def q_def

            have p_success := p_def.left
            have p_pos := p_def.right
            simp only [p_pos_eq_q_pos,  p_sub2_pos, ind1, ind2, Nat.add_assoc] at p_pos
            have p_pos' := Nat.add_left_cancel p_pos

            have q_success := q_def.left
            have q_pos := q_def.right
            simp only [q_sub1_pos, q_sub2_pos, Nat.add_assoc] at q_pos
            have q_pos' := Nat.add_left_cancel q_pos

            simp [p_success, q_success, p_pos', q_pos']

  | choice =>
    simp [record_match] at p_def q_def

    generalize p_sub1_eq : (p i).subproof1index = p_sub1
    generalize p_sub2_eq : (p i).subproof2index = p_sub2
    simp only [p_sub1_eq, p_sub2_eq] at p_def

    generalize q_sub1_eq : q_j.subproof1index = q_sub1
    generalize q_sub2_eq : q_j.subproof2index = q_sub2
    simp only [q_sub1_eq, q_sub2_eq] at q_def

    have p_sub1_bound := p_def.left
    have p_sub1_nt    := p_def.right.left.left
    have p_sub1_pos   := p_def.right.left.right
    have p_def  := p_def.right.right

    have q_sub1_bound := q_def.left
    have q_sub1_nt    := q_def.right.left.left
    have q_sub1_pos   := q_def.right.left.right
    have q_def := q_def.right.right

    have ind1 := ind (Fin.mk p_sub1 (Nat.lt_trans p_sub1_bound i.isLt))
                      p_sub1_bound
                      (Fin.mk q_sub1 (Nat.lt_trans q_sub1_bound j.isLt))
    rw [proof_get_to_getD (p i) p,
        proof_get_to_getD q_j q
        ] at ind1
    simp [p_sub1_nt, q_sub1_nt, p_sub1_pos, q_sub1_pos,
          ProofRecord.record_result]
       at ind1

    cases Decidable.em ((p.val.getD p_sub1 (p i)).success = true) with
    | inl p_sub1_success =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inr q_sub1_fail =>
        simp [p_sub1_success, q_sub1_fail] at ind1
      | inl q_sub1_success =>
        simp [p_sub1_success, q_sub1_success] at ind1 p_def q_def
        simp [p_def, q_def, ind1]
    | inr p_sub1_fail =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inl q_sub1_success =>
        simp [p_sub1_fail, q_sub1_success] at ind1
      | inr q_sub1_fail =>
        simp [p_sub1_fail, q_sub1_fail] at p_def q_def

        have p_sub2_bound := p_def.left
        have p_sub2_nt    := p_def.right.left.left
        have p_sub2_pos   := p_def.right.left.right
        have p_def  := p_def.right.right

        have q_sub2_bound := q_def.left
        have q_sub2_nt    := q_def.right.left.left
        have q_sub2_pos   := q_def.right.left.right
        have q_def := q_def.right.right

        -- Instantiate second invariant on subterm 2
        have ind2 :=
          ind (Fin.mk p_sub2 (Nat.lt_trans p_sub2_bound i.isLt))
              p_sub2_bound
              (Fin.mk q_sub2 (Nat.lt_trans q_sub2_bound j.isLt))
        rw [proof_get_to_getD (p i) p,
            proof_get_to_getD q_j q
            ] at ind2
        simp [p_sub2_nt, q_sub2_nt,
              p_sub2_pos, q_sub2_pos,
              ProofRecord.record_result]
          at ind2


        cases Decidable.em ((p.val.getD p_sub2 (p i)).success = true) with
        | inl p_sub2_success =>
          cases Decidable.em ((q.val.getD q_sub2 q_j).success = true) with
          | inr q_sub2_fail =>
            simp [p_sub2_success, q_sub2_fail] at ind2
          | inl q_sub2_success =>
            simp [p_sub2_success, q_sub2_success] at ind2 p_def q_def
            simp [p_def, q_def, ind2]
        | inr p_sub2_fail =>
          cases Decidable.em ((q.val.getD q_sub2 q_j).success = true) with
          | inl q_sub2_success =>
            simp [p_sub2_fail, q_sub2_success] at ind2
          | inr q_sub2_fail =>
            simp [p_sub2_fail, q_sub2_fail] at p_def q_def
            simp [p_def, q_def]

  | look =>
    simp [record_match] at p_def q_def

    generalize p_sub1_eq : (p i).subproof1index = p_sub1
    simp only [p_sub1_eq] at p_def

    generalize q_sub1_eq : q_j.subproof1index = q_sub1
    simp only [q_sub1_eq] at q_def

    have p_sub1_bound := p_def.left
    have p_sub1_nt    := p_def.right.left.left
    have p_sub1_pos   := p_def.right.left.right
    have p_def  := p_def.right.right

    have q_sub1_bound := q_def.left
    have q_sub1_nt    := q_def.right.left.left
    have q_sub1_pos   := q_def.right.left.right
    have q_def := q_def.right.right

    have ind1 := ind (Fin.mk p_sub1 (Nat.lt_trans p_sub1_bound i.isLt))
                      p_sub1_bound
                      (Fin.mk q_sub1 (Nat.lt_trans q_sub1_bound j.isLt))
    rw [proof_get_to_getD (p i) p,
        proof_get_to_getD q_j q
        ] at ind1
    simp [p_sub1_nt, q_sub1_nt, p_sub1_pos, q_sub1_pos,
          ProofRecord.record_result]
       at ind1

    cases Decidable.em ((p.val.getD p_sub1 (p i)).success = true) with
    | inl p_sub1_success =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inr q_sub1_fail =>
        simp [p_sub1_success, q_sub1_fail] at ind1
      | inl q_sub1_success =>
        simp [p_sub1_success, q_sub1_success] at ind1 p_def q_def
        simp [p_def, q_def, ind1]

    | inr p_sub1_fail =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inl q_sub1_success =>
        simp [p_sub1_fail, q_sub1_success] at ind1
      | inr q_sub1_fail =>
        simp [p_sub1_fail, q_sub1_fail] at ind1 p_def q_def
        simp [p_def, q_def, ind1]

  | notP =>
    simp [record_match] at p_def q_def

    generalize p_sub1_eq : (p i).subproof1index = p_sub1
    simp only [p_sub1_eq] at p_def

    generalize q_sub1_eq : q_j.subproof1index = q_sub1
    simp only [q_sub1_eq] at q_def

    have p_sub1_bound := p_def.left
    have p_sub1_nt    := p_def.right.left.left
    have p_sub1_pos   := p_def.right.left.right
    have p_def  := p_def.right.right

    have q_sub1_bound := q_def.left
    have q_sub1_nt    := q_def.right.left.left
    have q_sub1_pos   := q_def.right.left.right
    have q_def := q_def.right.right

    have ind1 := ind (Fin.mk p_sub1 (Nat.lt_trans p_sub1_bound i.isLt))
                      p_sub1_bound
                      (Fin.mk q_sub1 (Nat.lt_trans q_sub1_bound j.isLt))
    rw [proof_get_to_getD (p i) p,
        proof_get_to_getD q_j q
        ] at ind1
    simp [p_sub1_nt, q_sub1_nt, p_sub1_pos, q_sub1_pos,
          ProofRecord.record_result]
       at ind1

    cases Decidable.em ((p.val.getD p_sub1 (p i)).success = true) with
    | inl p_sub1_success =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inr q_sub1_fail =>
        simp [p_sub1_success, q_sub1_fail] at ind1
      | inl q_sub1_success =>
        simp [p_sub1_success, q_sub1_success] at ind1 p_def q_def
        simp [p_def, q_def, ind1]

    | inr p_sub1_fail =>
      cases Decidable.em ((q.val.getD q_sub1 q_j).success = true) with
      | inl q_sub1_success =>
        simp [p_sub1_fail, q_sub1_success] at ind1
      | inr q_sub1_fail =>
        simp [p_sub1_fail, q_sub1_fail] at ind1 p_def q_def
        simp [p_def, q_def, ind1]