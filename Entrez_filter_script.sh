	current=`cat $1 | epost -db nuccore -format acc`
	for filt in \
		'1:10000 [SLEN]'  \
		'NOT "gbdiv syn" [PROP]'  \
		'NOT "gbdiv est" [PROP]'  \
		'NOT "gbdiv gss" [PROP]'  \
		'NOT "gbdiv htg" [PROP]'  \
		'NOT "gbdiv pat" [PROP]'  \
		'NOT "src transgenic" [PROP]'  \
		'NOT "complete genome" [TITL]'  \
		'NOT "chromosome" [TITL]'  \
		'NOT "whole genome shotgun" [TITL]' 
	 do
		current=`echo "$current" | efilter -query "$filt"` 
# 		echo "$current" | xtract -pattern ENTREZ_DIRECT -element Count
	 done
	 echo "$current" | efetch -format acc
