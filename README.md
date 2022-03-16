This data is built from [Wiktionary](https://en.wiktionary.org) and [Tatoeba](tatoeboa.org) datasets using my [Wiktionary Parser](https://github.com/doozan/enwiktionary_parser) and [Spanish Tools](https://github.com/doozan/spanish_tools)

This data is used to build the free, open-source Spanish to English dictionary available in StarDict and Aard2/slob formats in the [Release section](https://github.com/doozan/spanish_data/releases). It's also used to build my [6001 Spanish Vocab](https://github.com/doozan/6001_Spanish) anki deck, and is provided here with the hope that others may find additional uses for it.

### Interesting files:
* es-en.data - Spanish to English Wiktionary data formatted for use with [enwiktionary_wordlist](https://github.com/doozan/enwiktionary_wordlist)
* frequency.csv - a list of the most frequently used Spanish lemmas with part of speech and word forms combined into lemma
* sentences.tsv - English/Spanish sentence pairs from tatoeba.org with users self-reported proficiency, part of speech tags, and lemmas

### Credits:
* es-en.data (CC-BY-SA Attribution: wiktionary.org)
* frequency.csv (CC-BY-SA 3.0 github.com/hermitdave/FrequencyWords)
* sentences.tsv (CC-BY 2.0 FR Attribution: tatoeba.org)
* tatoeba user [CK](https://tatoeba.org/eng/user/profile/CK) for the list of [reviewed English sentences](https://tatoeba.org/eng/sentences_lists/show/907)
* tatoeba user [arh](https://tatoeba.org/eng/user/profile/arh) for the list of [reviewed Spanish sentences](https://tatoeba.org/eng/sentences_lists/show/6685)
* [FreeLing](http://nlp.lsi.upc.edu/freeling) for the part of speech tagging

# Building the datafiles

## Install required tools
```bash
sudo apt install curl bzip2 gawk pv unzip zip pkg-config dictzip make
pip3 install ijson pywikibot mwparserfromhell pyglossary PyICU Levenshtein
```

## Install FreeLing on Debian (for other distros, check the [FreeLing instructions](https://freeling-user-manual.readthedocs.io/en/latest/installation/installation-packages/))
```bash
wget https://github.com/TALP-UPC/FreeLing/releases/download/4.2/freeling-4.2-buster-amd64.deb
sudo apt install ./freeling-4.2-buster-amd64.deb libboost-chrono1.67.0 libboost-date-time1.67.0
```

### Download and run the Makefile
```
curl https://github.com/doozan/spanish_data/raw/master/Makefile -o Makefile
make
```
