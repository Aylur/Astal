public class Astal.AnimatedPaintable : Object, Gdk.Paintable {

  private Gly.Image image;
  private Gly.Loader loader;
  private Cancellable cancellable;
  private Gdk.Texture current_frame;

  public double speed {get; set; default = 1;}

  private string _filename;
  public string filename {
    get {
      return this._filename;
    }
    set {
      this._filename = value;
      this.loader = new Gly.Loader(File.new_for_path(value));
      this.load.begin();
    }
  }

  private async void load() {
    if(this.cancellable != null) cancellable.cancel();
    this.cancellable = new Cancellable();
    try {
      this.image = yield this.loader.load_async(this.cancellable);
      if (this.image == null) return;
      this.schedule_next_frame.begin();
    }
    catch (Error e) {
      critical(e.message);
    }
  }

  private void on_timeout() {
    this.schedule_next_frame.begin();
  }

  private async bool schedule_next_frame() {
    Gly.Frame frame;
    try {
      frame = yield this.image.next_frame_async(cancellable);
      if(frame == null) return Source.REMOVE;
      this.current_frame = GlyGtk4.frame_get_texture(frame);
    }
    catch (Error e) {
      critical(e.message);
      return Source.REMOVE;
    }
    
    if (this.current_frame == null) return Source.REMOVE;
    this.invalidate_contents();
    this.invalidate_size();
    if(frame.get_delay() > 0) {
      Timeout.add_once((uint)(frame.get_delay()/1000/this.speed), (SourceOnceFunc)on_timeout);
    }
    return Source.REMOVE;
  }

  public void snapshot(Gdk.Snapshot snapshot, double width, double height) {
    if(this.current_frame != null) {
      this.current_frame.snapshot(snapshot, width, height);
    }
  }

  public int get_intrinsic_width () {
    return this.current_frame?.get_intrinsic_width() ?? 0;
  }

  public int get_intrinsic_height () {
    return this.current_frame?.get_intrinsic_height() ?? 0;
  }

  construct{
    this.cancellable = new Cancellable();
  }
}
