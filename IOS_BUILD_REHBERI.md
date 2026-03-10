# iPhone’da Nida Uygulamasını Görme Rehberi (Windows + GitHub Ücretsiz)

Bu rehber, **Windows 11** bilgisayarınızda Mac olmadan, **GitHub’ın ücretsiz macOS runner’ları** ile iOS derlemesi yapıp, **Apple Developer hesabınız** ve **iPhone 14** ile uygulamayı telefonunuzda nasıl göreceğinizi adım adım anlatır.

---

## Genel Akış

1. Projeyi **GitHub**’a push edersiniz.
2. **GitHub Actions** macOS’ta projeyi derleyip **IPA** dosyası üretir.
3. IPA’yı ya **artifact** olarak indirip (AltStore ile) telefona yüklersiniz ya da **TestFlight**’a yükleyip iPhone’dan TestFlight ile kurarsınız.

**iPhone USB ile bilgisayara bağlı** olsa da, kurulumu yine GitHub/TestFlight veya AltStore üzerinden yapacağız; Windows’tan doğrudan Xcode ile yükleme yapılamaz.

---

## Seçenek A: TestFlight ile (Önerilen)

En pratik yol: IPA’yı GitHub Actions’ta **App Store Connect’e (TestFlight)** yükleyip, iPhone’da **TestFlight** uygulamasından kurmak.

### 1. Apple Developer Portal’da Hazırlık

- [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles**.
- **App ID**: `com.nida.nidaFlutter` için bir App ID oluşturun (yoksa).
- **Distribution Certificate**: Bir **Apple Distribution** sertifikası oluşturup indirin, Mac’te veya Windows’ta OpenSSL ile **.p12**’ye çevirin (şifre belirleyin).
- **Provisioning Profile**: **Distribution → App Store** tipinde, bu App ID ve sertifikanızı kullanan bir profil oluşturup indirin (`.mobileprovision`). Bu profil adını `PROVISIONING_PROFILE_NAME` secret’ında kullanacaksınız; TestFlight build’inde workflow’u çalıştırırken “Build for TestFlight” seçeneğini işaretleyin.
- **App Store Connect**: [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **My Apps** → **+** ile yeni uygulama ekleyin (bundle ID: `com.nida.nidaFlutter`).

### 2. GitHub Repository Secrets

Reponuzda: **Settings → Secrets and variables → Actions → New repository secret** ile aşağıdakileri ekleyin:

| Secret adı | Açıklama |
|-------------|----------|
| `BUILD_CERTIFICATE_BASE64` | .p12 dosyasının Base64 hali (aşağıda nasıl alınır) |
| `P12_PASSWORD` | .p12’ye verdiğiniz şifre |
| `KEYCHAIN_PASSWORD` | Rastgele bir şifre (örn. `keychain123`) |
| `BUILD_PROVISION_PROFILE_BASE64` | .mobileprovision dosyasının Base64 hali |
| `APPLE_TEAM_ID` | Apple Developer’daki Team ID (ör. `ABCD1234`) |
| `PROVISIONING_PROFILE_NAME` | Profil adı (portalda görünen tam isim) |

**Base64 nasıl alınır (Windows PowerShell):**

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\yol\sertifika.p12")) | Set-Clipboard
```

`.mobileprovision` için aynı komutu dosya yoluyla tekrarlayın; çıkan metni ilgili secret’a yapıştırın.

### 3. Workflow’a TestFlight Yükleme (İsteğe Bağlı)

Şu an workflow sadece **IPA’yı artifact** olarak üretiyor. TestFlight’a otomatik yüklemek için workflow’a bir adım ekleyebilirsiniz; bunun için **App Store Connect API Key** (issuer ID, key ID, .p8 dosyası) gerekir. İsterseniz bir sonraki adımda bu adımı ekleyebilirim; şimdilik IPA’yı indirip **Transporter** (Windows’ta Microsoft Store’dan) ile App Store Connect’e yükleyebilirsiniz.

### 4. TestFlight için Workflow’u Çalıştırma

- **Actions** → **Build iOS (IPA)** → **Run workflow**.
- **Build for TestFlight** (veya “TestFlight için build”) kutusunu **işaretleyin**; böylece `app-store` dağıtım profili ile derlenir.
- Run workflow’u başlatın; bittiğinde **Artifacts**’tan **ios-ipa**’yı indirin.

### 5. IPA’yı TestFlight’a Yükleme (Manuel)

- GitHub’da **Actions** → en son **Build iOS (IPA)** run’ını açın.
- **Artifacts** bölümünden **ios-ipa**’yı indirin (zip içinde .ipa olacak).
- Windows’ta **Transporter** uygulamasını açın, Apple ID ile giriş yapın, IPA’yı sürükleyip yükleyin.
- App Store Connect’te uygulama sayfasında **TestFlight** sekmesinde build görününce, kendinizi **Internal Tester** olarak ekleyin.
- iPhone’da **TestFlight** uygulamasını indirip Apple ID ile giriş yapın; Nida build’i listede çıkar, **Install** deyin.

Bu sayede **parasını verdiğiniz Apple Developer hesabınız** ve **iPhone 14** ile uygulamayı **telefonunuzda** görebilirsiniz.

---

## Seçenek B: Geliştirme Profili + AltStore (USB ile Kurulum)

Gerçek cihaza **development** veya **ad-hoc** profil ile kurup, Windows’ta **AltStore** ile USB’den yüklemek mümkün.

### 1. Cihazı Portal’a Ekleme

- **developer.apple.com** → **Devices** → **+** → iPhone 14’ü seçip **UDID** girin.
- UDID’i bulmak: iPhone’u USB ile bilgisayara takın, **iTunes** veya **Apple Devices** (Windows 11) ile cihazı seçip seri numarasına tıklayın; UDID görünür (kopyalayın).

### 2. Development Sertifika ve Profil

- **Development** sertifikası oluşturup .p12’ye çevirin.
- **Development** provisioning profile oluşturun; App ID `com.nida.nidaFlutter`, sertifikanız ve **iPhone 14 cihazınız** seçili olsun. Profili indirin (.mobileprovision).

### 3. GitHub Secrets

Aynı tablodaki secret’ları kullanın; `PROVISIONING_PROFILE_NAME` bu sefer **development** profilinin adı olmalı. Workflow’daki `ExportOptions.plist` zaten `development` method kullanıyor.

### 4. Workflow’u Çalıştırma

- Kodu **main** veya **master**’a push edin veya **Actions** → **Build iOS (IPA)** → **Run workflow** ile manuel çalıştırın.
- Bittiğinde **Artifacts** → **ios-ipa**’yı indirin.

### 5. iPhone’a Kurulum (Windows + USB)

- [AltStore](https://altstore.io) sitesinden Windows sürümünü indirip kurun.
- iPhone’u USB ile bilgisayara bağlayın, güvenin.
- AltStore’da **Install** → indirdiğiniz **.ipa** dosyasını seçin; AltStore imzayı kendi Apple ID’nizle yeniler ve cihaza yükler (Apple Developer hesabınızla oluşturduğunuz development profilinin imzası kullanılmış olur).

Böylece **telefonunuz USB ile bilgisayara bağlıyken** bile kurulumu **GitHub’da üretilen IPA + AltStore** ile yapmış olursunuz.

---

## Özet Tablo

| Adım | Nerede | Ne yapıyorsunuz |
|------|--------|------------------|
| 1 | Apple Developer | App ID, sertifika (.p12), provisioning profile (.mobileprovision), (TestFlight için) App Store Connect’te uygulama |
| 2 | GitHub repo → Settings → Secrets | Base64 sertifika, profil, şifreler, TEAM_ID, PROFILE_NAME |
| 3 | GitHub | Push veya “Run workflow” ile **Build iOS (IPA)** çalışır |
| 4 | GitHub Actions → Artifacts | **ios-ipa** indirilir |
| 5a | TestFlight | IPA’yı Transporter ile yükleyip iPhone’da TestFlight’tan kurarsınız |
| 5b | AltStore | IPA’yı AltStore ile USB’den iPhone’a yüklersiniz |

---

## Sık Karşılaşılan Sorunlar

- **“BUILD_CERTIFICATE_BASE64 secret tanımlı değil”**: Sertifika veya profil secret’ları eklenmemiş; yukarıdaki tabloya göre hepsini ekleyin.
- **IPA oluşmadı / imza hatası**: Team ID ve provisioning profile adının (PROVISIONING_PROFILE_NAME) Apple Developer’daki ile birebir aynı olduğundan emin olun; method’un `development` veya dağıtım tipinize uygun olduğunu kontrol edin.
- **TestFlight’ta görünmüyor**: Transporter’da yükleme tamamlandıktan sonra birkaç dakika bekleyin; e-postanızı ve App Store Connect’teki TestFlight sekmesini kontrol edin.

Bu akışla **Mac kullanmadan**, **Windows 11** ve **GitHub’ın ücretsiz macOS runner’ı** ile, **ücretli Apple Developer hesabınız** ve **iPhone 14** ile uygulamayı telefonunuzda ücretsiz şekilde görebilirsiniz. Telefon USB’de olsa da kurulum TestFlight veya AltStore üzerinden yapılır.
