#!/bin/bash

DM="http://www.XXX.com"

function log()
{
	logTm=`date "+%Y-%m-%d %H:%M:%S"`
	echo $logTm" "$1 >> log.txt
}


function getTmpFileName()
{
	fn=`date  "+%Y%m%d_%H%M%S_%N"`
	echo ${fn}
}

function catchHome()
{
	ret=`curl -o tmp/index.html -s -w "%{http_code}" ${DM}`
	log $1" status:"$ret
	if [ ${ret} = "200" ]; then 
		return 0
	else 
		return 1
	fi
}


function checkPerformance()
{
	log "-----------------------------------------------"
	log " test performance using tmp/urls.txt >>"
	if [ -f "tmp/urls.txt" ];then
		echo "" > tmp/url_pfm.txt
		for row in `cat tmp/urls.txt`
		do
			url=`echo $row | cut -d, -f3`
			log " test "${url}
			pfm=`curl -o /dev/null -s -w '%{http_code},%{time_total},%{time_namelookup},%{time_connect},%{time_pretransfer},%{time_starttransfer},%{speed_download},%{size_download}' ${url}`			
			timetk=`date  "+%Y%m%d,%H%M%S"`
			echo $timetk","$row","$pfm >> tmp/url_pfm.csv
			echo ${url}
		done
	fi
	log "<< test performance finish"
}


function collectProduct()
{
	echo "" >> tmp/product.txt && rm tmp/product.txt
	cateUrl=`echo ${DM}/0-$1-0-0-0-0-0-0-0-0.html`
	pageCount=`curl -s ${cateUrl} | grep "共.*页" | sed -e "s/[^0-9]*//g"`
	log "Category["$1"] pages["$pageCount"]"
	for ((i = 1; i < $pageCount + 1; i++));
	do
		url="${DM}/0-$1-$i-0-0-0-0-0-0-0.html"
		log "Fetch product from Category["$1"] ..."
		curl -s $url | grep -e "product/[0-9]*.html" | awk '{printf("http%shtml\n",gensub(/.*http(.*)html.*/,"\\1",1));}' > tmp/product.txt
		for p in `cat tmp/product.txt`
		do
			echo "P,["$1"],"$p >> tmp/urls.txt
			productId=`echo $p | sed "s/[^0-9]//g" | head -1`
			log "		product["$productId"] was found"
			curl -s $p | grep "jqimg" | awk -v prdid="${productId}" '{img=gensub(/.*jqimg="(.*)" src.*/,"\\1",1);printf("I,[%s],%s\nI,[%s],%s?imageView2/1/h/350/w/350\n",prdid,img,prdid,img);}' | sed 's/com\/\//com\//' >> tmp/urls.txt
		done
	done
}


function collectCategory()
{
	grep "${DM}/cate" tmp/index.html | awk '{printf("%s\n",gensub(/.*cate\/(.*)\.html.*/,"\\1",1));}' > tmp/cate.txt
	for f in `cat tmp/cate.txt | cut -d, -f1`
	do
		echo "C,[${f}],${DM}/0-${f}-0-0-0-0-0-0-0-0.html" >> tmp/urls.txt
		collectProduct $f
	done
}


function main()
{
	rm tmp/* && echo "H,[],${DM}" >> tmp/urls.txt	
	catchHome && collectCategory	
}


if [ $# == 0 ]; then
	echo "Usage DetectZombieURL -s getLinks/testLinks"
fi
while getopts "s:" arg 
do
        case $arg in
             s)
                if [ "getLinks" = $OPTARG ]; then
                	main
                else
                	if [ "testLinks" = $OPTARG ]; then
                		checkPerformance
                	else
                		echo "Usage DetectZombieURL -s getLinks/testLinks"
                	fi
                fi
                ;;
             *)  
	            echo "Usage DetectZombieURL -s getLinks/testLinks"
        exit 1
        ;;
        esac
done

