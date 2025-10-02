# OpenWRT ZeroTier Otomatik Kurulum Scripti

OpenWRT tabanlı router'larda ZeroTier VPN'i tek komutla kurup yapılandıran otomatik bash scripti.

## 🚀 Hızlı Kurulum

**Yöntem 1: İndir ve Çalıştır (Önerilen)**

```bash
wget https://raw.githubusercontent.com/devcloud4u/run/refs/heads/main/zt-install.sh
chmod +x zt-install.sh
./zt-install.sh
```

**Yöntem 2: Tek Komut (Gelişmiş)**

```bash
curl -sL https://raw.githubusercontent.com/devcloud4u/run/refs/heads/main/zt-install.sh -o /tmp/zt-install.sh && sh /tmp/zt-install.sh
```

## ✨ Özellikler

- ✅ **Tek Komut Kurulum** - Tüm işlemler otomatik
- ✅ **Profil Desteği** - Müşteriler, SD-WAN, Datacenter profilleri
- ✅ **Akıllı Hata Yönetimi** - Hata durumunda otomatik tekrar deneme
- ✅ **Firewall Otomasyonu** - Zone ve forwarding kuralları otomatik oluşturulur
- ✅ **Kullanıcı Dostu** - Adım adım yönlendirme

## 📋 Gereksinimler

- OpenWRT 19.07 veya üzeri
- İnternet bağlantısı
- ZeroTier Network ID
- ZeroTier Controller erişimi

## 🎯 Kurulum Adımları

### 1. Scripti İndirin ve Çalıştırın

```bash
wget https://raw.githubusercontent.com/devcloud4u/run/refs/heads/main/zt-install.sh
chmod +x zt-install.sh
./zt-install.sh
```

### 2. Network ID Girin

Script sizden ZeroTier Network ID'nizi isteyecek:

```
ZeroTier Network ID girin: 1234567890abcdef
```

### 3. Profil Seçin

Kullanım amacınıza göre bir profil seçin:

```
1) cstmrs      (Müşteriler)
2) sdwan       (SD-WAN)
3) datacenters (Veri Merkezleri)
Seçiminiz (1-3): 2
```

### 4. ZeroTier Controller'da Onaylayın

Script otomatik kurulumu tamamladıktan sonra bekleyecek:

1. [ZeroTier Central](https://my.zerotier.com)'a giriş yapın
2. Network'ünüzü açın
3. Yeni cihazı **Authorize** edin
4. Cihaza bir **IP adresi** atayın
5. Terminal'e dönüp **ENTER** basın

### 5. Tamamlandı! 🎉

Script otomatik olarak:
- Interface'i oluşturacak
- Firewall kurallarını ekleyecek
- Servisleri yeniden başlatacak

## 🔧 Ne Yapar?

Script aşağıdaki işlemleri otomatik olarak gerçekleştirir:

1. **Paket Kurulumu**
   - `opkg update` çalıştırır
   - ZeroTier paketini kurar

2. **ZeroTier Yapılandırması**
   - Network ID'yi ekler
   - Managed IP'leri etkinleştirir
   - Global routes'u devre dışı bırakır

3. **Firewall Zone Oluşturma**
   - Yeni firewall zone oluşturur (örn: `zt_sdwan`)
   - LAN ↔ ZeroTier forwarding
   - ZeroTier ↔ WAN forwarding
   - Masquerading aktif

4. **Network Interface**
   - Static IP yapılandırması
   - `/13` netmask (255.248.0.0)
   - Firewall zone'a bağlama

## 📁 Oluşturulan Yapılandırma

### UCI Yapılandırması

**ZeroTier** (`/etc/config/zerotier`):
```
config network 'zt_sdwan'
    option id '1234567890abcdef'
    option allow_managed '1'
    option allow_global '0'
    option allow_default '0'
    option allow_dns '0'
```

**Network** (`/etc/config/network`):
```
config interface 'zt_sdwan'
    option ifname 'ztxxxxxxxxx'
    option proto 'static'
    option ipaddr '10.147.20.5'
    option netmask '255.248.0.0'
```

**Firewall** (`/etc/config/firewall`):
```
config zone
    option name 'zt_sdwan'
    option input 'ACCEPT'
    option output 'ACCEPT'
    option forward 'ACCEPT'
    option masq '1'
    list network 'zt_sdwan'

config forwarding
    option src 'lan'
    option dest 'zt_sdwan'

config forwarding
    option src 'zt_sdwan'
    option dest 'lan'

config forwarding
    option src 'zt_sdwan'
    option dest 'wan'
```

## 🔄 Hata Durumunda

Script, ZeroTier interface veya IP bulunamazsa otomatik olarak size geri dönecektir:

```
❌ ZeroTier interface bulunamadı!
⚠️  Lütfen ZeroTier Controller'da cihazın onaylandığından emin olun.

Tekrar denemek için ENTER'a basın (veya Ctrl+C ile çıkın)...
```

İşlemi tamamlayıp ENTER'a bastığınızda script tekrar kontrol edecektir.

## 🛠️ Manuel Silme

Kurulumu geri almak için:

```bash
# ZeroTier paketini kaldır
opkg remove zerotier

# UCI yapılandırmalarını temizle
uci delete network.zt_sdwan
uci delete firewall.zt_sdwan
uci delete zerotier.zt_sdwan

# Forwarding kurallarını manuel silin (LuCI veya UCI ile)
uci commit
/etc/init.d/network reload
/etc/init.d/firewall reload
```

## 📊 Profil Karşılaştırması

| Profil | Zone Adı | Kullanım Amacı |
|--------|----------|----------------|
| **cstmrs** | `zt_cstmrs` | Müşteri ağları için |
| **sdwan** | `zt_sdwan` | SD-WAN bağlantıları için |
| **datacenters** | `zt_datacenters` | Veri merkezi bağlantıları için |

## 🐛 Sorun Giderme

### Interface Bulunamıyor

```bash
# ZeroTier servisini kontrol edin
service zerotier status

# Network listesini görüntüleyin
zerotier-cli listnetworks

# Elle network ekleyin
zerotier-cli join NETWORK_ID
```

### IP Alınamıyor

1. ZeroTier Central'da cihazın **Authorized** olduğundan emin olun
2. IP ataması yapıldığından emin olun
3. `zerotier-cli listnetworks` ile durumu kontrol edin

### Firewall Sorunu

```bash
# Firewall kurallarını kontrol edin
uci show firewall | grep zt_

# Firewall'ı yeniden başlatın
/etc/init.d/firewall restart
```

## 🔒 Güvenlik Notları

- Script, ZeroTier'ı `allow_global='0'` ile yapılandırır (güvenlik için)
- `allow_default='0'` - ZeroTier varsayılan route'u ele geçirmez
- Masquerading aktif olduğundan NAT çalışır
- Firewall zone'lar ACCEPT modunda - gerekirse kısıtlayın

## 📝 Lisans

MIT License - İsterseniz değiştirip kullanabilirsiniz.

## 🤝 Katkıda Bulunma

1. Fork edin
2. Feature branch oluşturun (`git checkout -b feature/AmazingFeature`)
3. Commit edin (`git commit -m 'Add some AmazingFeature'`)
4. Push edin (`git push origin feature/AmazingFeature`)
5. Pull Request açın

## 📧 İletişim

Sorularınız için GitHub Issues kullanın.

## 🌟 Yıldız Vermeyi Unutmayın!

Bu script işinize yaradıysa ⭐ vermeyi unutmayın!

---

**Not:** Script OpenWRT 21.02, 22.03 ve 23.05 sürümlerinde test edilmiştir.
