This data is build from [Wiktionary](https://en.wiktionary.org) and [Tatoeba](tatoeboa.org) datasets using my [Spanish Tools](https://github.com/doozan/spanish_tools)

This data is primarily used to build my 6001 Spanish Vocab anki deck, but it's provided here in case it may be useful for other purposes.

### Interesting files:
* 2018_es_50k.csv - a list of the most frequently used Spanish words with part of speech and grouped by lemmas
* eng-spa.tsv - English/spanish sentence pairs from tatoeba.org with users self-reported proficiency
* es-en.txt - Spanish to english dictionary, with metadata for verb conjugation and noun lemmatization
* sentences.json - the sentence pairs from eng-spa.tsv with part of speech information

### Credits:
* eng-spa.tsv and sentences.json sentences are (CC-BY 2.0 FR Attribution: tatoeba.org)
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
### Check out the build tools
```bash
    git clone https://github.com/doozan/spanish_ankideck.git
    cd spanish_ankideck
    mkdir spanish_data
```
### Build the deck
```bash
    curl 'https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2' \
      | bzcat \
      | gawk -v LANG=Spanish -v ISO=es -v REMOVE_WIKILINKS="y" -v ENABLE_SYN="y" -v ENABLE_META="y" -f trans-en-es.awk \
      > orig.es-en.txt
    sort -s -d -k 1,1 -t"{" -o orig.es-en.txt orig.es-en.txt
    ./process_meta.py orig.es-en.txt > spanish_data/es-en.txt
```
### Build the deck
```bash
    wget https://downloads.tatoeba.org/exports/per_language/spa/spa_sentences_detailed.tsv.bz2
    wget https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences_detailed.tsv.bz2
    wget https://downloads.tatoeba.org/exports/per_language/eng/eng-spa_links.tsv.bz2
    wget https://downloads.tatoeba.org/exports/sentences_in_lists.tar.bz2
    wget https://downloads.tatoeba.org/exports/user_languages.tar.bz2

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
    cat joined.tsv | sort -k1,1 -k2,2 -t$'\t' --unique | awk 'BEGIN {FS="\t"}; {x=$1; print gsub(/ /, " ", x) "\t" $0}' | sort -n | cut -f 2- >  spanish_data/eng-spa.tsv

    ./build_sentences.py spanish_data/eng-spa.tsv > spa-only.txt

    ./build_tags.sh spa-only.txt
    ./build_sentences.py spanish_data/eng-spa.tsv --tags spa-only.txt.json | pv > spanish_data/sentences.json
```
### Build the frequency list
```bash
    curl https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_50k.txt -o 2018_es_50k.txt
    ./freq.py 2018_es_50k.txt --ignore spanish_data/2018_es_50k.ignore > spanish_data/2018_es_50k.csv
```
### Build the deck
```bash
    xvfb-run ./build_deck.py jeffs_deck --limit 5200 -w spanish_data/2018_es_50k.csv -w extras.csv -w excludes.csv --dump-sentence-ids spanish_data/sentences.preferred --dump-notes spanish_data/jeffs_deck.csv --anki "User 1" --model jeffs_deck.model
```
