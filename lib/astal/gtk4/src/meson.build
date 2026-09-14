version_split = meson.project_version().split('.')
api_version = version_split[0] + '.' + version_split[1]
gir = 'Astal-' + api_version + '.gir'
typelib = 'Astal-' + api_version + '.typelib'

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

config = configure_file(
  input: 'config.vala.in',
  output: 'config.vala',
  configuration: {
    'API_VERSION': api_version,
    'VERSION': meson.project_version(),
    'MAJOR_VERSION': version_split[0],
    'MINOR_VERSION': version_split[1],
    'MICRO_VERSION': version_split[2],
  },
)

deps = [
  dependency('glib-2.0'),
  dependency('astal-io-0.1'),
  dependency('gtk4'),
  dependency('gtk4-layer-shell-0'),
  dependency('glycin-2'),
  dependency('glycin-gtk4-2'),
]

sources = [config] + files(
  'widget/animated-paintable.vala',
  'widget/bin.vala',
  'widget/box.vala',
  'widget/gizmo.vala',
  'widget/slider.vala',
  'widget/window.vala',
  'application.vala',
)

lib = library(
  meson.project_name(),
  sources,
  dependencies: deps,
  vala_args: ['--vapi-comments'],
  vala_header: meson.project_name() + '.h',
  vala_vapi: meson.project_name() + '-' + api_version + '.vapi',
  version: meson.project_version(),
  install: true,
  install_dir: [true, true, true],
)

pkgs = []
foreach dep : deps
  pkgs += ['--pkg=' + dep.name()]
endforeach

gir_tgt = custom_target(
  gir,
  command: [
    find_program('python3'),
    girpy,
    '--name', meson.project_name(),
    '--gir', gir + ':src/' + gir,
    '--pkgs', ':'.join(
      'astal-io-0.1',
      'gtk4',
      'gtk4-layer-shell-0',
      'glycin-2',
      'glycin-gtk4-2'
    ),
    sources,
  ],
  input: sources,
  depends: lib,
  output: gir,
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)

custom_target(
  typelib,
  command: [
    find_program('g-ir-compiler'),
    '--output', '@OUTPUT@',
    '--shared-library', libdir / '@PLAINNAME@',
    meson.current_build_dir() / gir,
  ],
  input: lib,
  output: typelib,
  depends: [lib, gir_tgt],
  install: true,
  install_dir: libdir / 'girepository-1.0',
)

import('pkgconfig').generate(
  lib,
  name: meson.project_name(),
  filebase: meson.project_name() + '-' + api_version,
  version: meson.project_version(),
  subdirs: meson.project_name(),
  requires: deps,
  install_dir: libdir / 'pkgconfig',
)
