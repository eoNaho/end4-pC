pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root

    // 10 minute
    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: debounceTimer.restart()
    onCityChanged: debounceTimer.restart()

    // Debounce: wait 800ms after the last change before fetching,
    // so typing a city name letter-by-letter doesn't spam the API.
    Timer {
        id: debounceTimer
        interval: 800
        repeat: false
        onTriggered: root.getData()
    }

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: "",
        wind: "",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        lastRefresh: ""
    })

    function refineData(data) {
        let temp = {}
        const rainMm = data?.rain?.["1h"] || data?.rain?.["3h"] || 0
        const snowMm = data?.snow?.["1h"] || data?.snow?.["3h"] || 0

        temp.description = data?.weather?.[0]?.description || ""
        temp.cr = data?.clouds?.all !== undefined
            ? Math.round(data.clouds.all * 0.8) + "%"
            : "0%"
        temp.humidity = (data?.main?.humidity || 0) + "%"

        const fmt = (unix) => new Date(unix * 1000).toLocaleTimeString("en-US", {
            hour: "numeric",
            minute: "2-digit",
            second: "2-digit",
            hour12: true
        })

        temp.sunrise = data?.sys?.sunrise ? fmt(data.sys.sunrise) : "0"
        temp.sunset  = data?.sys?.sunset  ? fmt(data.sys.sunset)  : "0"

        temp.windDir = data?.wind?.deg || 0
        temp.wCode = data?.weather?.[0]?.id || 0
        temp.city = data?.name || "City"

        if (root.useUSCS) {
            temp.wind = (data?.wind?.speed || 0) + " mph"
            temp.precip = ((rainMm + snowMm) * 0.0394).toFixed(2) + " in"
            temp.visib = ((data?.visibility || 0) / 1609).toFixed(1) + " mi"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            temp.temp = Math.round(data?.main?.temp || 0) + "°F"
            temp.tempFeelsLike = Math.round(data?.main?.feels_like || 0) + "°F"
        } else {
            temp.wind = (data?.wind?.speed || 0) + " m/s"
            temp.precip = (rainMm + snowMm).toFixed(1) + " mm"
            temp.visib = ((data?.visibility || 0) / 1000).toFixed(1) + " km"
            temp.press = (data?.main?.pressure || 0) + " hPa"
            let roundedTemp = Math.round(data?.main?.temp || 0)
            let roundedFeels = Math.round(data?.main?.feels_like || 0)

            temp.temp = roundedTemp + "°C"
            temp.tempFeelsLike = roundedFeels + "°C"
        }

        temp.lastRefresh = DateTime.time + " • " + DateTime.date

        // Store coordinates returned by the API to use for UV index fetch
        if (data?.coord?.lat !== undefined && data?.coord?.lon !== undefined) {
            root.location.lat = data.coord.lat
            root.location.lon = data.coord.lon
            root.location.valid = true
        }

        // Keep previous UV until fresh data arrives
        temp.uv = root.data.uv ?? 0

        root.data = temp

        // Fetch UV index using the coordinates we now have
        if (root.location.valid) {
            root.getUvData(root.location.lat, root.location.lon)
        }
    }

    function getData() {
        let apiKey = "8b05d62206f459e1d298cbe5844d7d87"

        if (apiKey === "") {
            console.error("[WeatherService] Missing OpenWeather API key.")
            return
        }

        let units = root.useUSCS ? "imperial" : "metric"
        let url = "https://api.openweathermap.org/data/2.5/weather?"

        if (root.gpsActive && root.location.valid) {
            url += `lat=${root.location.lat}&lon=${root.location.lon}`
        } else {
            url += `q=${formatCityName(root.city)}`
        }

        url += `&units=${units}`
        url += `&appid=${apiKey}`

        let command = `curl -s "${url}"`

        fetcher.command[2] = command
        fetcher.running = true
    }

    function getUvData(lat, lon) {
        let apiKey = "8b05d62206f459e1d298cbe5844d7d87"
        let url = `https://api.openweathermap.org/data/2.5/uvi?lat=${lat}&lon=${lon}&appid=${apiKey}`
        uvFetcher.command[2] = `curl -s "${url}"`
        uvFetcher.running = true
    }

    function formatCityName(cityName) {
        return cityName.trim().split(/\s+/).join('+')
    }

    Component.onCompleted: {
        if (!root.gpsActive) return
        console.info("[WeatherService] Starting GPS service.")
        positionSource.start()
    }

    Process {
        id: fetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0)
                    return

                try {
                    const parsedData = JSON.parse(text)

                    if (parsedData.cod && parsedData.cod !== 200) {
                        console.error("[WeatherService] API error:", parsedData.message)
                        return
                    }

                    root.refineData(parsedData)
                } catch (e) {
                    console.error("[WeatherService] JSON parse error:", e.message)
                }
            }
        }
    }

    // Fetches UV index from the free /uvi endpoint using lat/lon coordinates.
    // Called automatically after a successful weather fetch (which provides the coords).
    Process {
        id: uvFetcher
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return
                try {
                    const uvData = JSON.parse(text)
                    if (uvData.value !== undefined) {
                        let updated = Object.assign({}, root.data)
                        updated.uv = Math.round(uvData.value * 10) / 10
                        root.data = updated
                    }
                } catch (e) {
                    console.error("[WeatherService] UV JSON parse error:", e.message)
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude
                root.location.lon = position.coordinate.longitude
                root.location.valid = true
                root.getData()
            } else {
                root.gpsActive = root.location.valid
                console.error("[WeatherService] Failed to get GPS location.")
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop()
                root.location.valid = false
                root.gpsActive = false
                console.error("[WeatherService] Could not acquire valid GPS backend.")
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}