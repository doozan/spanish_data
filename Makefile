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

NGRAMDATA := ../ngram_data
NGYEAR := 1950
#NGYEAR := 2012
BUILDDIR := $(DATETAG_PRETTY)
_mkdir := $(shell mkdir -p $(BUILDDIR))
PYPATH := PYTHONPATH=$(BUILDDIR)

SPANISH_SCRIPTS := $(BUILDDIR)/spanish_tools/scripts
BUILD_SENTENCES := $(PYPATH) $(SPANISH_SCRIPTS)/build_sentences
BUILD_TAGS := $(PYPATH) $(SPANISH_SCRIPTS)/build_tags
MAKE_FREQ := $(PYPATH) $(SPANISH_SCRIPTS)/make_freq
MERGE_FREQ_LIST := $(PYPATH) $(SPANISH_SCRIPTS)/merge_freq_list

NGRAM_COMBINE := $(PYPATH) $(BUILDDIR)/ngram/combine.py
WORDLIST_SCRIPTS := $(BUILDDIR)/enwiktionary_wordlist/scripts
MAKE_EXTRACT := $(PYPATH) $(WORDLIST_SCRIPTS)/make_extract
MAKE_WORDLIST := $(PYPATH) $(WORDLIST_SCRIPTS)/make_wordlist
MAKE_ALLFORMS := $(PYPATH) $(WORDLIST_SCRIPTS)/make_all_forms
KAIKKI_TO_WORDLIST := $(PYPATH) $(WORDLIST_SCRIPTS)/kaikki_to_wordlist
WORDLIST_TO_DICTUNFORMAT := $(PYPATH) $(WORDLIST_SCRIPTS)/wordlist_to_dictunformat
LANGID_TO_NAME := $(PYPATH) $(WORDLIST_SCRIPTS)/langid_to_name

EXTRACT_TRANSLATIONS := $(PYPATH) $(BUILDDIR)/enwiktionary_translations/scripts/extract_translations
TRANSLATIONS_TO_WORDLIST := $(PYPATH) $(BUILDDIR)/enwiktionary_translations/scripts/translations_to_wordlist
TEMPLATE_CACHE := $(PYPATH) $(BUILDDIR)/enwiktionary_templates/cache.py

WIKI_SEARCH := $(PYPATH) $(BUILDDIR)/autodooz/scripts/wikisearch

TEMPLATE_CACHEDB := ~/.enwiktionary_templates/cache.db
PYGLOSSARY := ~/.local/bin/pyglossary
ANALYZE := ~/.local/bin/analyze
ZIP := zip

TOOLS := $(BUILDDIR)/enwiktionary_wordlist $(BUILDDIR)/enwiktionary_templates $(BUILDDIR)/enwiktionary_sectionparser $(BUILDDIR)/enwiktionary_parser $(BUILDDIR)/enwiktionary_translations $(BUILDDIR)/spanish_tools $(BUILDDIR)/spanish_custom $(BUILDDIR)/autodooz $(BUILDDIR)/ngram
TARGETS :=  es-en.data es_allforms.csv sentences.tsv frequency.csv es_merged_50k.txt es-en.enwikt.StarDict.zip es-en.enwikt.slob.zip en-es.enwikt.slob.zip

tools: $(TOOLS)
all: $(TOOLS) $(TARGETS)
clean:
>   $(RM) -r $(TOOLS)
>   $(RM) $(TARGETS)

.PHONY: all tools clean force


$(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2:
>   @echo "Making $@..."
>   curl -s -f --retry 500 --retry-all-errors  "https://dumps.wikimedia.org/enwiktionary/$(DATETAG)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2" -o $@

# Modules

$(BUILDDIR)/enwiktionary_%:
>   git clone -q https://github.com/doozan/enwiktionary_$* $@

$(BUILDDIR)/enwiktionary_parser:
>   git clone -q https://github.com/doozan/wtparser $@

$(BUILDDIR)/enwiktionary_sectionparser:
>   pip3 install --target=$(BUILDDIR) git+https://github.com/doozan/enwiktionary_sectionparser

$(BUILDDIR)/spanish_tools:
>   git clone -q https://github.com/doozan/spanish_tools $@

$(BUILDDIR)/spanish_custom:
>   git clone -q https://github.com/doozan/6001_spanish $@

$(BUILDDIR)/autodooz:
>   git clone -q https://github.com/doozan/wikibot $@

$(BUILDDIR)/ngram:
>   git clone -q https://github.com/doozan/ngram $@


# Extracts

$(BUILDDIR)/%-en.enwikt.txt.bz2: $(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2
>   @echo "Making $@..."
>   $(MAKE_EXTRACT) --xml $< --lang $* --outdir $(BUILDDIR)

# workaround for building several extracts at one time until I can figure how to get make to do this
LANGS := all en es fr pl pt
OTHERS := templates modules redirects
$(patsubst %,$(BUILDDIR)/%-en.enwikt.txt.bz2,$(LANGS)) $(patsubst %,$(BUILDDIR)/%.enwikt.txt.bz2,$(OTHERS)) $(BUILDDIR)/enwikt.pages &: $(BUILDDIR)/enwiktionary-$(DATETAG)-pages-articles.xml.bz2 $(BUILDDIR)/enwiktionary_wordlist
>   @echo "Making $@..."
>   $(MAKE_EXTRACT) --xml $< $(patsubst %,--lang %,$(LANGS)) --templates --modules --redirects --allpages --outdir $(BUILDDIR)

# Translations
$(BUILDDIR)/translations.bz2: $(BUILDDIR)/all-en.enwikt.txt.bz2
>   @echo "Making $@..."
>   $(EXTRACT_TRANSLATIONS) --wxt $< | bzip2 > $@

# Tagged senses (used for {{transclude sense}})
$(BUILDDIR)/%-transcludes.txt: $(BUILDDIR)/%-en.enwikt.txt.bz2
>   echo "Making $@..."
>   $(WIKI_SEARCH) --sort --nopath $(BUILDDIR)/$*-en.enwikt.txt.bz2 '\#.*{{senseid' \
>       | perl -pe 's/(.*?):: \#[*:]*\s*(.*?){{senseid[^}]*?\s*([^|}]*)}}\s*(.*)/\1:\3::\2\4/' > $@

# Update the template cached - using a temp file to allow future runs to roll back to original data
# in the case the update fails and the file is deleted
$(TEMPLATE_CACHEDB): $(BUILDDIR)/es-en.enwikt.txt.bz2
>   echo "Making $@..."
>   if [ -f $@ -a ! -f $@.tmp_orig ]; then cp $@ $@.tmp_orig; fi # create backup
>   if [ ! -f $@ -a -f $@.tmp_orig ]; then cp $@.tmp_orig $@; fi # restore backup
>   $(TEMPLATE_CACHE) --db $@ --wxt $< --update -j 15
>   $(RM) $@.tmp_orig

# Build wordlist and allforms from wiktionary data
$(BUILDDIR)/%-en.enwikt.data-full: $(BUILDDIR)/%-en.enwikt.txt.bz2 $(BUILDDIR)/en-transcludes.txt $(TEMPLATE_CACHEDB)
>   @echo "Making $@..."
>   $(MAKE_WORDLIST) --langdata $< --lang-id $* --expand-templates --transcludes $(BUILDDIR)/en-transcludes.txt > $@ #2> $@.warnings

$(BUILDDIR)/en-%.enwikt.data-full: $(BUILDDIR)/translations.bz2
>   @echo "Making $@..."
>   $(TRANSLATIONS_TO_WORDLIST) --trans $< --langid $* > $@

$(BUILDDIR)/%.enwikt.data: $(BUILDDIR)/%.enwikt.data-full
>   @echo "Making $@..."
>   $(MAKE_WORDLIST) --wordlist $< --exclude-generated-forms --exclude-empty > $@

# Allforms - built from .data and not .data-full
$(BUILDDIR)/%.allforms.csv: $(BUILDDIR)/%.data
>   @echo "Making $@..."
>   $(MAKE_ALLFORMS) --low-mem $< > $@

# Build wordlist and allforms from kaikki data

$(BUILDDIR)/%-en.kaikki.json.gz:
>   @echo "Making $@..."
>   LANG_NAME=`$(LANGID_TO_NAME) $*`
>   curl -s https://kaikki.org/dictionary/$$LANG_NAME/kaikki.org-dictionary-$$LANG_NAME.json.gz -o $@

$(BUILDDIR)/%.kaikki.data $(BUILDDIR)/%.kaikki.allforms.csv &: $(BUILDDIR)/%.kaikki.json.gz
>   @echo "Making $@..."
>   $(KAIKKI_TO_WORDLIST) $< --allforms $(BUILDDIR)/$*.kaikki.allforms.csv > $(BUILDDIR)/$*.kaikki.data

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

$(BUILDDIR)/spa.untagged: $(BUILDDIR)/eng-spa.tsv $(BUILDDIR)/es-en.enwikt.data $(BUILDDIR)/es-en.enwikt.allforms.csv $(BUILDDIR)/es-1-$(NGYEAR).ngprobs
>   @echo "Making $@..."
>   $(BUILD_SENTENCES) \
>       --dictionary $(BUILDDIR)/es-en.enwikt.data \
>       --allforms $(BUILDDIR)/es-en.enwikt.allforms.csv \
>       --ngprobs $(BUILDDIR)/es-1-$(NGYEAR).ngprobs \
>       --ngcase $(NGRAMDATA)/spa/es-1-$(NGYEAR).ngcase \
>       --ngramdb $(NGRAMDATA)/spa/ngram-$(NGYEAR).db \
>       $< > $@

$(BUILDDIR)/%.untagged: $(BUILDDIR)/%.sentences
>   @echo "Making $@..."
>   cut -f 1 $< > $@

$(BUILDDIR)/%.tagged: $(BUILDDIR)/%.untagged
>   @echo "Making $@..."
>   $(ANALYZE)  -w 1 -f es.cfg --flush --output json --noloc --nodate --noquant --outlv tagged < $< | pv > $@

$(BUILDDIR)/%.json: $(BUILDDIR)/%.tagged
>   @echo "Making $@..."
>   echo "[" > $@
>   head -n -1 $< | sed 's/}]}]}/}]}]},/' | sed '$$ s/.$$//' >> $@
>   echo "" >> $@
>   echo "]" >> $@

$(BUILDDIR)/%.sentences.tsv: $(BUILDDIR)/eng-spa.tsv $(BUILDDIR)/spa.json $(BUILDDIR)/%.data $(BUILDDIR)/%.allforms.csv $(BUILDDIR)/es-1-$(NGYEAR).ngprobs
>   @echo "Making $@..."
>   $(BUILD_SENTENCES) \
>       --dictionary $(BUILDDIR)/es-en.enwikt.data \
>       --allforms $(BUILDDIR)/es-en.enwikt.allforms.csv \
>       --ngprobs $(BUILDDIR)/es-1-$(NGYEAR).ngprobs \
>       --ngcase $(NGRAMDATA)/spa/es-1-$(NGYEAR).ngcase \
>       --ngramdb $(NGRAMDATA)/spa/ngram-$(NGYEAR).db \
>       --tags $(BUILDDIR)/spa.json \
>       $< > $@

# Frequency list

$(BUILDDIR)/probabilitats.dat:
>   @echo "Making $@..."

>   curl -s "https://raw.githubusercontent.com/TALP-UPC/FreeLing/master/data/es/probabilitats.dat" -o $@

# Call into the ngram makefile to build anything not declared here
$(NGRAMDATA)/%: force
>   @echo "Subcontracting $@..."
>   $(MAKE) -C $(NGRAMDATA) $(@:$(NGRAMDATA)/%=%)

force: ;
# force used per https://www.gnu.org/software/make/manual/html_node/Overriding-Makefiles.html

$(BUILDDIR)/es-1-$(NGYEAR).ngprobs: $(BUILDDIR)/es-en.enwikt.allforms.csv $(NGRAMDATA)/spa/1-full-$(NGYEAR).ngram
>   @echo "Making $@..."

>   $(NGRAM_COMBINE) --allforms $< $(NGRAMDATA)/spa/1-full-$(NGYEAR).ngram > $@
>   sort -k2,2nr -k1,1 -o $@ $@

$(BUILDDIR)/es_2018_full.txt:
>   @echo "Making $@..."
>   curl -s https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_full.txt -o $@

$(BUILDDIR)/CREA_total.zip:
>   @echo "Making $@..."
>   curl -s http://corpus.rae.es/frec/CREA_total.zip -o $@ -H 'User-Agent: Mozilla/5.0'

$(BUILDDIR)/CORDE_total.zip:
>   @echo "Making $@..."
>   curl -s https://corpus.rae.es/frecCORDE/CORDE_total.zip -o $@ -H 'User-Agent: Mozilla/5.0'

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

$(BUILDDIR)/%.frequency.csv: $(BUILDDIR)/es-1-$(NGYEAR).ngprobs  $(BUILDDIR)/%.data $(BUILDDIR)/%.allforms.csv $(BUILDDIR)/es.wordcount
>   @echo "Making $@..."
>   $(MAKE_FREQ) \
>       --dictionary $(BUILDDIR)/$*.data \
>       --ngprobs $(BUILDDIR)/es-1-$(NGYEAR).ngprobs \
>       --allforms $(BUILDDIR)/$*.allforms.csv \
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
>   $(ZIP) -j $@ $(BUILDDIR)/$*.{ifo,idx,syn,dict.dz}

%.slob.zip: $(BUILDDIR)/%.slob
>   @echo "Making $@..."
>   $(ZIP) -j $@ $<
