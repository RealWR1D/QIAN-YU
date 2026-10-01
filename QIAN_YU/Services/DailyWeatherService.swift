import Foundation
import CoreLocation
import Observation

@MainActor @Observable final class DailyWeatherService: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = DailyWeatherService()
    var status = String(localized: "")
    var places: [CLPlacemark] = []
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var locationTimeout: Task<Void, Never>?
    private var forecasts: [String: String] = [:]
    private var forecastStamp: Date = .distantPast
    private var forecastLocation = ""

    override init() {
        super.init()
        forecasts = UserDefaults.standard.dictionary(forKey: "qianyu_weather_forecasts") as? [String: String] ?? [:]
        forecastStamp = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: "qianyu_weather_forecast_stamp"))
        forecastLocation = UserDefaults.standard.string(forKey: "qianyu_weather_forecast_location") ?? ""
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func search(city: String) async {
        status = String(localized: "正在查找城市与区…")
        do {
            places = try await CLGeocoder().geocodeAddressString(city)
            status = places.isEmpty ? "未找到地点，请补充省、市或区名。" : "请选择对应地点。"
        } catch { status = String(localized: "地点查询失败，请检查网络后重试。") }
    }

    func select(_ place: CLPlacemark) {
        guard let location = place.location else { return }
        let name = Self.name(place)
        AppSettings.shared.weatherCity = name
        AppSettings.shared.weatherUseLocation = false
        save(location: location, name: name, automatic: false)
        places = []
        status = String(localized: "已选择：\(name)")
        NotificationManager.shared.scheduleDailyNotifications()
    }

    static func name(_ place: CLPlacemark) -> String {
        let parts = [place.administrativeArea, place.locality, place.subAdministrativeArea, place.subLocality].compactMap { $0 }
        var unique: [String] = []
        for part in parts where !unique.contains(part) { unique.append(part) }
        return unique.isEmpty ? String(localized: "当前位置") : unique.joined(separator: " ")
    }

    func useCurrentLocation() async {
        guard locationContinuation == nil else { return }
        status = String(localized: "正在获取当前位置…")
        do {
            let location: CLLocation = try await withCheckedThrowingContinuation { continuation in
                locationContinuation = continuation
                locationTimeout = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(20))
                    guard !Task.isCancelled else { return }
                    finishLocation(.failure(CLError(.locationUnknown)))
                }
                switch manager.authorizationStatus {
                case .notDetermined: manager.requestWhenInUseAuthorization()
                case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
                default: finishLocation(.failure(CLError(.denied)))
                }
            }
            let place = try? await CLGeocoder().reverseGeocodeLocation(location).first
            let name = place.map(Self.name) ?? "当前位置"
            AppSettings.shared.weatherUseLocation = true
            save(location: location, name: name, automatic: true)
            status = String(localized: "已使用：\(name)")
            NotificationManager.shared.scheduleDailyNotifications()
        } catch {
            AppSettings.shared.weatherUseLocation = false
            status = String(localized: "定位不可用，继续使用常用城市。可在系统设置中允许定位，或手动选择城市与区。")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locationContinuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: finishLocation(.failure(CLError(.denied)))
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { finishLocation(.failure(CLError(.locationUnknown))); return }
        finishLocation(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finishLocation(.failure(error)) }

    private func finishLocation(_ result: Result<CLLocation, Error>) {
        let continuation = locationContinuation
        locationContinuation = nil
        locationTimeout?.cancel()
        locationTimeout = nil
        continuation?.resume(with: result)
    }

    private func save(location: CLLocation, name: String, automatic: Bool) {
        let prefix = automatic ? "qianyu_weather_auto" : "qianyu_weather_manual"
        UserDefaults.standard.set(location.coordinate.latitude, forKey: prefix + "_lat")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: prefix + "_lon")
        UserDefaults.standard.set(name, forKey: prefix + "_name")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: prefix + "_stamp")
        forecastStamp = .distantPast
    }

    private var locationAuthorized: Bool {
        #if os(macOS)
        return manager.authorizationStatus == .authorizedAlways
        #else
        return manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
        #endif
    }

    var cachedForecast: [String: String] {
        let settings = AppSettings.shared
        let defaults = UserDefaults.standard
        let authorized = locationAuthorized
        let automatic = settings.weatherUseLocation && authorized
            && Date().timeIntervalSince1970 - defaults.double(forKey: "qianyu_weather_auto_stamp") < 86400
        let city = automatic ? (defaults.string(forKey: "qianyu_weather_auto_name") ?? "当前位置") : settings.weatherCity
        guard city == forecastLocation, Date().timeIntervalSince(forecastStamp) < 3 * 3600 else { return [:] }
        return forecasts
    }

    func forecast() async -> [String: String] {
        let settings = AppSettings.shared
        let defaults = UserDefaults.standard
        let authorized = locationAuthorized
        let automatic = settings.weatherUseLocation && authorized
            && Date().timeIntervalSince1970 - defaults.double(forKey: "qianyu_weather_auto_stamp") < 86400
        let prefix = automatic ? "qianyu_weather_auto" : "qianyu_weather_manual"
        let city = automatic ? (defaults.string(forKey: prefix + "_name") ?? "当前位置") : settings.weatherCity
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [:] }
        if city == forecastLocation, Date().timeIntervalSince(forecastStamp) < 3 * 3600 { return forecasts }
        do {
            let coordinate: CLLocationCoordinate2D
            if defaults.string(forKey: prefix + "_name") == city,
               defaults.object(forKey: prefix + "_lat") != nil {
                coordinate = .init(latitude: defaults.double(forKey: prefix + "_lat"), longitude: defaults.double(forKey: prefix + "_lon"))
            } else {
                guard let location = try await CLGeocoder().geocodeAddressString(city).first?.location else { return [:] }
                coordinate = location.coordinate
                save(location: location, name: city, automatic: false)
            }
            guard CLLocationCoordinate2DIsValid(coordinate) else { return [:] }
            var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
            url.queryItems = [URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
                URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
                URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
                URLQueryItem(name: "timezone", value: TimeZone.current.identifier),
                URLQueryItem(name: "forecast_days", value: "7")]
            var request = URLRequest(url: url.url!)
            request.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [:] }
            let decoded = try JSONDecoder().decode(Forecast.self, from: data)
            let daily = decoded.daily
            var result: [String: String] = [:]
            for index in daily.time.indices {
                guard index < daily.weather_code.count, index < daily.temperature_2m_max.count,
                      index < daily.temperature_2m_min.count, index < daily.precipitation_probability_max.count,
                      let high = daily.temperature_2m_max[index], let low = daily.temperature_2m_min[index],
                      let code = daily.weather_code[index], high.isFinite, low.isFinite,
                      (-100...80).contains(high), (-100...80).contains(low), low <= high else { continue }
                let rain = daily.precipitation_probability_max[index].map { "，降水概率最高 \($0)%" } ?? ""
                result[daily.time[index]] = "\(city) \(daily.time[index]) 天气预报：\(Self.condition(code))，\(Int(low.rounded()))–\(Int(high.rounded()))℃\(rain)。来源 Open-Meteo，获取于 \(Date().formatted())。"
            }
            forecasts = result
            forecastLocation = city
            forecastStamp = Date()
            defaults.set(result, forKey: "qianyu_weather_forecasts")
            defaults.set(forecastStamp.timeIntervalSince1970, forKey: "qianyu_weather_forecast_stamp")
            defaults.set(city, forKey: "qianyu_weather_forecast_location")
            return result
        } catch { return [:] }
    }

    private struct Forecast: Decodable {
        struct Daily: Decodable {
            let time: [String]
            let weather_code: [Int?]
            let temperature_2m_max: [Double?]
            let temperature_2m_min: [Double?]
            let precipitation_probability_max: [Int?]
        }
        let daily: Daily
    }
    private static func condition(_ code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1...3: return "晴间多云或阴"
        case 45, 48: return "雾"
        case 51...67, 80...82: return "雨"
        case 71...77, 85, 86: return "雪"
        case 95...99: return "雷雨"
        default: return "天气状况不明"
        }
    }
}
