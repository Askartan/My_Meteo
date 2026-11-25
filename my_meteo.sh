#!/bin/bash

CITY=$2
CACHE_DIR="$HOME/.cache/mymeteo"
STATIONS_DB="$CACHE_DIR/NomatimStationsDB.json" # tu są koordynaty stacji wzięte z nomatima
CITIES_DB="$CACHE_DIR/IMGWStationsDB.json" # tu są miasta wzięte z IMGW
USER="projekt (contact: franekgrzywa@gmail.com)"

R='\033[0;31m'   # red
G='\033[0;32m'   # green
Y='\033[0;33m'   # yellow
B='\033[0;34m'   # blyue
C='\033[0;36m'   # cyan
NC='\033[0m'     # reset

# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


getCityCoords() {
    local fcity=$(echo "$1" | tr 'A-Z' 'a-z' | iconv -f UTF-8 -t ASCII//TRANSLIT)
    local cachePath="$CACHE_DIR/cities/$fcity.json"

    if $DEBUG; then (echo -n "Lokalizowanie miasta $fcity... "); fi
    if $DEBUG; then sleep 1; fi

    if [ ! -f "$cachePath" ]; then
        sleep 1.1
        curl -s -A "$USER" "https://nominatim.openstreetmap.org/search?city=${fcity// /%20}&countrycodes=pl&format=json" | jq '.[0]' > "$cachePath"
    fi
    
    CityLat=$(jq -r '.lat // empty' "$cachePath")
    CityLon=$(jq -r '.lon // empty' "$cachePath")
    
    if [ -z "$CityLat" ]; then 
        rm "$cachePath"
        echo "Błąd: Nie znaleziono miejscowości $1"
        exit 1
    fi
    if $DEBUG; then (echo  "OK"); fi
    if $DEBUG; then sleep 1; fi
}

getDistance() {
    echo "scale=6; sqrt(($1 - $3)^2 + ($2 - $4)^2)" | bc
}

getStations() {

    if $DEBUG; then (echo -n "Czy baza danych ze stacjami imgw jest ok... "); fi
    if $DEBUG; then sleep 1; fi

    # jeśli plik nie istnieje to go tworzy
    if [ ! -f "$CITIES_DB" ]; then
        local all_stations=$(curl -s "https://danepubliczne.imgw.pl/api/data/synop")
        sleep 1
        echo "$all_stations" > "$CITIES_DB"

        if $DEBUG; then (echo "Brak, stworzono nową"); fi
        if $DEBUG; then sleep 1; fi
    else 

    # jeśli plik istnieje, to sprawdza czy godzina jest aktualna lub czy plik był edytowany od godziny
        local gadzina
        if [ -f "$CITIES_DB" ]; then
            gadzina=$(cat "$CITIES_DB" | jq -r '.[0].godzina_pomiaru')
        fi

        local current_hour=$(date +%k | tr -d ' ')

        if [ -n "$(find "$CITIES_DB" -mmin +60)" ] || (( current_hour - gadzina > 1 )); then
            local all_stations=$(curl -s "https://danepubliczne.imgw.pl/api/data/synop")
            echo "$all_stations" > "$CITIES_DB"
            
            if $DEBUG; then (echo "Aktualizuję bazę danych... "); fi
            if $DEBUG; then sleep 1; fi

        else

            if $DEBUG; then (echo "OK"); fi
            if $DEBUG; then sleep 1; fi

        fi

        if $DEBUG; then (echo "Teraźniejsza godzina = $current_hour"); fi
        if $DEBUG; then sleep 1; fi
        if $DEBUG; then (echo "Aktualna godzina w bazie danych = $gadzina "); fi
        if $DEBUG; then sleep 1; fi
    fi

    if $DEBUG; then (echo -n "Sprawdzam bazę danych ze stacjami (nominatim)... "); fi
    if $DEBUG; then sleep 1; fi
    if [ ! -f "$STATIONS_DB" ]; then
        echo "[]" > "$STATIONS_DB"
        if $DEBUG; then (echo "Brak, generuję nową... "); fi

        OLDIFS=$IFS
        IFS=$'\n'
        cities=$(jq -c '.[]' "$CITIES_DB")
        for row in "cities"; do
            local name=$(echo "$row" | jq -r '.stacja')
            local id=$(echo "$row" | jq -r '.id_stacji')
            
            local fname=$(echo "$name" | tr 'A-Z' 'a-z' | iconv -f UTF-8 -t ASCII//TRANSLIT)

            if $DEBUG; then echo -n "Lokalizowanie: $name... "; fi
            
            local coords=$(curl -s -A "$USER" "https://nominatim.openstreetmap.org/search?city=${fname// /%20}&countrycodes=pl&format=json")

            local lat=$(echo "$coords" | jq -r '.[0].lat // empty')
            local lon=$(echo "$coords" | jq -r '.[0].lon // empty')

            if [[ -n "$lat" && -n "$lon" ]]; then
                jq ". += [{ \"id\":\"$id\", \"name\":\"$name\", \"lat\":$lat, \"lon\":$lon}]" "$STATIONS_DB" > "${STATIONS_DB}.tmp" && mv "${STATIONS_DB}.tmp" "$STATIONS_DB"
                if $DEBUG; then echo "OK"; fi
            else
                if $DEBUG; then echo "ERROR"; fi
            fi

            sleep 1.1
        done
        IFS=$OLDIFS
        
    fi
    if $DEBUG; then (echo "OK"); fi
    if $DEBUG; then sleep 1; fi
}


# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


helpFunc() {
    cat << EOF
Użycie: $0 --city "Nazwa Miasta" [Opcje]

Program pobiera aktualne dane pogodowe z najbliższej stacji synoptycznej IMGW
dla podanej lokalizacji. 

Opcje:
  --city "Miasto"    Określa miasto, dla którego szukamy pogody (wymagane).
  --pobierz, -p      Pobiera niezbędne funkcje.
  --debug, -d        Wyświetla o wiele więcej informacji, pomaga przy problemach.
  --colors, -c       Kolorki :DDD
  --reset, -r        Usuwa pamięć cache przed działaniem programu.

Opcje dodatkowe:
  --help, -h         Wyświetla ten tekst pomocy.
  --info, -i         Wyświetla schemat działania programu.

Przykład:
  $0 --city "Poznań"
  $0 --help
  $0 -i
  $0 --city wachock --colors -d -r

Autor Skryptu: Franciszek Grzywa
EOF
}


infoFunc() {
    cat << EOF
1. Program najpierw sprawdza czy ma dane odnośnie miasta w pamięci cache.
2. Za pomocą Nominatim API program sprawdza czy szukane miejsce faktycznie istnieje.
3. Sprawdza czy dane odnośnie stacji są aktualne, jeśli nie to pobiera nowe.
4. Jeśli nie ma informacji odnośnie koordynatów miast ze stacjami, to generuje bazę danych (przez około minutę)
5. Oblicza odległości między wszystkimi stacjami a miastem, po czym wybiera najkrótszą.  
6. Program zwraca wyniki (pogoda z najbliższej stacji meteorologicznej) 
EOF
}

colors=false
for arg in "$@"; do
    if [[ "$arg" == "-c" ]] || [[ "$arg" == "--colors" ]]; then
        colors=true
    fi
done

for arg in "$@"; do
    if [[ "$arg" == "-r" ]] || [[ "$arg" == "--reset" ]]; then
        if [ -f "$STATIONS_DB" ]; then rm "$STATIONS_DB"; fi
        if [ -f "$CITIES_DB" ]; then rm "$CITIES_DB"; fi
        rm -rf "$CACHE_DIR/cities"
    fi
done

DEBUG=false
for arg in "$@"; do
    if [[ "$arg" == "-d" ]] || [[ "$arg" == "--debug" ]]; then
        DEBUG=true
    fi
done

if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    helpFunc
    exit 0
fi

if [[ "$1" == "--info" ]] || [[ "$1" == "-i" ]]; then
    infoFunc
    exit 0
fi

for arg in "$@"; do
    if [[ "$arg" == "-p" ]] || [[ "$arg" == "--pobierz" ]]; then
        apt install curl && apt install jq
    fi
done

if [ "$1" != "--city" ] || [ -z "$CITY" ]; then
    echo "Błąd: Użyj --city \"Nazwa Miasta\""
    exit 1
fi


# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

mkdir -p "$CACHE_DIR/cities"

getCityCoords "$CITY"
getStations

MinDistance=999999
ClosestID=""

OLDIFS=$IFS
IFS=$'\n'
stations=$(jq -c '.[]' "$STATIONS_DB")

if $DEBUG; then echo "---------------------------------------------------------------------------------------------------------------------------"; fi
for s in $stations; do

    StationID=$(echo "$s" | jq -r '.id')
    StationLat=$(echo "$s" | jq -r '.lat')
    StationLon=$(echo "$s" | jq -r '.lon')
    StationName=$(echo "$s" | jq -r '.name')

    dist=$(getDistance "$CityLat" "$CityLon" "$StationLat" "$StationLon")

    if $DEBUG; then 
        echo "Lat $CITY = $CityLat, Lon $CITY = $CityLon, Lat Stacji w $StationName = $StationLat, Lon Stacji w $StationName = $StationLon"
        echo "ODLEGŁOŚĆ $CITY OD $StationName = $dist"
    fi

    if (( $(echo "$dist < $MinDistance" | bc -l) )); then
        MinDistance=$dist
        ClosestID=$StationID
    fi
done
IFS=$OLDIFS
if $DEBUG; then echo "---------------------------------------------------------------------------------------------------------------------------"; fi

if [ -z "$ClosestID" ]; then
    echo "Nie udało się znaleźć żadnej stacji."
    exit 1
fi

W=$(jq -r --arg id "$ClosestID" '.[] | select(.id_stacji == $id)' "$CITIES_DB")

if ! $colors; then 
    echo "-------------------------------------"
    echo "Stacja: $(echo "$W" | jq -r '.stacja') [ID: $ClosestID]"
    echo "Data pomiaru: $(echo "$W" | jq -r '.data_pomiaru') o godz. $(echo "$W" | jq -r '.godzina_pomiaru'):00"
    echo "-------------------------------------"
    printf "Temperatura:            %7s °C\n" "$(echo "$W" | jq -r '.temperatura')"
    printf "Prędkość wiatru:        %7s m/s\n" "$(echo "$W" | jq -r '.predkosc_wiatru')"
    printf "Wilgotność względna:    %7s %%\n" "$(echo "$W" | jq -r '.wilgotnosc_wzgledna')"
    printf "Suma Opadów:            %7s mm\n" "$(echo "$W" | jq -r '.suma_opadu')"
    printf "Ciśnienie:              %7s hPa\n" "$(echo "$W" | jq -r '.cisnienie')"
    echo "-------------------------------------"
else
    echo -e "${B}-------------------------------------${NC}"
    echo -e "${G}Stacja: $(echo "$W" | jq -r '.stacja') [ID: $ClosestID]${NC}"
    echo -e "Data pomiaru: ${C}$(echo "$W" | jq -r '.data_pomiaru')${NC} o godz. ${C}$(echo "$W" | jq -r '.godzina_pomiaru'):00${NC}"
    echo -e "${B}-------------------------------------${NC}"
    printf "${R}Temperatura:            ${NC}%7s °C\n" "$(echo "$W" | jq -r '.temperatura')"
    printf "${R}Prędkość wiatru:        ${NC}%7s m/s\n" "$(echo "$W" | jq -r '.predkosc_wiatru')"
    printf "${R}Wilgotność względna:    ${NC}%7s %%\n" "$(echo "$W" | jq -r '.wilgotnosc_wzgledna')"
    printf "${R}Suma Opadów:            ${NC}%7s mm\n" "$(echo "$W" | jq -r '.suma_opadu')"
    printf "${R}Ciśnienie:              ${NC}%7s hPa\n" "$(echo "$W" | jq -r '.cisnienie')"
    echo -e "${B}-------------------------------------${NC}"
fi