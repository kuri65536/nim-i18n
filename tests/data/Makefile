.PHONY: build edit

build:
	make $(mo1)
	make $(mo2)

edit:
	editor $(pot1)
	editor $(pot2)


pot1:=lang/character_traits.pot
pot2:=tools/gettext/meld.pot
po1:=$(dir $(pot1))fr/LC_MESSAGES/$(subst .pot,.po,$(notdir $(pot1)))
po2:=$(dir $(pot2))fr/LC_MESSAGES/$(subst .pot,.po,$(notdir $(pot2)))
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


## for js, serve data
serve-start:
	echo > nohup.out
	nohup python3 -m http.server -d json 8123 &
serve-stop:
	kill -TERM $$(lsof -t -i:8123)

