cat $1 | epost -db nuccore -format acc | efetch -format fasta > $2
