#!/usr/bin/env bash
# This script creates plain text, or
# RTF with a comment holding a link back to bookends.
# Scrivener can make comments annotation by setting:
# defaults write com.literatureandlatte.scrivener3 KBRTFImportCommentsInline 1

UUID=$1
FRONTAPP=$(osascript -e 'tell application "System Events"' -e 'set frontApp to name of first application process whose frontmost is true' -e 'end tell')
if [ ${FRONTAPP} = "Scrivener" ]; then USERTF='true'; fi
LINKTEXT=$commentText

CITEMARKER='@'
[[ $usePandocFormat -lt 1 ]] && CITEMARKER='#'


if [[ $UUID =~ ^[0-9] ]]; then
BIBKEY=$(/usr/bin/osascript << EOT
tell application "Bookends"
    return «event ToySRFLD» "$UUID" given string:"user1"
end tell
EOT
)
else
BIBKEY=$UUID
UUID=$(cat /Users/zhope/Dropbox/Sundry/src.json | /usr/local/bin/jq -r --arg BIBKEY "${BIBKEY}" '.[] | select(.id==$BIBKEY) | .bookends')
fi

DTPOLINK=$(cat /Users/zhope/Dropbox/Sundry/src.json | /usr/local/bin/jq -r --arg BIBKEY "${BIBKEY}" '.[] | select(.id==$BIBKEY) | .DEVONthink')
LINKT=$(echo $LINKTEXT | iconv --unicode-subst="\'%02X" -f UTF8 -t ascii)

modifierBits=$(/usr/bin/python -c 'import Cocoa; print Cocoa.NSEvent.modifierFlags()')

if [ "$modifierBits" = "1966080" ]; then
read -r -d '' applescriptCode <<'EOF'
   set dialogText to text returned of (display dialog "Enter Citation Locator" default answer ", pp. ")
   return dialogText
EOF
dialogText=$(osascript -e "$applescriptCode");
fi

# RTF1=$(cat << EOT
# {\rtf1\ansi\ansicpg1252\cocoartf1561\cocoasubrtf200
# [$CITEMARKER$BIBKEY]{\chatn{\*\annotation{\field{\*\fldinst{HYPERLINK $URL}}{\fldrslt $LINKT}}}}   }
# EOT
# )

# we can't reset the pref just yet
if [[ $USEANNOTATION == 'true' ]]; then
  PREFVAL=$(defaults read com.literatureandlatte.scrivener3 KBRTFImportCommentsInline 2> /dev/null)
  if [[ $? -ne 0 ]]; then #there was no pref set
    REMOVEPREF=1
  else
    REMOVEPREF=0
  fi
  defaults write com.literatureandlatte.scrivener3 KBRTFImportCommentsInline 1 > /dev/null 2>&1
fi

if [[ $USERTF == 'true' ]]; then
  if [ -n "${DTPOLINK}" ] && [ -n "${dialogText}" ]; then
    if [[ $dialogText == ", p"* ]]; then thePage=$(echo "$dialogText" | grep -o -E '[0-9]+' | head -1); else thePage=""; fi
    echo "<font face=\"sf pro text\" font size=4 font color=#000000>[<a href=src://${BIBKEY} style=\"color: #000000; text-decoration: none\">@</a><a href$BIBKEY$dialogText]</a><a href=bookends://sonnysoftware.com/$UUID style=\"color: #000000; text-decoration: none\">${BIBKEY}</a><a href=${DTPOLINK}?page=${thePage} style=\"color: #000000; text-decoration: none\">${dialogText}</a>]</font>" | tr -d '\n' | textutil -stdin -stdout -format html -convert rtf | pbcopy -Prefer rtf
  else
    echo "<font face=\"sf pro text\" font size=3 font color=#000000>[<a href=src://${BIBKEY} style=\"color: #000000; text-decoration: none\">@</a><a href$BIBKEY$dialogText]</a><a href=bookends://sonnysoftware.com/$UUID style=\"color: #000000; text-decoration: none\">${BIBKEY}${dialogText}</a>]</font>" | tr -d '\n' | textutil -stdin -stdout -format html -convert rtf | pbcopy -Prefer rtf
  fi
else
  echo "[@$BIBKEY$dialogText]" | tr -d '\n' | pbcopy -Prefer txt
fi

# we can't reset the pref just yet
if [[ $USEANNOTATION == 'true' ]]; then
  if [[ $REMOVEPREF -gt 0 ]]; then #there was no pref set
    defaults delete com.literatureandlatte.scrivener3 KBRTFImportCommentsInline > /dev/null 2>&1
  else
    defaults write com.literatureandlatte.scrivener3 KBRTFImportCommentsInline $PREFVAL > /dev/null 2>&1
  fi
fi
