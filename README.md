
# MyMeteo

A command-line application written in Bash that retrieves current weather data for a given city in Poland. It finds the nearest synoptic station based on geographic coordinates and displays its latest measurements.

## Requirements

- Linux: Bash, curl, 

## Usage

    chmod +x my_meteo.sh
    ./my_meteo.sh --city "Poznań"

## Example

    $ ./my_meteo.sh --city "Kórnik"

    Poznań [12330] / 2024-09-26 09:27

    Temperature:       14.7 °C
    Wind speed:         5.0 m/s
    Wind direction:   300.0 °
    Relative humidity: 94.9 %
    Precipitation:      0.4 mm
    Pressure:        1006.4 hPa

## Technologies and Data Sources

- Bash – Linux implementation.
- Nominatim API – retrieves geographic coordinates of cities.
- IMGW-PIB API – provides weather data from synoptic stations.
- curl – sends HTTP requests.
- jq – parses JSON responses (Bash).

The application calculates distances between the requested city and available weather stations to identify the nearest one.
