Require Import Ascii Bool String List.
Require Import Lib.CommonTactics Lib.ilist Lib.Word Lib.Struct Lib.StringBound.
Require Import Lts.Syntax Lts.Semantics Lts.Equiv Lts.Tactics Lts.Specialize.
Require Import Ex.Msi Ex.MemTypes Ex.Fifo Ex.RegFile Ex.L1Cache Ex.ChildParent Ex.MemDir.
Require Import Ex.SC Ex.MemAtomic Ex.MemCache.

Set Implicit Arguments.

Section MemCorrect.
  Variables IdxBits TagBits LgNumDatas LgDataBytes: nat.
  Variable Id: Kind.
  Variable FifoSize: nat.

  Definition n := 1. (* number of caches (cores) *)

  Definition memCache := MemCache.memCache IdxBits TagBits LgNumDatas LgDataBytes Id FifoSize n.

  Definition memAtomic := memAtomic (AddrBits IdxBits LgNumDatas LgDataBytes) FifoSize
                                    LgDataBytes n.

  Hint Unfold memCache: ModuleDefs. (* for kinline_compute *)
  Hint Extern 1 (ModEquiv type typeUT memCache) => unfold memCache. (* for kequiv *)
  Hint Extern 1 (ModEquiv type typeUT memAtomic) => unfold memAtomic. (* for kequiv *)

  Theorem memCache_refines_memAtomic: memCache <<== memAtomic.
  Proof.
    admit.
  Qed.

End MemCorrect.

