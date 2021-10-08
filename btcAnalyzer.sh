#!/bin/bash
#colores
red="\e[1;31m"
green="\e[1;32m"
yellow="\e[1;33m"
blue="\e[1;34m"
purple="\e[1;35m"
cyan="\e[1;36m"
white="\e[1;37m"
end="\e[0m"

# Ctrl+C
trap ctrl_c INT
function ctrl_c(){
	echo -e "${red}\nSaliendo...${end}"
	rm i* o* ut* money* add* 2>/dev/null
	exit 1
}
# Variables Globales
transaction_unconfirmed_url="https://www.blockchain.com/btc/unconfirmed-transactions"
inspect_transaction_url="https://www.blockchain.com/btc/tx/"
inspect_address_url="https://www.blockchain.com/btc/address/"

# Funciones
# Funcion tablas >>>
function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}
function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}
function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}
function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}
#tablas <<<
function helpPanel(){ # Panel de ayuda
	echo -e "${red}\n[!]Modo de uso: ./BlockChain.sh <parametros>${end}"
	for line in $(seq 1 90); do echo -ne "${purple}-"; done; echo -ne "${end}"
	echo -e "\n\t${blue}[-e]${end}${yellow} Mostrar transacciones generales${end}"
	echo -e "\t\t${cyan}transaction${end}${yellow}:\t\tLista transacciones no confirmadas${end}"
	echo -e "\t\t${cyan}inspect${end}${yellow}:\t\tInspecciona un hash de transaccion agregando un identificador [-i <id>]${end}"
	echo -e "\t\t${cyan}address${end}${yellow}:\t\tInspecciona la direccion de una hash agregando un identifcador [-a <id> | -o <id>]${end}"
	echo -e "\n\t${blue}[-i]${end}${yellow} Proporcionar el dentificador de transaccion${end}"
	echo -e "\t\t${cyan}Ejemplo: ./BlockChain.sh -e inspect -i 3${end}"
	echo -e "\n\t${blue}[-a]${end}${yellow} Selecctiona el Id de las direcciones de entrada${end}"
	echo -e "\t\t${cyan}Ejemplo: ./BlockChain.sh -e address -a 1${end}"
	echo -e "\n\t${blue}[-o]${end}${yellow} Selecciona el Id de las direcciones de salida${end}"
	echo -e "\t\t${cyan}Ejemplo: ./BlockChain.sh -e address -o 1${end}"
	echo -e "\n\t${blue}[-l]${end}${yellow} Limitar el numero de resultados para las transacciones no confirmadas${end}"
	echo -e	"\t\t${cyan}Ejemplo: ./BlockChain.sh -e transaction -l 10${end}"
	echo -e "\n\t${blue}[-h]${end}${yellow} Panel de ayuda${end}"
	rm i* o* ut* money* add* 2>/dev/null
	exit 1
}
function unconfirmed_transactions(){ # Mostrar transacciones no confirmadas
	number_output=$1
	echo '' > ut.tmp
	while [ $(cat ut.tmp | wc -l) == 1 ]; do
		curl -s $transaction_unconfirmed_url | html2text > ut.tmp
	done
	hashes=$(cat ut.tmp | grep "Hash" -A 1 | grep -v -E "Hash|--|Time" | head -n $number_output)

	echo "Id_Hash_Cantidad_Bitcoin_Tiempo" > ut.table
	id=1
	for hash in $hashes; do
		echo "${id}_${hash}_$(cat ut.tmp | grep "$hash" -A 6 | awk 'NR==7')_$(cat ut.tmp | grep "$hash" -A 6 | awk 'NR==5')_$(cat ut.tmp | grep "$hash" -A 6 | awk 'NR==3')" >> ut.table
		let id+=1
	done
	cat ut.table |tr '_' ' ' | awk '{print $3}' | grep -v "^C" | tr -d '$' |tr -d ','| sed 's/\..*//g' > money.tmp
	money=0; cat money.tmp | while read money_in_line; do
		let money+=$money_in_line
		echo $money > money_all.tmp
	done
	echo -n "Cantidad total dolares_" > money.table
	echo  "$(printf "\$%'d" $(cat money_all.tmp))" >> money.table

	if [[ $(cat money.table) != 1 ]];then
		echo -e $purple
		printTable '_' "$(cat ut.table)"
		echo -e $end
		echo -e ${blue}
		printTable '_' "$(cat money.table)"
		echo -e ${end}
	fi
	rm ut.tmp 2> /dev/null
	rm money* 2> /dev/null
}
function inspectTransaction(){
	identificator=$1
	hash_id=$(cat ut.table | tr '_' ' ' | grep "^${identificator}\s" | awk '{print $2}')

	if [[ $hash_id ]]; then
		#Inspect hash id
		echo "Id_Hash_Entrada Total_Salida Total" > it.table
		echo -n "${identificator}_${hash_id}_" >> it.table
		curl "${inspect_transaction_url}${hash_id}" -s | html2text | grep -iE "total input|total output" -A 1 | grep -v "^T" | xargs | tr ' ' '_' | sed 's/_BTC/ BTC/g' >> it.table
		echo -e ${yellow}
		printTable '_' "$(cat it.table)"
		echo -e ${end}

		#inspect hash id Input
		echo "Id_Direccion (Entradas)_Gasto (BTC)" > input.table
		curl -s "${inspect_transaction_url}${hash_id}" |html2text | grep "Inputs" -A 100 | grep "Outputs" -B 100 | grep "Address" -A 3 | grep -v -E "Address|Value|--" |awk 'NR%2!=0 {printf "%s ",$0;next;}1' | awk '{print NR "_" $1 "_" $2 " " $3}' >> input.table
		echo -e ${cyan}
		printTable '_' "$(cat input.table)"
		echo -e ${end}

		#inspect hash id output
		echo "Id_Direccion (Salidas)_Sin Gastar (BTC)" > output.table
curl -s "${inspect_transaction_url}${hash_id}" |html2text |grep "Outputs" -A 100 | grep "\[Unknown INPUT type\]" -B 100 | grep "Address" -A 3 | grep -v -E "Address|--|Value|Pkscript" | awk 'NR%2!=0 {printf "%s_", $0;next;}1' | awk '{print NR "_" $0}' >> output.table
		echo -e	${cyan}
		printTable '_' "$(cat output.table)"
		echo -e ${end}
	fi

#	rm i* o* 2> /dev/null
}
function address_input(){
	identificator_address_in=$1
	hash_id_input=$(cat input.table | grep "^${identificator_address_in}" | awk -F '_' '{print $2}')
	money_address_input=$(cat input.table | grep "^${identificator_address_in}" | awk -F '_' '{print $3}')

	echo "Id_Direccion de Entrada_Gasto (BTC)" > add_input.tmp
	echo "${identificator_address_in}_${hash_id_input}_${money_address_input}" >> add_input.tmp

	if [[ $hash_id_input ]]; then
		echo "No Transacciones_Total Recibido_Total Enviado_Saldo Final" > add_input.table
		curl -s "${inspect_address_url}${hash_id_input}" | html2text |grep "^Transactions" -m 1 -A 8 | awk 'NR%2==0 {printf "%s_", $0}' | sed 's/_$//' >> add_input.table

		echo -e ${cyan}
		printTable '_' "$(cat add_input.tmp)"
		echo -e ${end}
		echo -e ${white}
		printTable '_' "$(cat add_input.table)"
		echo -e ${end}
	fi
#	rm add* input* 2> /dev/null
}
function address_output(){
	identificator_address_out=$1
	hash_id_output=$(cat output.table | grep "^${identificator_address_out}" | awk -F '_' '{print $2}')
	money_address_output=$(cat output.table | grep "^$identificator_address_out" | awk -F '_' '{print $3}')

	echo "Id_Direccion de Salida_Sin Gastar (BTC)" > add_output.tmp
	echo "${identificator_address_out}_${hash_id_output}_${money_address_output}" >> add_output.tmp

	if [[ $hash_id_output ]]; then
		echo "No transacciones_Total Recibido_Total Enviado_Saldo Final" > add_output.table
		curl -s "${inspect_address_url}${hash_id_output}" | html2text | grep "^Transactions" -m 1 -A 7 | awk 'NR%2==0 {printf "%s_", $0}' | sed 's/_$//' >> add_output.table

		echo -e ${cyan}
		printTable '_' "$(cat add_output.tmp)"
		echo -e ${end}
		echo -e ${white}
		printTable '_' "$(cat add_output.table)"
		echo -e ${end}
	fi
#	rm add* out* 2>/dev/null
}
#Opciones de Menu
while getopts ":e:i:a:o:l:h" arg; do
	case $arg in
		e) exploration_mode=$OPTARG;;
		i) identificator_transaction=$OPTARG;;
		a) identificator_address_input=$OPTARG;;
		o) identificator_address_output=$OPTARG;;
		l) number_output=$OPTARG;;
		h) helpPanel;;
		?) echo -e "${white}[!] Opcion -${OPTARG} invalida o falta de argumentos${end}";
			helpPanel;;
	esac
done
#Main Menu
if [[ ${#} -eq 0 ]]; then #cero argumentos
	helpPanel
else
	if [ $(echo $exploration_mode) == "transaction" ]; then #primera opcion
		if [[ ! $number_output ]]; then #numero de resultados
			number_output=50
		fi
		unconfirmed_transactions $number_output
	elif [[ $(echo $exploration_mode) == "inspect" ]]; then
		inspectTransaction $identificator_transaction
	elif [[ $(echo $exploration_mode) == "address" ]]; then
		if [[ $3 == "-a" ]]; then
			address_input $identificator_address_input
		elif [[ $3 == "-o" ]]; then
			address_output $identificator_address_output
		fi
	else
		echo -e "${white}[!] Argumento Incorrecto!${end}"
		helpPanel
	fi
fi
