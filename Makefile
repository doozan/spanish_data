SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --keep-going

# don't delete any intermediary files
.SECONDARY:

ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif
.RECIPEPREFIX = >

DATETAG := $(shell curl -s https://dumps.wikimedia.org/enwiktionary/ | grep '>[0-9]*/<' | cut -b 10-17 | tail -1)
DATETAG_PRETTY := $(shell date --date="$(DATETAG)" +%Y-%m-%d)

BUILDDIR := $(DATETAG_PRETTY)
PYPATH := PYTHONPATH=$(BUILDDIR)

SPANISH_SCRIPTS := $(BUILDDIR)/spanish_tools/scripts
BUILD_SENTENCES := $(PYPATH) $(SPANISH_SCRIPTS)/build_sentences
BUILD_TAGS := $(PYPATH) $(SPANISH_SCRIPTS)/build_tags
MAKE_FREQ := $(PYPATH) $(SPANISH_SCRIPTS)/make_freq
MERGE_FREQ_LIST := $(PYPATH) $(SPANISH_SCRIPTS)/merge_freq_list

WORDLIST_SCRIPTS := $(BUILDDIR)/enwiktionary_wordlist/scripts
MAKE_EXTRACT := $(PYPATH) $(WORDLIST_SCRIPTS)/make_extract
MAKE_WORDLIST := $(PYPATH) $(WORDLIST_SCRIPTS)/make_wordlist
MAKE_ALLFORMS := $(PYPATH) $(WORDLIST_SCRIPTS)/make_all_forms
WORDLIST_TO_DICTUNFORMAT := $(PYPATH) $(WORDLIST_SCRIPTS)/wordlist_to_dictunformat

EXTRACT_TRANSLATIONS := $(PYPATH) $(BUILDDIR)/enwiktionary_translations/scripts/extract_translations
TRANSLATIONS_TO_WORDLIST := $(PYPATH) $(BUILDDIR)/enwiktionary_translations/scripts/translations_to_wordlist 

PYGLOSSARY := ~/.local/bin/pyglossary 
ANALYZE := ~/.local/bin/analyze
#ANALYZE := /usr/local/bin/analyze
ZIP := zip

TOOLS := $(BUILDDIR)/enwiktionary_wordlist $(BUILDDIR)/enwiktionary_templates $(BUILDDIR)/enwiktionary_parser $(BUILDDIR)/enwiktionary_translations $(BUILDDIR)/spanish_tools $(BUILDDIR)/spanish_custom $(BUILDDIR)/autodooz
TARGETS :=  es-en.data es_allforms.csv sentences.tsv frequency.csv es_merged_50k.txt es-en.enwikt.StarDict.zip es-en.enwikt.slob.zip en-es.enwikt.slob.zip

tools: $(TOOLS)
all: $(TOOLS) $(TARGETS)
clean:
>   $(RM) -r $(TOOLS)
>   $(RM) $(TARGETS)

.PHONY: all tools clean


$(BUILDDIR):
>   mkdir -p $(BUILDDIR)

$(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2:
>   @echo "Making $@..."
>   curl -s "https://dumps.wikimedia.org/enwiktionary/$(DATETAG)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2" -o $@


# Modules

$(BUILDDIR)/enwiktionary_%:
>   git clone -q https://github.com/doozan/enwiktionary_$* $@

$(BUILDDIR)/enwiktionary_parser:
>   git clone -q https://github.com/doozan/wtparser $@

$(BUILDDIR)/spanish_tools:
>   git clone -q https://github.com/doozan/spanish_tools $@

$(BUILDDIR)/spanish_custom:
>   git clone -q https://github.com/doozan/6001_spanish $@

$(BUILDDIR)/autodooz:
>   git clone -q https://github.com/doozan/wikibot $@


# Extracts

$(BUILDDIR)/%-en.enwikt.txt.bz2: $(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2
>   @echo "Making $@..."
>   $(MAKE_EXTRACT) --xml $< --lang $* --outdir $(BUILDDIR)

# workaround for building several extracts at one time until I can figure how to get make to do this
LANGS := en es fr pl pt
$(patsubst %,$(BUILDDIR)/%-en.enwikt.txt.bz2,$(LANGS)) &: $(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2
>   @echo "Making $@..."
>   $(MAKE_EXTRACT) --xml $< $(patsubst %,--lang %,$(LANGS)) --outdir $(BUILDDIR)

# Translations
$(BUILDDIR)/translations.bz2: $(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2
>   @echo "Making $@..."
>   $(EXTRACT_TRANSLATIONS) --xml $< | bzip2 > $@

# Wordlist

$(BUILDDIR)/%-en.enwikt.data-full: $(BUILDDIR)/%-en.enwikt.txt.bz2
>   @echo "Making $@..."
>   $(MAKE_WORDLIST) --langdata $< --lang-id $* > $@ #2> $@.warnings

$(BUILDDIR)/en-%.enwikt.data-full: $(BUILDDIR)/translations.bz2
>   @echo "Making $@..."
>   $(TRANSLATIONS_TO_WORDLIST) --trans $< --langid $* > $@

$(BUILDDIR)/en-en.enwikt.data-full: $(BUILDDIR)/en-en.enwikt.txt.bz2
>   @echo "Making $@..."
>   $(MAKE_WORDLIST) --langdata $< --lang-id en > $@ #2> $@.warnings

$(BUILDDIR)/%.data: $(BUILDDIR)/%.data-full
>   @echo "Making $@..."
>   $(MAKE_WORDLIST) --lang-id $* --wordlist $< --exclude-generated-forms --exclude-empty > $@



# Allforms - built from .data and not .data-full
$(BUILDDIR)/%.allforms.csv: $(BUILDDIR)/%.data
>   @echo "Making $@..."
>   $(MAKE_ALLFORMS) --low-mem $< > $@


# Sentences

$(BUILDDIR)/%_sentences_detailed.tsv.bz2:
>   @echo "Making $@..."
>   curl -s https://downloads.tatoeba.org/exports/per_language/$*/$(@F) -o $@

$(BUILDDIR)/sentences_in_lists.tar.bz2 $(BUILDDIR)/user_languages.tar.bz2:
>   @echo "Making $@..."
>   curl -s https://downloads.tatoeba.org/exports/$(@F) -o $@

$(BUILDDIR)/eng-spa_links.tsv.bz2:
>   @echo "Making $@..."
>   curl -s https://downloads.tatoeba.org/exports/per_language/eng/eng-spa_links.tsv.bz2 -o $@

$(BUILDDIR)/%_5.txt: $(BUILDDIR)/user_languages.tar.bz2
>   @echo "Making $@..."
>   bzcat $< | tail -n +2 |  grep -P "^$*\t5" | cut -f 3 | grep -v '\N' > $@

$(BUILDDIR)/%_4.txt: $(BUILDDIR)/user_languages.tar.bz2
>   @echo "Making $@..."
>   bzcat $< | tail -n +2 |  grep -P "^$*\t4" | cut -f 3 | grep -v '\N' > $@

$(BUILDDIR)/%_known.txt: $(BUILDDIR)/user_languages.tar.bz2
>   @echo "Making $@..."
>   bzcat $< | tail -n +2 |  grep -P "^$*\t[1-5]" | cut -f 3 > $@

$(BUILDDIR)/spa_reviewed.txt: $(BUILDDIR)/sentences_in_lists.tar.bz2
>   @echo "Making $@..."
>   bzcat $< | tail -n +2 |  grep -P "^6685\t" | cut -f 2 > $@

$(BUILDDIR)/eng_reviewed.txt: $(BUILDDIR)/sentences_in_lists.tar.bz2
>   @echo "Making $@..."
>   bzcat $<| tail -n +2 |  grep -P "^907\t" | cut -f 2 > $@

$(BUILDDIR)/%_sentences.tsv: $(BUILDDIR)/%_sentences_detailed.tsv.bz2 $(BUILDDIR)/%_reviewed.txt $(BUILDDIR)/%_5.txt $(BUILDDIR)/%_4.txt $(BUILDDIR)/%_known.txt
>   @echo "Making $@..."
>   bzcat $< | awk 'BEGIN {FS="\t"} NR==FNR{A[$$1];next}($$1 in A){print $$1 "\t" $$3 "\t" $$4 "\t6" }' $(BUILDDIR)/$*_reviewed.txt - > $@
>   bzcat $< | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$$1];next} FID==2{B[$$1];next} (!($$1 in A)&&($$4 in B)){print $$1 "\t" $$3 "\t" $$4 "\t5" }' $(BUILDDIR)/$*_reviewed.txt $(BUILDDIR)/$*_5.txt - >> $@
>   bzcat $< | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$$1];next} FID==2{B[$$1];next} (!($$1 in A)&&($$4 in B)){print $$1 "\t" $$3 "\t" $$4 "\t4" }' $(BUILDDIR)/$*_reviewed.txt $(BUILDDIR)/$*_4.txt - >> $@
>   bzcat $< | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$$1];next} FID==2{B[$$1];next} (!($$1 in A)&&!($$4 in B)){print $$1 "\t" $$3 "\t" $$4 "\t0" }' $(BUILDDIR)/$*_reviewed.txt $(BUILDDIR)/$*_known.txt - >> $@

$(BUILDDIR)/join.awk:
>   @cat <<'EOF'>$@
>   BEGIN {FS="\t"}
>   FNR == 1 {FID++}
>   FID<3 {cache[$$1] = $$2"\t"$$3"\t"$$4}
>   FID==3 && $$1 in cache && $$2 in cache {
>       split(cache[$$1], eng)
>       split(cache[$$2], spa)
>
>       print eng[1] "\t" spa[1] "\t" \
>        "CC-BY 2.0 (France) Attribution: tatoeba.org #" $$1 " (" eng[2] ") & #" $$2 " (" spa[2] ")" \
>        "\t" eng[3] "\t" spa[3]
>   }
>   EOF

$(BUILDDIR)/eng-spa_joined.tsv: $(BUILDDIR)/eng-spa_links.tsv.bz2 $(BUILDDIR)/join.awk $(BUILDDIR)/eng_sentences.tsv $(BUILDDIR)/spa_sentences.tsv
>   @echo "Making $@..."
>   bzcat $< | gawk -f $(BUILDDIR)/join.awk $(BUILDDIR)/eng_sentences.tsv $(BUILDDIR)/spa_sentences.tsv - > $@

$(BUILDDIR)/%.tsv: $(BUILDDIR)/%_joined.tsv
>   @echo "Making $@..."
>   cat $< \
>   | sort -k1,1 -k2,2 -t$$'\t' --unique \
>   | awk 'BEGIN {FS="\t"}; {x=$$1; print gsub(/ /, " ", x) "\t" $$0}' \
>   | sort -n \
>   | cut -f 2- \
>   > $@

$(BUILDDIR)/spa-only.txt: $(BUILDDIR)/eng-spa.tsv $(BUILDDIR)/es-en.enwikt.data $(BUILDDIR)/es-en.enwikt.allforms.csv
>   @echo "Making $@..."
>   $(BUILD_SENTENCES) --dictionary $(BUILDDIR)/es-en.enwikt.data --allforms $(BUILDDIR)/es-en.enwikt.allforms.csv $(BUILDDIR)/eng-spa.tsv > $@

$(BUILDDIR)/spa-only.txt.tagged: $(BUILDDIR)/spa-only.txt
>   @echo "Making $@..."
>   $(ANALYZE) -f es.cfg --flush --output json --noloc --nodate --noquant --outlv tagged < $< | pv > $@

$(BUILDDIR)/%-only.txt.json: $(BUILDDIR)/%-only.txt.tagged
>   @echo "Making $@..."
>   echo "[" > $@
>   head -n -1 $< | sed 's/}]}]}/}]}]},/' | sed '$$ s/.$$//' >> $@
>   echo "" >> $@
>   echo "]" >> $@

$(BUILDDIR)/%.sentences.tsv: $(BUILDDIR)/eng-spa.tsv $(BUILDDIR)/spa-only.txt.json $(BUILDDIR)/%.data $(BUILDDIR)/%.allforms.csv
>   @echo "Making $@..."
>   $(BUILD_SENTENCES) --dictionary $(BUILDDIR)/$*.data --allforms $(BUILDDIR)/$*.allforms.csv $(BUILDDIR)/eng-spa.tsv --tags $(BUILDDIR)/spa-only.txt.json > $@


# Frequency list

$(BUILDDIR)/probabilitats.dat:
>   @echo "Making $@..."
>   curl -s "https://raw.githubusercontent.com/TALP-UPC/FreeLing/master/data/es/probabilitats.dat" -o $@

$(BUILDDIR)/es_2018_full.txt:
>   @echo "Making $@..."
>   curl -s https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_full.txt -o $@

$(BUILDDIR)/CREA_total.zip:
>   @echo "Making $@..."
>   curl -s http://corpus.rae.es/frec/CREA_total.zip -o $@

$(BUILDDIR)/CREA_full.txt: $(BUILDDIR)/CREA_total.zip
>   @echo "Making $@..."
>   zcat $< \
>     | tail -n +2 \
>     | awk '{gsub(",",""); print $$2" "$$3;}' \
>     | iconv -f ISO-8859-1 -t UTF-8  \
>     > $@

$(BUILDDIR)/es.wordcount: $(BUILDDIR)/es_2018_full.txt $(BUILDDIR)/CREA_full.txt
>   @echo "Making $@..."
>   $(MERGE_FREQ_LIST) $(BUILDDIR)/es_2018_full.txt $(BUILDDIR)/CREA_full.txt --min 4 > $@

$(BUILDDIR)/%.frequency.csv: $(BUILDDIR)/probabilitats.dat  $(BUILDDIR)/%.data $(BUILDDIR)/%.allforms.csv $(BUILDDIR)/es.wordcount $(BUILDDIR)/%.sentences.tsv
>   @echo "Making $@..."
>   $(MAKE_FREQ) \
>       --dictionary $(BUILDDIR)/$*.data \
>       --probs $(BUILDDIR)/probabilitats.dat \
>       --allforms $(BUILDDIR)/$*.allforms.csv \
>       --data-dir "." \
>       --custom-dir "$(BUILDDIR)/spanish_custom" \
>       --sentences $(BUILDDIR)/$*.sentences.tsv \
>       --ignore $(BUILDDIR)/spanish_custom/ignore.txt \
>       --infile $(BUILDDIR)/es.wordcount \
>       --outfile $@

# Dictionary

$(BUILDDIR)/%.dictunformat: $(BUILDDIR)/%.data $(BUILDDIR)/%.allforms.csv
>   @echo "Making $@..."
>   LANGS=`echo $* | cut -d "." -f 1`
>   SOURCE=`echo $* | cut -d "." -f 2`
>   FROM_LANG=`echo $$LANGS | cut -d "-" -f 1`
>   TO_LANG=`echo $$LANGS | cut -d "-" -f 2`
>   $(WORDLIST_TO_DICTUNFORMAT) $(BUILDDIR)/$*.data $(BUILDDIR)/$*.allforms.csv \
>      --name "$$SOURCE ($$FROM_LANG-$$TO_LANG)" \
>      --description "$$FROM_LANG-$$TO_LANG dictionary, published by Jeff Doozan using en.wiktionary.org data from $(DATETAG_PRETTY). CC-BY-SA" \
>      > $@

$(BUILDDIR)/%.slob: $(BUILDDIR)/%.dictunformat
>   @echo "Making $@..."
>   $(RM) $@
>   $(PYGLOSSARY) --ui=none $< $@

$(BUILDDIR)/%.ifo: $(BUILDDIR)/%.dictunformat
>   @echo "Making $@..."
>   $(PYGLOSSARY) --ui=none $< $@


# Target files

es-en.data: $(BUILDDIR)/es-en.enwikt.data
>   @echo "Making $@..."
>   cp $< $@

es_allforms.csv: $(BUILDDIR)/es-en.enwikt.allforms.csv
>   @echo "Making $@..."
>   cp $< $@

frequency.csv: $(BUILDDIR)/es-en.enwikt.frequency.csv
>   echo "Making $@..."
>   awk -F, '$$1 >= CUTOFF {print}; NR==25001 {CUTOFF=$$1}' $< > $@

sentences.tsv: $(BUILDDIR)/es-en.enwikt.sentences.tsv
>   @echo "Making $@..."
>   cp $< $@

es_merged_50k.txt: $(BUILDDIR)/es.wordcount
>   @echo "Making $@..."
>   awk '$$2 >= CUTOFF {print}; NR==50000 {CUTOFF=$$2}' $< > $@

%.StarDict.zip: $(BUILDDIR)/%.ifo
>   @echo "Making $@..."
>   $(ZIP) $@ $(BUILDDIR)/es-en.enwikt.{ifo,idx,syn,dict.dz}

%.slob.zip: $(BUILDDIR)/%.slob
>   @echo "Making $@..."
>   $(ZIP) $@ $<