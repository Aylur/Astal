public class AstalNetwork.ConnectionProfile : Object {
    private Wifi wifi;
    private NM.AccessPoint ap;
    private NM.RemoteConnection connection;

    public string uuid { get { return connection.get_uuid(); } }
    public bool is_active { get { return uuid == wifi.device.get_active_connection().uuid; } }

    public string id { get { return connection.get_id(); } }
    public int autoconnect_priority { get { return connection.get_setting_connection().autoconnect_priority; } }
    public bool autoconnect { get { return connection.get_setting_connection().autoconnect; } }
    public bool visible { get { return connection.visible; } }

    public string ip4_method { get { return connection.get_setting_ip4_config().get_method(); } }
    public string ip6_method { get { return connection.get_setting_ip6_config().get_method(); } }

    public string mode { get { return connection.get_setting_wireless().get_mode(); } }
    public uint channel { get { return connection.get_setting_wireless().get_channel(); } }
    public string mac_address { get { return connection.get_setting_wireless().get_mac_address(); } }
    public bool powersave { get { return connection.get_setting_wireless().get_powersave() == 1 ? true : false; } }

    public ConnectionProfile(NM.RemoteConnection connection, Wifi wifi, NM.AccessPoint ap) {
        this.ap = ap;
        this.connection = connection;
        this.wifi = wifi;
    }

    public static ConnectionProfile? fromNMConnection(NM.RemoteConnection connection, Wifi wifi, NM.AccessPoint ap) {
        var wireless_setting = connection.get_setting_wireless();
        if (wireless_setting == null) {
            return null;
        }

        var connection_ssid_data = wireless_setting.get_ssid();
        if (connection_ssid_data == null) {
            return null;
        }

        string? password = null;
        var security_setting = connection.get_setting_wireless_security();
        if (security_setting != null) {
            password = security_setting.psk;
        }

        return new ConnectionProfile(connection, wifi, ap);
    }

    public string? get_psk() {
        // FIX: -> find out why this does not return psk
        return connection.get_setting_wireless_security().psk;
    }

    public string? get_key() {
        return connection.get_setting_wireless_security().get_key_mgmt();
    }

    public string? auth_algo() {
        return connection.get_setting_wireless_security().get_auth_alg();
    }

    public string[]? get_dns() {
        return connection.get_setting_ip4_config().dns;
    }

    public async void activate_connection() throws Error {
        try {
            yield ap.client.activate_connection_async(connection, wifi.device, ap.get_path(), null);
        } catch (Error err) {
            critical(err.message);
        }
    }

    public async void deactivate_connection() {
        try {
            var active_connection = wifi.device.get_active_connection();

            if (active_connection == null) {
                critical("No active connection found.");
                return;
            }

            if (!is_active){
                critical("you are not connected to this profile.");
                return;
            }

            yield ap.client.deactivate_connection_async(active_connection, null);
        } catch (Error e) {
            critical(e.message);
        }
    }

    public async void delete_profile() throws Error {
        try{
            yield connection.delete_async(null);
        } catch (Error e) {
            critical(e.message);
        }
    }

    private NM.SettingWireless set_wireless_settings(
        string? ssid = null,
        string? bssid = this.ap.bssid,
        string mode = "infrastructure",
        string? band = null,
        uint channel = 0,
        string? mac_address = null,
        bool powersave = true
    ){
        var wireless_setting = connection.get_setting_wireless();

        var ssid_bytes = ssid.data;
        var ssid_gbytes = new GLib.Bytes(ssid_bytes);
        wireless_setting.set_property("ssid", ssid_gbytes);

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
        var security_setting = connection.get_setting_wireless_security();
        security_setting.set_property("key-mgmt", security_type);
        security_setting.set_property("psk", password);
        security_setting.set_property("auth-alg", auth_alg);
        return security_setting;
    }

    private NM.SettingIP4Config set_ip4_settings(string ip4_method, string[]? ip4_dns = null){
        var ip4_setting = connection.get_setting_ip4_config();
        ip4_setting.set_property("method", ip4_method);
        if (ip4_dns != null) {
            ip4_setting.set_property("dns", ip4_dns);
        }
        return ip4_setting;
    }

    private NM.SettingConnection set_general_settings(string? profile_name = null, int autoconnect_priority = 0, bool autoconnect = false){
        var general_setting = connection.get_setting_connection();
        if (profile_name != null){
            general_setting.set_property("id", profile_name);
        }
        general_setting.set_property("autoconnect", autoconnect);
        general_setting.set_property("autoconnect_priority", autoconnect_priority);
        return general_setting;
    }

    public async void update_profile(
        string? password = null,
        string? profile_name = null,
        int autoconnect_priority = 0,
        string? ssid = null,
        string? bssid = null,
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

            yield connection.commit_changes_async(true, null);
        } catch (Error e){
            critical(e.message);
        }
    }

}
