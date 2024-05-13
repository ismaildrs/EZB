help : ./backup.sh -h
manual : sudo ./backup.sh -m -s <filename> -n <name>
automatic : sudo ./backup.sh -a -s <filename> -n <name>
log :./backup.sh -l
restore :./backup.sh -r
thread : sudo ./backup.sh -t -m -s <foldername> -n <name>
fork : sudo ./backup.sh -fo -m -s <foldername> -n <name>
