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
pip3 install ijson pywikibot mwparserfromhell pyglossary PyICU
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
### Build the wordlist
```bash
    wget -N -nv 'https://dumps.wikimedia.org/enwiktionary/latest/enwiktionary-latest-pages-articles.xml.bz2'
    [ es-en.unsorted.txt -nt enwiktionary-latest-pages-articles.xml.bz2 ] || enwiktionary_wordlist/make_wordlist.py \
	    --xml enwiktionary-latest-pages-articles.xml.bz2 --lang-id es | pv > es-en.unsorted.txt || return 1
    sort -s -k 1,1 -t"{" -o es-en.withforms.txt es-en.unsorted.txt
    grep -v "\-forms}" es-en.withforms.txt > spanish_data/es-en.txt
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

    bzcat eng-spa_links.tsv.bz2 | gawk -f join.awk eng_sentences.tsv spa_sentences.tsv - | pv > joined.tsv || return 1

    # sort by number of spaces in the spanish sentence
    cat joined.tsv | sort -k1,1 -k2,2 -t$'\t' --unique | awk 'BEGIN {FS="\t"}; {x=$1; print gsub(/ /, " ", x) "\t" $0}' | sort -n | cut -f 2- > eng-spa.tsv

    spanish_tools/build_sentences.py --dictionary es-en.withforms.txt eng-spa.tsv > spa-only.txt || return 1
    [ spa-only.txt.json -nt eng-spa_links.tsv.bz2 ] || spanish_tools/build_tags.sh spa-only.txt || return 1
    spanish_tools/build_sentences.py --dictionary es-en.withforms.txt eng-spa.tsv --tags spa-only.txt.json | pv > spanish_data/sentences.tsv || return 1
```
### Build the frequency list
```bash
    wget -N -nv https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/es/es_50k.txt
    spanish_tools/freq.py --dictionary es-en.withforms.txt es_50k.txt --ignore spanish_custom/ignore.txt > spanish_data/frequency.csv
```
### Build the Spanish-English Stardict dictionary
```bash

python3 -m enwiktionary_wordlist.wordlist_to_dictunformat es-en.withforms.txt --lang-id es \
	--description "Spanish-English dictionary. Compiled by Jeff Doozan from Wiktionary data $TAG. CC-BY-SA" \
	> es-en.dictunformat
~/.local/bin/pyglossary es-en.dictunformat es-en.ifo -w merge_syns=1 || return 1

# Converting from dictunformat doesn't split synonyms, so use ifo as intermediary
~/.local/bin/pyglossary es-en.dictunformat es-en.temp.ifo || return 1
~/.local/bin/pyglossary es-en.temp.ifo es-en.slob || return 1
```
#:/DECKDOC
}

publish_deck() {
    # Create a release
    response=$( curl -H "Content-Type:application/json" -H "Authorization: token $TOKEN" \
        https://api.github.com/repos/doozan/6001_Spanish/releases \
        -d "{ \"tag_name\":\"$TAG\", \"name\": \"6001_Spanish_Vocab-$TAG\", \"body\": \"Jeff's 6001 Spanish Vocab, release $TAG\"}" )

    UPLOAD_URL=$( echo "$response" | grep upload_url | cut -d '"' -f 4 | cut -d '{' -f 1 )
    echo UPLOAD_URL=$UPLOAD_URL

    # Add the deck
    FILE=jeffs_deck.apkg
    [ -f $FILE ] || { echo $FILE is not a file ; return 1; }
    curl -H "Authorization: token $TOKEN" \
         -H "Content-Type: application/octet-stream" \
         --data-binary @$FILE \
         "$UPLOAD_URL?name=Jeffs_6001_Spanish_Vocab-$TAG.apkg"
}

publish_dictionary() {
    # Create a release
    response=$( curl -H "Content-Type:application/json" -H "Authorization: token $TOKEN" \
        https://api.github.com/repos/doozan/Spanish_Data/releases \
        -d "{ \"tag_name\":\"$TAG\", \"name\": \"Spanish-English-Dictionary-$TAG\", \"body\": \"Spanish-English dictionary, release $TAG\"}" )

    UPLOAD_URL=$( echo "$response" | grep upload_url | cut -d '"' -f 4 | cut -d '{' -f 1 )
    echo UPLOAD_URL=$UPLOAD_URL

    # Add the dictionary
    FILE=dictionary.zip
    zip $FILE es-en.ifo es-en.idx es-en.dict.dz
    curl -H "Authorization: token $TOKEN" \
         -H "Content-Type: application/octet-stream" \
         --data-binary @$FILE \
         "$UPLOAD_URL?name=Spanish-English-Wiktionary-$TAG.StarDict.zip"

    # Add the wordlist
    FILE=es-en.slob.zip
    zip $FILE es-en.slob
    curl -H "Authorization: token $TOKEN" \
         -H "Content-Type: application/octet-stream" \
         --data-binary @$FILE \
         "$UPLOAD_URL?name=Spanish-English-Wiktionary-$TAG.slob.zip"

}

main() {
    BUILDDIR=$(pwd)/spanish-$TAG
    [ -d $BUILDDIR ] || mkdir  $BUILDDIR
    cd $BUILDDIR
    clone_repos

    echo "Building wordlist"
    build_wordlist || { echo "Wordlist build failed"; exit 1; }
    #build_newdict || { echo "New Dictionary build failed"; }

    echo "Building sentences"
    build_sentences || { echo "Sentences failed"; exit 1; }

    echo "Building frequency list"
    build_frequency || { echo "Frequency list failed"; exit 1; }

    echo "Building deck"
    build_deck || { echo "Deck build failed"; exit 1; }

    echo "Building dictionary"
    build_dictionary || { echo "Dictionary build failed"; exit 1; }

    # Update the docs
    cd ..
    $0 --datadoc > $BUILDDIR/spanish_data/README.md
    $0 --deckdoc > $BUILDDIR/spanish_custom/README.md

    # Commit the data changes
    cd $BUILDDIR/spanish_data
    if ! git diff --no-ext-diff --quiet --exit-code; then
        git commit -a -m "Automatic build $(date +%F)"
        git push

        # If there are changes, make a release
        cd $BUILDDIR
        publish_dictionary || { echo "Dictionary release failed"; exit 1; }
    fi

    # Commit the deck changes and publish a release
    cd $BUILDDIR/spanish_custom
    if ! git diff --no-ext-diff --quiet --exit-code; then
        git commit -a -m "Automatic build $(date +%F)"
        git push

        # If there are deck changes, make a release
        cd $BUILDDIR
        publish_deck || { echo "Deck release failed"; exit 1; }
    fi

    cd $BUILDDIR
    echo "Syncing the changes to Anki server"
    xvfb-run -a spanish_tools/sync_anki.py jeffs_deck.apkg --anki "User 1" --remove removed.txt || { echo "Sync failed"; exit 1; }

    #rm -rf $BUILDDIR
    echo "done"
}

main
