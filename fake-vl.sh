#!/bin/sh


PAGE='home.php?bonusCash=0&eventPoints=0&formNonce=b9a2d84285926ad70fe62ddcb3e6a793ad843345&h=64c4f9fd9313e2175aa580fef46ef51ddf071f30'
PAGE='home.php'

URL="http://vl.storm8.com/$PAGE"
COOKIES='Cookie: asc=7ea39e90be128ea8f3231e1361f539237496a714; st=5817886%2Cb1e45ea87da3cf4cc9436ad6080de05793e67631%2C1307321860%2C12%2C%2Ca1.54%2C147%2C3%2Csdv10008-a1.54%2C2011-06-05+17%3A57%3A40%2C%2CAndroid%2Cminisdv2000%2C%2Cv1_1307321860_9c386252fc8fa0cb9f2a2819e221542cb941ec75'

COOKIES2='Cookie: asc=7ea39e90be128ea8f3231e1361f539237496a714; st=5817886,b1e45ea87da3cf4cc9436ad6080de05793e67631,1307321860,12,,a1.54,147,3,sdv10008-a1.54,2011-06-05+17:57:40,,Android,minisdv2000,,v1_1307321860_9c386252fc8fa0cb9f2a2819e221542cb941ec75'

UA='User-Agent: Mozilla/5.0 (Linux; U; Android 2.2; en-us; DROID2 Build/VZW) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1'

ACCEPT='Accept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5'

CHARSET='Accept-Charset: utf-8, iso-8859-1, utf-16, *;q=0.7'

wget -O - "$URL" --header "$COOKIES2"
