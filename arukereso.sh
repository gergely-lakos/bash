#!/bin/bash
#created by Gergely LAKOS - mail@lakosg.hu
#2023
#arukereso.hu - webscrapping 

#declare variables
EMAIL=""
CSV="/tmp/arukereso.csv"
MAIL_CONTENT="/tmp/arukereso.mail"
TMP_CSV="/tmp/arukereso.csv.tmp"

DATE=$(date "+%Y-%m-%d")

#insert new col
new_col() {
    NEW_ITEM_PRICE=$1
    FILTER=$2

    #create tmp file
    cp $CSV $TMP_CSV
    
    NEW_COL="\"$DATE~$NEW_ITEM_PRICE\""
    ROW_NUMBER=$(cat $CSV | nl | grep "$FILTER" | awk '{print $1}')
    awk -v col="$NEW_COL" -v row="$ROW_NUMBER" 'BEGIN {FS=OFS=","} {if (NR==row) $0 = $0 OFS col; print}' "$TMP_CSV" > "$CSV"
}


#main

#create data file
if [ ! -f "$CSV" ]; then
  touch $CSV
fi

#arukereso url
START_URL="https://www.arukereso.hu/mikrohullamu-suto-c3179/f:beepitheto,urtartalom=4;5/"

#get all item pages
echo -e "$START_URL\n$(wget -q -O - "$START_URL" | grep "start=.*onclick=" | sed -e "s~.*href=\"\(.*\)\" onclick.*~\1~" | sort | uniq)" | while read URL; do
  #get all items
  wget -q -O - "$URL" | grep "<a.*class=\"price\"" | grep -v "productads.hu" | while read LINE; do
    #multi shop
    if [ "$(echo $LINE | grep "Árak összehasonlítása" | wc -l)" -gt 0 ]; then
        ITEM=$(echo $LINE | sed -e "s~.*href=\(.*\) data-akl.*title=\"\(.*\)\">\(.*\) Ft-tól</a>~\1;\2;\3~")
        ITEM_NAME=$(echo "$ITEM" | awk -F";" '{print $2}' | sed -e 's~\(.*\) - Árak.*~\"\1\"~')
        ITEM_URL=$(echo "$ITEM" | awk -F";" '{print $1}')
        ITEM_PRICE=$(echo "$ITEM" | awk -F";" '{print $3}' | tr -d " ")
        CSV_ITEM_LAST_PRICE=$(grep "$ITEM_URL" $CSV | awk -F"," '{print $NF}' | tr -d "\"" | cut -d "~" -f2)
        CSV_FIND=$ITEM_URL
    #simple shop
    else
        ITEM=$(echo $LINE | sed -e "s~.*href=\(.*\) data-akptp.*trackJump(\(.*\), 0).*nofollow\">\(.*\) Ft</a>~\1;\2;\3~")
        ITEM_NAME=$(echo $ITEM | awk -F";" '{print $2}' | awk -F"," '{print $4}' | tr "'" "\"")
        ITEM_URL=$(echo "$ITEM" | awk -F";" '{print $1}')
        ITEM_PRICE=$(echo "$ITEM" | awk -F";" '{print $3}' | tr -d " ")
        PROD_ID=$(echo $ITEM_URL | sed -e "s~.*Jump.php?\(.*\)&ProductType.*~\1~")
        CSV_ITEM_LAST_PRICE=$(grep "$PROD_ID" $CSV | awk -F"," '{print $NF}' | tr -d "\"" | cut -d "~" -f2)
        CSV_FIND=$PROD_ID
    fi   

    #item is not in data file 
    if [ -z "$CSV_ITEM_LAST_PRICE" ]; then
      echo "$ITEM_NAME,$ITEM_URL,\"$DATE~$ITEM_PRICE\"" >> $CSV;
    #price changed
    elif [ $ITEM_PRICE -ne $CSV_ITEM_LAST_PRICE ]; then
        #add new column to the item's row
        new_col "$ITEM_PRICE" "$CSV_FIND"
        #calculate price diff 
        PRICE_DIFF=$(echo "scale=3; ($ITEM_PRICE-$CSV_ITEM_LAST_PRICE)/$CSV_ITEM_LAST_PRICE*100" | bc -l)

        #add changed data to the mail content
        echo "Termék: $ITEM_NAME; Árváltozás mértéke: $PRICE_DIFF%; Új ár: $ITEM_PRICE; Link: $ITEM_URL" >> $MAIL_CONTENT
    fi
  done
done

#if mail content is not empty
if [ -f "$MAIL_CONTENT" ]; then
  echo "Levél menne!"
  cat $MAIL_CONTENT
fi

#delete temp files
rm -rf $MAIL_CONTENT
rm -rf $TMP_CSV