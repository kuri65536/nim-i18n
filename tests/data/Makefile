.PHONY: build edit

build:
	make $(mo1)
	make $(mo2)

edit:
	editor $(pot1)
	editor $(pot2)


dir1:=lang
dir2:=tools/gettext
pot1:=$(dir1)/character_traits.pot
pot2:=$(dir2)/meld.pot
po1:=$(dir $(pot1))fr/LC_MESSAGES/$(patsubst %.pot,%.po,$(notdir $(pot1)))
po2:=$(dir $(pot1))fr/LC_MESSAGES/$(patsubst %.pot,%.po,$(notdir $(pot2)))
mo1:=$(subst .po,.mo,$(po1))
mo2:=$(subst .po,.mo,$(po2))


$(po1): $(pot1)
	mkdir -p $(dir $@)
	if ! [ -e $@ ]; then cp $< $@; fi
	msgmerge --update $@ $<
	editor $@
$(po2): $(pot2)
	mkdir -p $(dir $@)
	if ! [ -e $@ ]; then cp $< $@; fi  # if first time.
	msgmerge --update $@ $<
	editor $@


$(mo1): $(po1)
	msgfmt -o $@ $<
$(mo2): $(po2)
	msgfmt -o $@ $<

