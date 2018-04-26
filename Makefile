IGNORE:=

LIBVS:=$(wildcard Kami/Lib/*.v)
LIBVS:=$(filter-out $(IGNORE:%=%.v),$(LIBVS))

EXVS:=$(wildcard Kami/Ex/*.v)
EXVS:=$(filter-out $(EXSVS) $(IGNORE:%=%.v),$(EXVS))

EXTVS:=$(wildcard Kami/Ext/*.v)
EXTVS:=$(filter-out $(IGNORE:%=%.v),$(EXTVS))

VS:=$(wildcard Kami/*.v)
VS:=$(filter-out $(LIBVS) $(EXSVS) $(EXVS) $(EXTVS) $(RTLVS) $(IGNORE:%=%.v),$(VS))

.PHONY: coq clean

ARGS := -R Kami Kami

coq: Makefile.coq
	$(MAKE) -f Makefile.coq

Makefile.coq: Makefile $(LIBVS) $(VS) $(EXVS) $(EXTVS)
	$(COQBIN)coq_makefile $(ARGS) $(LIBVS) $(VS) $(EXVS) $(EXTVS) -o Makefile.coq

clean:: Makefile.coq
	$(MAKE) -f Makefile.coq clean
	rm -f */*.v.d */*.glob */*.vo */*~ *~
	rm -f Makefile.coq Makefile.coq.conf .coqdeps.d .lia.cache
