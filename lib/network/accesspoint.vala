public class AstalNetwork.AccessPoint : Object {
    private Wifi wifi;
    private NM.AccessPoint ap;

    private HashTable<string, ConnectionProfile> _profiles =
        new HashTable<string, ConnectionProfile>(str_hash, str_equal);

    public List<weak ConnectionProfile> profiles {
        owned get { return _profiles.get_values(); }
    }

    public uint bandwidth { get { return ap.bandwidth; } }
    public string bssid { owned get { return ap.bssid; } }
    public uint frequency { get { return ap.frequency; } }
    public int last_seen { get { return ap.last_seen; } }
    public uint max_bitrate { get { return ap.max_bitrate; } }
    public uint8 strength { get { return ap.strength; } }
    public string icon_name { get; private set; }
    public NM.80211Mode mode { get { return ap.mode; } }
    public NM.80211ApFlags flags { get { return ap.flags; } }
    public NM.80211ApSecurityFlags rsn_flags { get { return ap.rsn_flags; } }
    public NM.80211ApSecurityFlags wpa_flags { get { return ap.wpa_flags; } }
    public bool hidden { get { return ssid == "Unknown" || ssid == null; } }
    public bool requires_password { get { return wpa_flags != NM.80211ApSecurityFlags.NONE || rsn_flags != NM.80211ApSecurityFlags.NONE; } }
    public ConnectionProfile? active_profile { get; private set; }

    public string? ssid {
        owned get {
            if (ap.ssid == null)
                return null;

            return (string)NM.Utils.ssid_to_utf8(ap.ssid.get_data());
        }
    }

    internal AccessPoint(Wifi wifi, NM.AccessPoint ap) {
        this.wifi = wifi;
        this.ap = ap;

        ap.notify.connect((pspec) => {
            if (get_class().find_property(pspec.name) != null)
                notify_property(pspec.name);
            if (pspec.name == "strength")
                icon_name = _icon();
        });
        icon_name = _icon();
        _loadProfiles();
    }

    private void _loadProfiles() {
        foreach (var connection in ap.client.get_connections()) {
            var wireless_setting = connection.get_setting_wireless();
            if (wireless_setting != null) {
                var connection_ssid_data = wireless_setting.get_ssid();
                if (connection_ssid_data != null) {
                    var connection_ssid = NM.Utils.ssid_to_utf8(connection_ssid_data.get_data());
                    if (connection_ssid == ssid) { 
                        var profile = ConnectionProfile.fromNMConnection(connection, wifi, ap);
                        if (profile != null) {
                            if (profile.is_active){
                                active_profile = profile;
                            }
                            _profiles.set (connection.get_uuid (), profile);
                        }
                    }
                }
            }
        }
    }

    private NM.SettingWireless set_wireless_settings(
        string? ssid = this.ssid,
        string? bssid = this.bssid,
        string mode = "infrastructure",
        string? band = null,
        uint channel = 0,
        string? mac_address = null,
        bool powersave = true
    ){
        var wireless_setting = new NM.SettingWireless();
        wireless_setting.set_property("ssid", ssid);
        if (bssid != null) {
            wireless_setting.set_property("bssid", bssid);
        }
        wireless_setting.set_property("mode", mode);
        if (band != null) {
            wireless_setting.set_property("band", band);
        }
        if (channel != 0) {
            wireless_setting.set_property("channel", channel);
        }
        if (mac_address != null) {
            wireless_setting.set_property("mac-address", mac_address);
        }
        wireless_setting.set_property("powersave", powersave ? 1 : 0);

        return wireless_setting;
    }

    private NM.SettingWirelessSecurity set_security_settings(
        string? password,
        string security_type = "wpa-psk",
        string auth_alg = "open"
    ){
        var security_setting = new NM.SettingWirelessSecurity();
        security_setting.set_property("key-mgmt", security_type);
        security_setting.set_property("psk", password);
        security_setting.set_property("auth-alg", auth_alg);
        return security_setting;
    }

    private NM.SettingIP4Config set_ip4_settings(string ip4_method, string[]? ip4_dns = null){
        var ip4_setting = new NM.SettingIP4Config();
        ip4_setting.set_property("method", ip4_method);
        if (ip4_dns != null) {
            ip4_setting.set_property("dns", ip4_dns);
        }
        return ip4_setting;
    }

    private NM.SettingConnection set_general_settings(string? profile_name = null, int autoconnect_priority = 0, bool autoconnect = false){
        var general_setting = new NM.SettingConnection();
        if (profile_name != null){
            general_setting.set_property("id", profile_name);
        }
        general_setting.set_property("autoconnect", autoconnect);
        general_setting.set_property("autoconnect_priority", autoconnect_priority);
        return general_setting;
    }

    public async void create_full_connection(
        string? password = null,
        string? profile_name = null,
        int autoconnect_priority = 0,
        string? ssid = this.ssid,
        string? bssid = this.bssid,
        string mode = "infrastructure",
        string? band = null, // "a", "b", or "g"
        uint channel = 0,
        string? mac_address = null,
        bool powersave = true,
        string security_type = "wpa-psk",
        string auth_alg = "open",
        string ip4_method = "auto",
        string[]? ip4_dns = null,
        string ip6_method = "auto",
        bool autoconnect = false
    ) throws Error {
        try{
            var connection = NM.SimpleConnection.new();

            // Wireless settings
            var wireless_setting = set_wireless_settings(ssid, bssid, mode, band, channel, mac_address, powersave);
            connection.add_setting(wireless_setting);

            // Security settings
            if (password != null) {
                var security_setting = set_security_settings(password, security_type, auth_alg);
                connection.add_setting(security_setting);
            }

            // IPv4 settings
            var ip4_setting = set_ip4_settings(ip4_method, ip4_dns);
            connection.add_setting(ip4_setting);

            // IPv6 settings
            var ip6_setting = new NM.SettingIP6Config();
            ip6_setting.set_property("method", ip6_method);
            connection.add_setting(ip6_setting);

            // General connection settings
            var general_setting = set_general_settings(profile_name, autoconnect_priority, autoconnect);
            connection.add_setting(general_setting);

            // Activate the connection on the device
            yield ap.client.add_and_activate_connection_async(connection, wifi.device, ap.get_path(), null);
        } catch (Error e){
            critical(e.message);
        }
    }

    public async void create_new_connection(string? password = null) throws Error {
        yield this.create_full_connection(password);
    }

    public async void deactivate_connection() {
        try {
            if (active_profile == null){
                critical("you are not connected to this access point.");
                return;
            }

            var active_connection = wifi.device.get_active_connection();
            yield ap.client.deactivate_connection_async(active_connection, null);
        } catch (Error e) {
            critical(e.message);
        }
    }

    private string _icon() {
        if (strength >= 80) return Wifi.ICON_EXCELLENT;
        if (strength >= 60) return Wifi.ICON_GOOD;
        if (strength >= 40) return Wifi.ICON_OK;
        if (strength >= 20) return Wifi.ICON_WEAK;
        return Wifi.ICON_NONE;
    }

}
