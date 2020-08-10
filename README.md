This data is build from [Wiktionary](https://en.wiktionary.org) and [Tatoeba](tatoeboa.org) datasets using my [Spanish Tools](https://github.com/doozan/spanish_tools)

This data is primarily used to build my [6001 Spanish Vocab](https://github.com/doozan/6001_Spanish) anki deck, but it's provided here in case it may be useful for other purposes.

### Interesting files:
* es-en.txt - Spanish to English dictionary, with metadata for verb conjugation and noun lemmatization
* frequency.csv - a list of the most frequently used Spanish words with part of speech, with all word variations combined into common lemma
* sentences.tsv - English/Spanish sentence pairs from tatoeba.org with users self-reported proficiency, part of speech tags, and lemmas

### Credits:
* eng-spa.tsv (CC-BY 2.0 FR Attribution: tatoeba.org, see CREDITS file for individual contributor credits)
* es-en.txt (CC-BY-SA Attribution: wiktionary.org)
* Many thanks to Matthias Buchmeier for the original [trans-en-es.awk](https://en.wiktionary.org/wiki/User:Matthias_Buchmeier/trans-en-es.awk) script (GPL2)
* tatoeba user [CK](https://tatoeba.org/eng/user/profile/CK) for the list of [reviewed English sentences](https://tatoeba.org/eng/sentences_lists/show/907)
* [FreeLing](http://nlp.lsi.upc.edu/freeling) for the part of speech tagging

# Building the datafiles

## Install required tools
```bash
sudo apt install curl bzip2 gawk pv unzip
pip3 install ijson
```

## Install FreeLing on Debian (for other distros, check the [FreeLing instructions](https://freeling-user-manual.readthedocs.io/en/latest/installation/installation-packages/))
```bash
wget https://github.com/TALP-UPC/FreeLing/releases/download/4.2/freeling-4.2-buster-amd64.deb
sudo apt install ./freeling-4.2-buster-amd64.deb libboost-chrono1.67.0 libboost-date-time1.67.0
```
## Check out the build tools
```bash
git clone https://github.com/doozan/spanish_tools.git
git clone https://github.com/doozan/6001_Spanish.git spanish_custom
mkdir spanish_data
### Build the deck
```bash
    wget -N -nv 'https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2'
    [ orig.es-en.txt -nt enwiktionary-latest-pages-articles.xml.bz2 ] || bzcat enwiktionary-latest-pages-articles.xml.bz2 \
      | gawk -v LANG=Spanish -v ISO=es -v REMOVE_WIKILINKS="y" -v ENABLE_SYN="y" -v ENABLE_META="y" -f spanish_tools/trans-en-es.awk \
      | pv > orig.es-en.txt || return 1
    sort -s -d -k 1,1 -t"{" -o orig.es-en.txt orig.es-en.txt
    spanish_tools/process_meta.py orig.es-en.txt > spanish_data/es-en.txt || return 1
```
### Build the deck
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

    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}($4 in A){print $1 "\t" $3 "\t" $4 "\t50" }' spa_5.txt - > spa_sentences.tsv
    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}($4 in A){print $1 "\t" $3 "\t" $4 "\t40" }' spa_4.txt - >> spa_sentences.tsv
    bzcat spa_sentences_detailed.tsv.bz2 | awk 'BEGIN {FS="\t"} NR==FNR{A[$1];next}!($4 in A){print $1 "\t" $3 "\t" $4 "\t0" }' spa_known.txt - >> spa_sentences.tsv

    cat<<'EOF'>join.awk
        BEGIN {FS="\t"}
        FNR == 1 {FID++}
        FID==1{eng[$1] = $2; credit[$1] = $3; skill[$1] = $4}
        FID==2{spa[$1] = $2; credit[$1] = $3; skill[$1] = $4}
        FID==3 && $1 in eng && $2 in spa{ print eng[$1] "\t" spa[$2] "\tCC-BY 2.0 (France) Attribution: tatoeba.org #" $1 " (" credit[$1] ") & #" $2 " (" credit[$2] ")\t" skill[$1]+skill[$2] }
EOF

    bzcat eng-spa_links.tsv.bz2 | gawk -f join.awk eng_sentences.tsv spa_sentences.tsv - | pv > joined.tsv

    # sort by number of spaces in the spanish sentence
    cat joined.tsv | sort -k1,1 -k2,2 -t$'\t' --unique | awk 'BEGIN {FS="\t"}; {x=$1; print gsub(/ /, " ", x) "\t" $0}' | sort -n | cut -f 2- > eng-spa.tsv

    spanish_tools/build_sentences.py eng-spa.tsv > spa-only.txt || return 1
    [ spa-only.txt.json -nt eng-spa_links.tsv.bz2 ] || spanish_tools/build_tags.sh spa-only.txt || return 1
    spanish_tools/build_sentences.py eng-spa.tsv --tags spa-only.txt.json | pv > spanish_data/sentences.tsv || return 1
```
### Build the frequency list
```bash
    wget -N -nv https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_50k.txt
    spanish_tools/freq.py es_50k.txt --ignore spanish_custom/ignore.txt > spanish_data/frequency.csv
```
