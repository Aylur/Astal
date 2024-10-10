project(
  'astal-cava',
  'c',
  version: '0.1.0',
  default_options: ['c_std=gnu11', 'warning_level=3', 'prefix=/usr'],
)

add_project_arguments(['-Wno-pedantic', '-Wno-unused-parameter'], language: 'c')

version_split = meson.project_version().split('.')
lib_so_version = version_split[0] + '.' + version_split[1]

pkg_config = import('pkgconfig')
gnome = import('gnome')

srcs = files(
  'cava.c',
  'astal-cava.h'
)

install_headers('astal-cava.h')

deps = [
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('cava')
]

astal_cava_lib = library(
  'astal-cava',
  sources: srcs,
  dependencies: deps,
  version: meson.project_version(),
  install: true,
)

libastal_cava = declare_dependency(link_with: astal_cava_lib)

pkg_config_name = 'astal-cava-' + lib_so_version

if get_option('introspection')
  gir = gnome.generate_gir(
    astal_cava_lib,
    sources: srcs,
    nsversion: '0.1',
    namespace: 'AstalCava',
    symbol_prefix: 'astal_cava',
    identifier_prefix: 'AstalCava',
    includes: ['GObject-2.0', 'Gio-2.0'],
    header: 'astal-cava.h',
    export_packages: pkg_config_name,
    install: true,
  )

  if get_option('vapi')
    gnome.generate_vapi(
      pkg_config_name,
      sources: [gir[0]],
      packages: ['gobject-2.0', 'gio-2.0'],
      install: true,
    )
  endif
endif

pkg_config.generate(
  name: 'astal-cava',
  version: meson.project_version(),
  libraries: [astal_cava_lib],
  filebase: pkg_config_name,
  subdirs: 'astal',
  description: 'audio analyzing service using cava',
  url: 'https://github.com/Aylur/astal',
)
