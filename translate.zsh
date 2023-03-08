#!/bin/zsh

API_KEY=redacted
API_PATH="https://localise.biz/api/export/locale/LANGUAGE.xml?format=android&status=translated,!same-as-source&order=id&filter=!iosonly"
API_CHECK="https://localise.biz/api/locales/LANGUAGE/errors"
OUTPUT_DIR="design/src/main/res"
#Matches any fullstops in the string name and replaces with an underscore
TRANSFORM="s/\(name=\"[a-z_]*\)\./\1_/g"

function isFileUpdated {
  #Checks the file timestamp to see if it was touched in last 60 seconds

  readonly file=${1:?"The file must be specified"}

  CURTIME=$(date +%s)
  FILETIME=$(stat -t %s -f %m $file)
  TIMEDIFF=$(expr $CURTIME - $FILETIME)

  if [[ $TIMEDIFF -gt 60 ]]; then
    echo "false"
  else
    echo "true"
  fi
}

declare -A pairs
pairs=(  en values
         en-GB values-en-rGB
         it values-it
         fr values-fr
         es values-es
         de values-de
         zh values-zh
         ja values-ja
         ko values-ko
         pt values-pt
         sv values-sv
         da values-da
      )

cd $OUTPUT_DIR

ERROR_FOUND=false
for lang in ${(k)pairs}; do
  lines=`curl -s -u $API_KEY: ${API_CHECK:s/LANGUAGE/$lang} | wc -l`
  if [[ $lines -gt 1 ]]; then
    echo "Error for $lang"
    ERROR_FOUND=true
  fi
done

if [[ $ERROR_FOUND == true ]]; then
  #exit
fi

for lang dir in ${(kv)pairs}; do
  mkdir -p $dir
  file=$dir/strings.xml
  tmp_file=$dir/strings.xml.tmp
  #Fail silently (so file has zero size for failure) and silence successful responses so the console isn't full of comments
  curl -f -s -u $API_KEY: ${API_PATH:s/LANGUAGE/$lang} | sed -e ${TRANSFORM} > $tmp_file
  #If the file size is > 0
  if [[ -s $tmp_file ]]; then
    mv $tmp_file $file
  else
    echo "Extraction error for $lang"
    rm $tmp_file
  fi
  echo -n "."
done
echo

if [[ `isFileUpdated values/strings.xml` == "true" ]]; then
  sed -i "" 's/xmlns:xliff=\"urn:oasis:names:tc:xliff:document:1.2\"/xmlns:tools=\"http:\/\/schemas.android.com\/tools\" xmlns:xliff=\"urn:oasis:names:tc:xliff:document:1.2\" tools:locale=\"en\"/' values/strings.xml
fi

# French can use Many plural but this only applies when > 1M so not important to us
if [[ `isFileUpdated values-fr/strings.xml` == "true" ]]; then
  sed -i "" 's/\(plurals[ a-z_:=].*\)>/\1 tools:ignore=\"MissingQuantity\">/' values-fr/strings.xml
  sed -i "" 's/<resources/<resources xmlns:tools=\"http:\/\/schemas.android.com\/tools\"/' values-fr/strings.xml
fi

#Ignore GoCity misspelling of Inclusive in German
if [[ `isFileUpdated values-de/strings.xml` == "true" ]]; then
  sed -i "" 's/\(>.*Inclusive.*\)>/ tools:ignore=\"Typos\"\1>/' values-de/strings.xml
  sed -i "" 's/<resources/<resources xmlns:tools=\"http:\/\/schemas.android.com\/tools\"/' values-de/strings.xml
fi
