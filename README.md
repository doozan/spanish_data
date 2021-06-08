This data is built from [Wiktionary](https://en.wiktionary.org) and [Tatoeba](tatoeboa.org) datasets using my [Wiktionary Parser](https://github.com/doozan/enwiktionary_parser) and [Spanish Tools](https://github.com/doozan/spanish_tools)

This data is used to build the free, open-source Spanish to English dictionary available in StarDict and Aard2/slob formats in the [Release section](https://github.com/doozan/spanish_data/releases). It's also used to build my [6001 Spanish Vocab](https://github.com/doozan/6001_Spanish) anki deck, and is provided here with the hope that others may find additional uses for it.

### Interesting files:
* es-en.txt - Spanish to English wordlist
* frequency.csv - a list of the most frequently used Spanish lemmas with part of speech and all word variations combined into lemma
* sentences.tsv - English/Spanish sentence pairs from tatoeba.org with users self-reported proficiency, part of speech tags, and lemmas

### Credits:
* es-en.txt (CC-BY-SA Attribution: wiktionary.org)
* frequency.csv (CC-BY-SA 3.0 github.com/hermitdave/FrequencyWords)
* sentences.tsv (CC-BY 2.0 FR Attribution: tatoeba.org)
* Many thanks to Matthias Buchmeier for the original [trans-en-es.awk](https://en.wiktionary.org/wiki/User:Matthias_Buchmeier/trans-en-es.awk) script (GPL2)
* tatoeba user [CK](https://tatoeba.org/eng/user/profile/CK) for the list of [reviewed English sentences](https://tatoeba.org/eng/sentences_lists/show/907)
* [FreeLing](http://nlp.lsi.upc.edu/freeling) for the part of speech tagging

# Building the datafiles

## Install required tools
```bash
sudo apt install curl bzip2 gawk pv unzip zip pkg-config dictzip
pip3 install ijson pywikibot mwparserfromhell pyglossary PyICU Levenshtein
```

## Install FreeLing on Debian (for other distros, check the [FreeLing instructions](https://freeling-user-manual.readthedocs.io/en/latest/installation/installation-packages/))
```bash
wget https://github.com/TALP-UPC/FreeLing/releases/download/4.2/freeling-4.2-buster-amd64.deb
sudo apt install ./freeling-4.2-buster-amd64.deb libboost-chrono1.67.0 libboost-date-time1.67.0
```
## Check out the build tools
```bash
git clone https://github.com/doozan/enwiktionary_wordlist.git
git clone https://github.com/doozan/wtparser.git enwiktionary_wordlist/enwiktionary_parser
git clone https://github.com/doozan/enwiktionary_templates.git enwiktionary_wordlist/enwiktionary_templates
git clone https://github.com/doozan/spanish_tools.git
git clone https://github.com/doozan/6001_Spanish.git spanish_custom
mkdir spanish_data
```
### Extract the language data and build the wordlist
```bash
    wget -N -nv 'https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2'
    [ Spanish.txt.bz2 -nt enwiktionary-latest-pages-articles.xml.bz2 ] || PYWIKIBOT_NO_USER_CONFIG=1 python3 -m enwiktionary_wordlist.make_extract \
	    --xml enwiktionary-latest-pages-articles.xml.bz2 --lang es || return 1
    [ spanish_data/es-en.data -nt Spanish.txt.bz2 ] || python3 -m enwiktionary_wordlist.make_wordlist \
	    --langdata Spanish.txt.bz2 --lang-id es > spanish_data/es-en.data || return 1
    [ spanish_data/es_allforms.csv -nt Spanish.txt.bz2 ] || python3 -m enwiktionary_wordlist.make_all_forms \
	    --low-mem spanish_data/es-en.data > spanish_data/es_allforms.csv || return 1
```
### Build the sentences
```bash
    wget -N -nv https://downloads.tatoeba.org/exports/per_language/spa/spa_sentences_detailed.tsv.bz2
    wget -N -nv https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences_detailed.tsv.bz2
    wget -N -nv https://downloads.tatoeba.org/exports/per_language/eng/eng-spa_links.tsv.bz2
    wget -N -nv https://downloads.tatoeba.org/exports/sentences_in_lists.tar.bz2
    wget -N -nv https://downloads.tatoeba.org/exports/user_languages.tar.bz2

    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^spa\t5" | cut -f 3 | grep -v '\N' > spa_5.txt
    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^spa\t4" | cut -f 3 | grep -v '\N' > spa_4.txt
    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^spa\t[1-5]" | cut -f 3 > spa_known.txt

    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^eng\t5" | cut -f 3 | grep -v '\N' > eng_5.txt
    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^eng\t4" | cut -f 3 | grep -v '\N' > eng_4.txt
    bzcat user_languages.tar.bz2 | tail -n +2 |  grep -P "^eng\t[1-5]" | cut -f 3  > eng_known.txt

    bzcat sentences_in_lists.tar.bz2 | tail -n +2 |  grep -P "^907\t" | cut -f 2 > eng_reviewed.txt

    bzcat eng_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}($1 in A){print $1 "\t" $3 "\t" $4 "\t6" }' eng_reviewed.txt - > eng_sentences.tsv
    bzcat eng_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$1];next} FID==2{B[$1];next} (!($1 in A)&&($4 in B)){print $1 "\t" $3 "\t" $4 "\t5" }' eng_reviewed.txt eng_5.txt - >> eng_sentences.tsv
    bzcat eng_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$1];next} FID==2{B[$1];next} (!($1 in A)&&($4 in B)){print $1 "\t" $3 "\t" $4 "\t4" }' eng_reviewed.txt eng_4.txt - >> eng_sentences.tsv
    bzcat eng_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} FNR==1{FID++} FID==1{A[$1];next} FID==2{B[$1];next} (!($1 in A)&&!($4 in B)){print $1 "\t" $3 "\t" $4 "\t0" }' eng_reviewed.txt eng_known.txt - >> eng_sentences.tsv

    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}($4 in A){print $1 "\t" $3 "\t" $4 "\t5" }' spa_5.txt - > spa_sentences.tsv
    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}($4 in A){print $1 "\t" $3 "\t" $4 "\t4" }' spa_4.txt - >> spa_sentences.tsv
    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}!($4 in A){print $1 "\t" $3 "\t" $4 "\t0" }' spa_known.txt - >> spa_sentences.tsv

    cat<<'EOF'>join.awk

        BEGIN {FS="\t"}
        FNR == 1 {FID++}
        FID<3 {cache[$1] = $2"\t"$3"\t"$4}
        FID==3 && $1 in cache && $2 in cache {
            split(cache[$1], eng)
            split(cache[$2], spa)

            print eng[1] "\t" spa[1] "\t" \
                "CC-BY 2.0 (France) Attribution: tatoeba.org #" $1 " (" eng[2] ") & #" $2 " (" spa[2] ")" \
                "\t" eng[3] "\t" spa[3]
        }
EOF

    bzcat eng-spa_links.tsv.bz2 | gawk -f join.awk eng_sentences.tsv spa_sentences.tsv - > joined.tsv || return 1

    # sort by number of spaces in the spanish sentence
    cat joined.tsv | sort -k1,1 -k2,2 -t$'\t' --unique | awk 'BEGIN {FS="\t"}; {x=$1; print gsub(/ /, " ", x) "\t" $0}' | sort -n | cut -f 2- > eng-spa.tsv

    python3 -m spanish_tools.build_sentences --low-mem --dictionary spanish_data/es-en.data --allforms spanish_data/es_allforms.csv eng-spa.tsv > spa-only.txt || return 1
    echo "...tagging sentences"
    [ spa-only.txt.json -nt eng-spa_links.tsv.bz2 ] || spanish_tools/build_tags.sh spa-only.txt || return 1
    python3 -m spanish_tools.build_sentences --low-mem --dictionary spanish_data/es-en.data --allforms spanish_data/es_allforms.csv eng-spa.tsv --tags spa-only.txt.json > spanish_data/sentences.tsv || return 1
```
### Build the frequency list
```bash
    python3 -m spanish_tools.freq --low-mem --dictionary spanish_data/es-en.data --allforms spanish_data/es_allforms.csv --ignore spanish_custom/ignore.txt spanish_data/es_50k_merged.txt > spanish_data/frequency.csv
```
### Build the Spanish-English Stardict dictionary
```bash

python3 -m enwiktionary_wordlist.wordlist_to_dictunformat --low-mem spanish_data/es-en.data spanish_data/es_allforms.csv --lang-id es \
	--description "Spanish-English dictionary. Compiled by Jeff Doozan from Wiktionary data $TAG. CC-BY-SA" \
	> es-en.dictunformat || return 1
~/.local/bin/pyglossary --no-progress-bar --no-color es-en.dictunformat es-en.ifo || return 1
~/.local/bin/pyglossary --no-progress-bar --no-color es-en.ifo es-en.slob || return 1
```
