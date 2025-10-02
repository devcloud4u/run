#!/bin/sh

# OpenWRT ZeroTier Otomatik Kurulum Scripti
# Kullanım: curl -sL https://raw.githubusercontent.com/devcloud4u/run/refs/heads/main/zt-install.sh | sh

set -e

echo "======================================"
echo "  OpenWRT ZeroTier Kurulum Scripti"
echo "======================================"
echo ""

# 1. ZeroTier Network ID al
echo "🔹 Adım 1: ZeroTier Network ID"
printf "ZeroTier Network ID girin: "
read NETWORK_ID

if [ -z "$NETWORK_ID" ]; then
    echo "❌ Network ID boş olamaz!"
    exit 1
fi

# 2. Interface alias (profil) seçimi
echo ""
echo "🔹 Adım 2: Profil Seçimi"
echo "1) cstmrs   (Müşteriler)"
echo "2) sdwan    (SD-WAN)"
echo "3) datacenters (Veri Merkezleri)"
printf "Seçiminiz (1-3): "
read CHOICE

case $CHOICE in
    1) ALIAS="cstmrs" ;;
    2) ALIAS="sdwan" ;;
    3) ALIAS="datacenters" ;;
    *)
        echo "❌ Geçersiz seçim!"
        exit 1
        ;;
esac

ZONE_NAME="zt_${ALIAS}"
echo "✅ Profil seçildi: $ZONE_NAME"
echo ""

# 3. ZeroTier kurulumu
echo "🔹 Adım 3: ZeroTier Kurulumu"
echo "⏳ Paket listesi güncelleniyor..."
opkg update > /dev/null 2>&1

echo "⏳ ZeroTier kuruluyor..."
opkg install zerotier > /dev/null 2>&1

# 4. ZeroTier yapılandırması
echo ""
echo "🔹 Adım 4: ZeroTier Yapılandırması"
uci set zerotier.global.enabled='1'
uci delete zerotier.earth 2>/dev/null || true
uci set zerotier.${ZONE_NAME}='network'
uci set zerotier.${ZONE_NAME}.id="$NETWORK_ID"
uci set zerotier.${ZONE_NAME}.allow_managed='1'
uci set zerotier.${ZONE_NAME}.allow_global='0'
uci set zerotier.${ZONE_NAME}.allow_default='0'
uci set zerotier.${ZONE_NAME}.allow_dns='0'
uci commit zerotier

echo "✅ ZeroTier yapılandırıldı"
echo "⏳ ZeroTier servisi başlatılıyor..."
service zerotier restart
sleep 2

# 5. Firewall zone oluştur
echo ""
echo "🔹 Adım 5: Firewall Zone Oluşturma"
uci delete firewall.${ZONE_NAME} 2>/dev/null || true
uci set firewall.${ZONE_NAME}=zone
uci set firewall.${ZONE_NAME}.name="$ZONE_NAME"
uci set firewall.${ZONE_NAME}.input='ACCEPT'
uci set firewall.${ZONE_NAME}.output='ACCEPT'
uci set firewall.${ZONE_NAME}.forward='ACCEPT'
uci set firewall.${ZONE_NAME}.masq='1'
uci set firewall.${ZONE_NAME}.network="$ZONE_NAME"

# Forwarding kuralları
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest="$ZONE_NAME"

uci add firewall forwarding
uci set firewall.@forwarding[-1].src="$ZONE_NAME"
uci set firewall.@forwarding[-1].dest='lan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src="$ZONE_NAME"
uci set firewall.@forwarding[-1].dest='wan'

uci commit firewall
/etc/init.d/firewall reload > /dev/null 2>&1

echo "✅ Firewall kuralları oluşturuldu"

# 6. Kullanıcıdan onay bekle - DÖNGÜ BAŞLANGICI
while true; do
    echo ""
    echo "======================================"
    echo "⚠️  ÖNEMLİ ADIM"
    echo "======================================"
    echo ""
    echo "Şimdi ZeroTier Controller'da aşağıdaki işlemleri yapın:"
    echo "1. Bu cihazı ONAYLAYIN (Authorize)"
    echo "2. Cihaza bir IP ADRESİ atayın"
    echo ""
    printf "İşlemi tamamladıktan sonra ENTER'a basın..."
    read dummy

    # 7. Interface bilgilerini al
    echo ""
    echo "🔹 Adım 6: Interface Yapılandırması"
    echo "⏳ ZeroTier yeniden başlatılıyor..."
    /etc/init.d/zerotier restart
    sleep 5

    # Interface adını al
    ZT_IFACE=$(zerotier-cli listnetworks | grep "$NETWORK_ID" | awk '{print $(NF-1)}')

    if [ -z "$ZT_IFACE" ]; then
        echo ""
        echo "❌ ZeroTier interface bulunamadı!"
        echo "⚠️  Lütfen ZeroTier Controller'da cihazın onaylandığından emin olun."
        echo ""
        printf "Tekrar denemek için ENTER'a basın (veya Ctrl+C ile çıkın)..."
        read dummy
        continue
    fi

    # IP adresini al
    ZT_IP=$(ip -o -f inet addr show "$ZT_IFACE" 2>/dev/null | awk '{print $4}')

    if [ -z "$ZT_IP" ]; then
        echo ""
        echo "❌ IP adresi alınamadı!"
        echo "⚠️  Lütfen ZeroTier Controller'da IP ataması yaptığınızdan emin olun."
        echo ""
        printf "Tekrar denemek için ENTER'a basın (veya Ctrl+C ile çıkın)..."
        read dummy
        continue
    fi

    # Her şey başarılı, döngüden çık
    echo "✅ Interface bilgileri alındı:"
    echo "   Network ID: $NETWORK_ID"
    echo "   Interface: $ZT_IFACE"
    echo "   IP Adresi: ${ZT_IP%/*}"
    break
done

# 8. Network interface oluştur
echo ""
echo "🔹 Adım 7: Network Interface Oluşturma"
uci set network.${ZONE_NAME}='interface'
uci set network.${ZONE_NAME}.ifname="$ZT_IFACE"
uci set network.${ZONE_NAME}.proto='static'
uci set network.${ZONE_NAME}.ipaddr="${ZT_IP%/*}"
uci set network.${ZONE_NAME}.netmask="255.248.0.0"

# Firewall zone'a interface ekle
uci add_list firewall.${ZONE_NAME}.network="${ZONE_NAME}"

uci commit network
uci commit firewall

echo "⏳ Network ve Firewall yeniden başlatılıyor..."
/etc/init.d/network reload > /dev/null 2>&1
/etc/init.d/firewall reload > /dev/null 2>&1
/etc/init.d/zerotier restart > /dev/null 2>&1

sleep 2

# 9. Tamamlandı
echo ""
echo "======================================"
echo "✅  KURULUM TAMAMLANDI!"
echo "======================================"
echo ""
echo "📋 Yapılandırma Özeti:"
echo "   Profil: $ZONE_NAME"
echo "   Network ID: $NETWORK_ID"
echo "   Interface: $ZT_IFACE"
echo "   IP Adresi: ${ZT_IP%/*}/13"
echo ""
echo "🔥 Firewall Zone: $ZONE_NAME (LAN, WAN ile routing aktif)"
echo ""
