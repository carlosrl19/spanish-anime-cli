#!/bin/sh
# video_player ( needs to be able to play urls )

# ASCII ART
echo -e "\n································································"
echo -e "   ░█▀▀░█▀█░█▀█░█▀█░▀█▀░█▀▀░█░█░░█░█░█▀█░█▀█░▀█▀░░█▀▀░█░░░▀█▀"
echo -e "   ░▀▀█░█▀▀░█▀█░█░█░░█░░▀▀█░█▀█░░█▀█░█▀█░█░█░░█░░░█░░░█░░░░█░"
echo -e "   ░▀▀▀░▀░░░▀░▀░▀░▀░▀▀▀░▀▀▀░▀░▀░░▀░▀░▀░▀░▀░▀░▀▀▀░░▀▀▀░▀▀▀░▀▀▀"
echo -e "································································\n"

player_fn="mpv"

prog="hani-cli"
logfile="${XDG_CACHE_HOME:-$HOME/.cache}/hani-hsts"

# Supported sites.
monoschinos_url="https://monoschinos2.com"
jkanime_url="https://jkanime.net"

# Servers
okru_url="https://ok.ru/"

# UQload is the default server for monoschinos.
uqload=false
mp4upload=false
okru=false

c_red="\033[1;31m"
c_green="\033[1;32m"
c_yellow="\033[1;33m"
c_blue="\033[1;34m"
c_magenta="\033[1;35m"
c_cyan="\033[1;36m"
c_reset="\033[0m"


help_text () {
	while IFS= read line; do
		printf "%s\n" "$line"
	done <<-EOF
	USAGE: $prog <query>
	 -h	 mostrar ayuda
	 -d	 descargar episodio
	 -H	 continar donde se dejó
	 -D	 borrar historial

	EOF
}


die () {
	printf "$c_red%s$c_reset\n" "$*" >&2
	exit 1
}

err () {
	printf "$c_red%s$c_reset\n" "$*" >&2
}

search_anime () {
	# get anime name along with its id
	search=$(printf '%s' "$1" | tr ' ' '+')
	titlepattern_m='<a href="https://monoschinos2.com/anime/'
	results_1=$(curl -s "$monoschinos_url/buscar" -G -d "q=$search" |
	sed -n '/^<div class="series">/{g;1!p;};h' | sed -e "s|${titlepattern_m}||" -e 's\">*$\\')
	[ ! -z "$results_1" -a "$results_1" != " " ] && results_1=$(echo "$results_1" | sed 's/^/MC /g')
	search=$(echo $search | sed 's/+/_/')
	titlepattern_j='<h5><a  href="https://jkanime.net/'
	page_counter=1
	while [ "$page_counter" -gt 0 ]
	do
		page=$(curl -s -L "$jkanime_url/buscar/$search/$page_counter")
		appendable_result=$(echo "$page" |
		sed -e 's/^[[:space:]]\{1,'"$n"'\}//' -e '/^<h5><a  href="https:/!d' |
		sed -e "s|<h5><a  href=\"https://jkanime.net/||" -e 's|/.*$||')
		is_next=$(echo $page | sed -n '/<a class="text nav-next"/p')
		if [ -z "$results_2" ]
		then
			results_2="$appendable_result"
		else
			results_2="$results_2\n$appendable_result"
		fi
		if [ ! -z "$is_next" -a "$is_next" != " "  ]
		then
			page_counter=$(($page_counter+1))
		else
			page_counter=0
			[ ! -z "$results_2" -a "$results_2" != " " ] && results_2=$(echo "$results_2" | sed 's/^/JK /g')
		fi
	done
	[ ! -z "$results_1" -a ! -z "$results_2"  ] && echo "$results_1\n$results_2"
	[ -z "$results_1" -a ! -z "$results_2"  ] && echo "$results_2"
	[ ! -z "$results_1" -a -z "$results_2"  ] && echo "$results_1"
}

search_eps () {
	# get available episodes for anime_id
	anime_id=$1
	if [ "$uqload" = true ]
	then
		nodub_anime_id=`echo $anime_id  | sed 's|-sub-espanol||'`
		curl -s "$monoschinos_url/anime/$anime_id" | 
		sed -n '/^<p class="animetitles"/p' | sed -e '$!d' -e 's|<p class="animetitles">Capitulo||' | sed 's/<.*$//'
	else
		anime_id=$(echo "$anime_id" | sed 's/JK //g')
		curl -s -L "$jkanime_url/$anime_id" |
		sed -n '/<li><span>Episodios/p' |
		sed -e 's/^[[:space:]]\{1,'"$n"'\}//' -e 's|<li><span>Episodios:</span> ||' -e 's|</li>||'
	fi
}

get_embedded_video_link() {
	# get the download page url
	anime_id=$1	
	ep_no=$2
	if [ "$uqload" = false ]
	then
		anime_id=$(echo "$anime_id" | sed 's/JK //g')
		nodub_anime_id=`echo $anime_id  | sed 's|-sub-espanol||'`
		curl -s -L "$jkanime_url/$anime_id/$ep_no" |
		sed -n '/video\[2\] =/p' |
		sed -e 's/^[[:space:]]\{1,'"$n"'\}//' -e 's/^[^h]*//g' -e 's|-.*$||' -e 's|".*$||'
	else
		if [ "$mp4upload" = false ]
		then
			server="uqload</p>"
		elif [ "$okru" = false ]
		then
			server="mp4upload</p>"
		else
			server="ok</p>"
		fi
		anime_id=$(echo "$anime_id" | sed 's/UQLOAD_MC //g')
		nodub_anime_id=`echo $anime_id  | sed 's|-sub-espanol||'`
		curl -s "$monoschinos_url/ver/$nodub_anime_id-episodio-$ep_no" |
		grep $server |
		sed -e 's|<p class="play-video" data-player="||' -e 's|".*$||' |
		base64 --decode |
		sed "s|https://monoschinos2.com/reproductor?url=||"
	fi
}

get_links () {
	embedded_video_url=$1
	if [ "$uqload" = false ]
	then
		video_url=$(curl -s -L "$embedded_video_url" |
		sed -n "/url: '/p" | sed -e 's/^[[:space:]]\{1,'"$n"'\}//' -e '2d' -e "s/url: '//" -e "s|'.*$||")
	elif [ "$mp4upload" = true ] && [ "$okru" = false ]
	then
		html_page=$(curl -s "$embedded_video_url" | sed -n '/||player/p' | sed 's/^[^|]*|//')
		str=$(curl -s "$embedded_video_url" |
			sed -n '/||player/p' |
			sed 's/^[^|]*|//')
		parameters=$(echo $html_page | sed 's/|/\n/g')
		p_counter=0
		url=""
		p=$parameters
		while read p; do
			p_counter=$(($p_counter+1))
			case $p_counter in
				4) player_extension=$p;;
				6) player=$p;;
				7) url="$p://";;
				21) url="$url$p.$player.$player_extension:END/d/" ;;
				70) file_extension=$p ;;
				71) file_name=$p ;;
				72) url="$url$p/$file_name.$file_extension" ;;
				73) url=$(echo $url | sed "s/END/${p}/")
					video_url="$url"
			esac
		done<<-EOF
		$parameters
		EOF
	else
		video_url=$(curl -s "$embedded_video_url" |
		sed -n '/sources:/p' |
		sed -e 's/sources: \["//' -e 's/^[[:space:]]\{1,'"$n"'\}//'|
		sed 's|".*$||')
	fi

	echo $video_url
}

dep_ch () {
	for dep; do
		if ! command -v "$dep" >/dev/null ; then
			die "Programa \"$dep\" no instalado. Por favor, instalalo antes de usar hani-cli."
		fi
	done
}

# get query
get_search_query () {
	if [ -z "$*" ]; then
		printf "${c_blue}Buscar anime: "
		read -r query
	else
		query=$*
	fi
}

# create history file
[ -f "$logfile" ] || : > "$logfile"

#####################
## Anime selection ##
#####################

anime_selection () {
	search_results=$*
	menu_format_string='[%d](%s) %s\n'
	menu_format_string_c1="$c_blue[$c_cyan%d$c_blue]$c_magenta(%s) $c_reset%s\n"
	menu_format_string_c2="$c_blue[$c_cyan%d$c_blue]$c_magenta(%s) $c_yellow%s$c_reset\n"

	count=1
	while read anime_id; do
		# alternating colors for menu
		[ $((count % 2)) -eq 0 ] &&
			menu_format_string=$menu_format_string_c1 ||
			menu_format_string=$menu_format_string_c2
		nosub_anime_id=$(echo "$anime_id" | sed -e 's/-sub-espanol//g' -e 's/MC //g' -e 's/JK //g')
		if echo "$anime_id" | grep -q "MC "
		then
			site="MC"
		else
			site="JK"
		fi
		printf "$menu_format_string" "$count" "$site" "$nosub_anime_id"
		count=$((count+1))
	done <<-EOF
	$search_results
	EOF

	# User input
	printf "\n$c_blue%s$c_green" "Ingresa un número: "
	read choice
	printf "$c_reset"

	# Check if input is a number
	[ "$choice" -eq "$choice" ] 2>/dev/null || die "Número inválido, ingresa un número válido."

	# Select respective anime_id
	count=1
	while read anime_id; do
		if [ $count -eq $choice ]; then
			if echo "$anime_id" | grep -q "MC "
			then
				uqload=true
			fi
			selection_id=$(echo $anime_id | sed -e 's/MC //g' -e 's/JK //g')
			break
		fi
		count=$((count+1))
	done <<-EOF
	$search_results
	EOF

	[ -z "$selection_id" ] && die "Número inválido, ingresa un número válido."

	read last_ep_number <<-EOF
	$(search_eps "$selection_id")
	EOF
}

##################
## Ep selection ##
##################
episode_selection () {
	ep_choice_start="1"
	if [ $last_ep_number -gt 1 ] 
	then
		[ $is_download -eq 1 ] &&
			printf "Los rangos de episodios pueden ser especificados: número_inicial número_final\n"

		printf "${c_blue}Elige el episodio $c_cyan[1-%d]$c_reset:$c_green " $last_ep_number
		read ep_choice_start ep_choice_end
		printf "$c_reset"
	fi
}

check_input() {
	[ "$ep_choice_start" -eq "$ep_choice_start" ] 2>/dev/null || die "Número inválido, ingresa un número válido."
	episodes=$ep_choice_start
	if [ -n "$ep_choice_end" ]; then
		[ "$ep_choice_end" -eq "$ep_choice_end" ] 2>/dev/null || die "Número inválido, ingresa un número válido."
		# create list of episodes to download/watch
		episodes=$(seq $ep_choice_start $ep_choice_end)
	fi
}

append_history () {
	grep -q -w "${selection_id}" "$logfile" ||
		printf "%s\t%d\n" "$selection_id" $((episode+1)) >> "$logfile"
}

open_selection() {
	for ep in $episodes
	do
		open_episode "$selection_id" "$ep"
	done
	episode=${ep_choice_end:-$ep_choice_start}
}

open_episode () {
	anime_id=$1
	episode=$2
	# Cool way of clearing screen
	tput reset
	while [ "$episode" -lt 1 ] || [ "$episode" -gt "$last_ep_number" ]
	do
		err "Episodio fuera de rango"
		printf "${c_blue}Choose episode $c_cyan[1-%d]$c_reset:$c_green " $last_ep_number
		read episode
		printf "$c_reset"
	done

	printf "Obteniendo información del episodio Nº %d.\n" $episode
	embedded_video_url=""
	video_url=""
	while [ "$embedded_video_url" = "" ] || [ "$video_url" = "" ]
	do
		if [ "$uqload" = false ]
		then
			printf "Conectando a Desu...\n"
			embedded_video_url=$(get_embedded_video_link "$anime_id" "$episode")
			[ -z "$embedded_video_url" ] && die "Servidor no disponible."
			video_url=$(get_links "$embedded_video_url")
			[ -z "$video_url" ] && die "Parece que hay problemas para obtener el video del servidor."
		else
			if [ "$mp4upload" = false ]
			then
				printf "Conectando a Uqload...\n" 
				embedded_video_url=$(get_embedded_video_link "$anime_id" "$episode")
				video_url=$(get_links "$embedded_video_url")
				#https://m20.uqload.org/3rfkja7hbrw2q4drdiipdn5vanfoiixp3o2tvrw34pppm2rvwaezdfexuvza/v.mp4
			else
				if [ "$okru" = false ]
				then
					printf "Conectando a Mp4Upload...\n"
					anime_id=$(echo "$anime_id" | sed "s/UQLOAD/MP4UPLOAD/")
					embedded_video_url=$(get_embedded_video_link "$anime_id" "$episode")
					#echo $embedded_video_url >> 
					video_url=$(get_links "$embedded_video_url")
				else
					printf "Conectando a Ok...\n"
					anime_id=$(echo "$anime_id" | sed -e "s/MP4UPLOAD/OKRU/" -e "s/UQLOAD/OKRU/")
					embedded_video_url=$(get_embedded_video_link "$anime_id" "$episode")
					[ -z "$embedded_video_url" ] && die "Servidor no disponible."
					video_url=$embedded_video_url
					embedded_video_url=$okru_url
				fi
				okru=true
			fi
			mp4upload=true
		fi
	done
	case $video_url in
		*streamtape*)
			# If direct download not available then scrape streamtape.com
			BROWSER=${BROWSER:-firefox}
			printf "Conectando a streamtape.com\n"
			video_url=$(curl -s "$video_url" | sed -n -E '
				/^<script>document/{
				s/^[^"]*"([^"]*)" \+ '\''([^'\'']*).*/https:\1\2\&dl=1/p
				q
				}
			');;
	esac

	if [ $is_download -eq 0 ]; then
		# write anime and episode number
		sed -E "
			s/^${selection_id}\t[0-9]+/${selection_id}\t$((episode+1))/
		" "$logfile" > "${logfile}.new" && mv "${logfile}.new" "$logfile"
		setsid -f $player_fn --http-header-fields="Referer: $embedded_video_url" "$video_url" >/dev/null 2>&1
	else
		anime_name=$(echo anime_id | sed 's/^[^ ]* //g')
		printf "Descargando episodio $episode ...\n"
		printf "%s\n" "$video_url"
		# add 0 padding to the episode name
		episode=$(printf "%03d" $episode)
		{
			ffmpeg -headers "Referente: $embedded_video_url" -i "$video_url" \
				-c copy "${anime_name}-${episode}.mkv" >/dev/null 2>&1 &&
				printf "${c_green}Descarga finalizada episodio: %s${c_reset}\n" "$episode" ||
				printf "${c_red}Descarga fallida episodio: %s${c_reset}\n" "$episode"
		}
	fi
}

############
# Start Up #
############
# to clear the colors when exited using SIGINT
trap "printf '$c_reset'" INT HUP

dep_ch "$player_fn" "curl" "sed" "grep" "git"

# option parsing
is_download=0
scrape=query
while getopts 'hdHDquU:-:' OPT; do
	case $OPT in
		h)
			help_text
			exit 0
			;;
		d)
			is_download=1
			;;
		H)
			scrape=history
			;;

		D)
			: > "$logfile"
			exit 0
			;;
		u)
			git -C "$(dirname "$(readlink -f "$0")")" pull
			;;
		-)
			case $OPTARG in
				dub)
					dub_prefix="-dub"
					;;
			esac
			;;
	esac
done
shift $((OPTIND - 1))

########
# main #
########

case $scrape in
	query)
		get_search_query "$*"
		search_results=$(search_anime "$query")
		[ -z "$search_results" ] && die "Sin resultados..."
		anime_selection "$search_results"
		episode_selection
		;;
	history)
		search_results=$(sed -n -E 's/\t[0-9]*//p' "$logfile")
		[ -z "$search_results" ] && die "Historial vacío"
		anime_selection "$search_results"
		ep_choice_start=$(sed -n -E "s/${selection_id}\t//p" "$logfile")
		;;
esac

check_input
append_history
open_selection

while :; do
	printf "${c_green}\nSi tienes problemas para reproducir el episodio:\n"
	printf "${c_magenta}1. Presiona [r] para intentar de reproducirlo nuevamente\n${c_blue}2. Presiona [t] para intentar conectar desde otro servidor."
	printf "\n${c_green}\nAhora mismo estás viendo: %s \nEpisodio ${c_cyan}%d/%d\n" "$selection_id" $episode $last_ep_number
	if [ "$episode" -ne "$last_ep_number" ]; then
		printf "\n$c_blue[${c_cyan}%s$c_blue] $c_yellow%s$c_reset\n" "n" "Siguiente episodio"
	fi
	if [ "$episode" -ne "1" ]; then
		printf "$c_blue[${c_cyan}%s$c_blue] $c_magenta%s$c_reset\n" "p" "Anterior episodio"
	fi
	if [ "$last_ep_number" -ne "1" ]; then
		printf "$c_blue[${c_cyan}%s$c_blue] $c_yellow%s$c_reset\n" "s" "Seleccionar episodio"
	fi
	printf "$c_blue[${c_cyan}%s$c_blue] $c_magenta%s$c_reset\n" "r" "Reproducir de nuevo"
	printf "$c_blue[${c_cyan}%s$c_blue] $c_blue%s$c_reset\n" "t" "Intentar en otro servidor"
	printf "$c_blue[${c_cyan}%s$c_blue] $c_cyan%s$c_reset\n" "a" "Buscar otro anime"
	printf "$c_blue[${c_cyan}%s$c_blue] $c_red%s$c_reset\n" "q" "Salir"
	printf "\n${c_blue}Elige una opción:${c_green} "
	read choice
	printf "$c_reset"
	case $choice in
		n)
			episode=$((episode + 1))
			;;
		p)
			episode=$((episode - 1))
			;;

		s)	printf "${c_blue}Elige episodio $c_cyan[1-%d]$c_reset:$c_green " $last_ep_number
			read episode
			printf "$c_reset"
			[ "$episode" -eq "$episode" ] 2>/dev/null || die "Número inválido, ingresa un número válido."
			;;

		r)
			episode=$((episode))
			;;
		t)
			episode=$((episode))
			[$mp4upload] && okru=true
			[!$mp4upload] && mp4upload=true
			;;
		a)
			tput reset
			get_search_query ""
			search_results=$(search_anime "$query")
			[ -z "$search_results" ] && die "Sin resultados..."
			anime_selection "$search_results"
			episode_selection
			check_input
			append_history
			open_selection
			continue
			;;
		q)
			break;;

		*)
			die "Opción inválida, ingresa una opción válida."
			;;
	esac

	open_episode "$selection_id" "$episode"
done
