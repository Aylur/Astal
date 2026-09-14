[DBus(name = "org.bluez.Adapter1")]
private interface AstalBluetooth.IAdapter : DBusProxy {
    public abstract async void remove_device(ObjectPath device) throws Error;
    public abstract async void start_discovery() throws Error;
    public abstract async void stop_discovery() throws Error;

    public abstract string[] uuids { owned get; }
    public abstract bool discoverable { get; set; }
    public abstract bool discovering { get; }
    public abstract bool pairable { get; set; }
    public abstract bool powered { get; set; }
    public abstract string address { owned get; }
    public abstract string alias { owned get; set; }
    public abstract string modalias { owned get; }
    public abstract string name { owned get; }
    public abstract uint class { get; }
    public abstract uint discoverable_timeout { get; set; }
    public abstract uint pairable_timeout { get; set; }
}

[DBus(name = "org.bluez.Device1")]
private interface AstalBluetooth.IDevice : DBusProxy {
    public abstract async void cancel_pairing() throws Error;
    public abstract async void connect() throws Error;
    public abstract async void connect_profile(string uuid) throws Error;
    public abstract async void disconnect() throws Error;
    public abstract async void disconnect_profile(string uuid) throws Error;
    public abstract async void pair() throws Error;

    public abstract string[] uuids { owned get; }
    public abstract bool blocked { get; set; }
    public abstract bool connected { get; }
    public abstract bool legacy_pairing { get; }
    public abstract bool paired { get; }
    public abstract bool trusted { get; set; }
    public abstract int16 rssi { get; }
    public abstract ObjectPath adapter { owned get; }
    public abstract string address { owned get; }
    public abstract string alias { owned get; set; }
    public abstract string icon { owned get; }
    public abstract string modalias { owned get; }
    public abstract string name { owned get; }
    public abstract uint16 appearance { get; }
    public abstract uint32 class { get; }
}

[DBus(name = "org.bluez.Battery1")]
private interface AstalBluetooth.IBattery : DBusProxy {
    public abstract uint8 percentage { get; }
    public abstract string source { owned get; }
}
