# API anahtarları (repo’da saklanmaz)

## Google Maps / Places API

Bu anahtar **yakındaki camiler** haritası ve rota için kullanılır. Repo’da **saklanmaz**; yerel ve CI’da aşağıdaki yöntemlerle verilir.

### Önemli (anahtar açığa çıktıysa)

GitHub’da veya başka yerde anahtar açığa çıktıysa:

1. [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services** → **Credentials**
2. İlgili API anahtarını **silin** veya **yeniden oluşturun**
3. Yeni anahtarı aşağıdaki gibi yalnızca yerel/CI ortamında kullanın

### Yerel geliştirme

**Android (Maps SDK):**  
`android/local.properties` dosyasına ekleyin (bu dosya git’e alınmaz):

```properties
google.maps.api_key=YOUR_GOOGLE_API_KEY
```

**Dart (Places / Directions API):**  
Çalıştırırken anahtarı verin:

```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_API_KEY
```

VS Code / Cursor’da `launch.json` örneği:

```json
"args": ["--dart-define=GOOGLE_MAPS_API_KEY=YOUR_GOOGLE_API_KEY"]
```

### CI (GitHub Actions)

- **Android build:** Workflow’ta `GOOGLE_MAPS_API_KEY` ortam değişkeni tanımlayın veya repo **Secrets**’ta tutup job’da `env` ile verin.
- **iOS build:** Sadece IPA imzası için Google anahtarı gerekmez; harita özelliği uygulama içinde `String.fromEnvironment` ile alır, TestFlight/development build’te anahtar yoksa harita boş kalır.
