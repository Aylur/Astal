project(
  'astal-wl',
  'vala',
  'c',
  version: run_command('cat', join_paths(meson.project_source_root(), 'version')).stdout().strip(),
  meson_version: '>= 0.63.0',
  default_options: [
    'warning_level=2',
    'werror=false',
    'c_std=gnu11',
  ],
)

add_project_arguments('-DG_LOG_DOMAIN="AstalWl"', language: 'c')

version = meson.project_version()
name = meson.project_name()
version_split = version.split('.')
api_version = '0.1'
gir_name = 'AstalWl-0.1.gir'
typelib_name = 'AstalWl-0.1.typelib'

fs = import('fs')

config = configure_file(
  input: 'config.vala.in',
  output: 'config.vala',
  configuration: {
    'API_VERSION': api_version,
    'VERSION': version,
    'MAJOR_VERSION': version_split[0],
    'MINOR_VERSION': version_split[1],
    'MICRO_VERSION': version_split[2],
  },
)


wl_vapi_gen_prog = find_program('wl-vapi-gen', required: false)
if not wl_vapi_gen_prog.found()
  subproject('wl-vapi-gen')
  wl_vapi_gen_prog = find_program('wl-vapi-gen', required: false)
endif

wayland_protos = dependency('wayland-protocols')
wayland_scanner = find_program('wayland-scanner')

wl_protocol_dir = wayland_protos.get_variable(pkgconfig: 'pkgdatadir')

protocols = [
  join_paths(wl_protocol_dir, 'unstable/xdg-output/xdg-output-unstable-v1.xml'),
]

protocol_deps = []
protocol_vapis = []

foreach protocol : protocols
  client_header = custom_target(
    fs.name(protocol) + '_header',
    input: protocol,
    output: '@BASENAME@.h',
    command: [
      wayland_scanner,
      '-c', 'client-header',
      '@INPUT@',
      '@OUTPUT@',
    ],
  )

  code = custom_target(
    fs.name(protocol) + '_code',
    input: protocol,
    output: '@BASENAME@.c',
    command: [
      wayland_scanner,
      '-c', 'private-code',
      '@INPUT@',
      '@OUTPUT@',
    ],
  )

  vapi = custom_target(
    fs.name(protocol) + '_vapi',
    input: [protocol, client_header],
    output: '@BASENAME0@.vapi',
    command: [
      wl_vapi_gen_prog,
      '--vapi', '@OUTPUT@',
      '--protocol', '@INPUT0@',
      '--cheader', '@INPUT1@',
    ],
  )

  protocol_deps += declare_dependency(
    dependencies: [dependency('wayland-client')],
    sources: [client_header, code, vapi],
  )
  protocol_vapis += vapi
endforeach

deps = [
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gio-2.0'),
  dependency('wayland-client'),
]

sources = [config] + files(
  'wl_display.c',
  'registry.vala',
  'wl-source.vala',
  'output.vala',
  'seat.vala',
  'utils.vala'
)

lib = library(
  name,
  sources,
  dependencies: deps + protocol_deps,
  vala_args: ['--vapi-comments'],
  vala_header: name + '.h',
  vala_vapi: name + '-' + api_version + '.vapi',
  version: version,
  install: true,
  install_dir: [true, true, true],
)

gir = custom_target(
  gir_name,
  command: [
    find_program('python3'),
    files('gir.py'),
    '--name', name,
    '--gir', gir_name,
    '--pkgs', ':'.join(
      'json-glib-1.0',
      'wayland-client',
    ),
    '@INPUT@'
  ],
  input: sources + protocol_vapis,
  depends: lib,
  output: gir_name,
  install: true,
  install_dir: get_option('datadir') / 'gir-1.0',
)

custom_target(
  typelib_name,
  command: [
    find_program('g-ir-compiler'),
    '--output', '@OUTPUT@',
    '--shared-library', get_option('prefix') / get_option('libdir') / '@PLAINNAME@',
    meson.current_build_dir() / gir_name,
  ],
  input: lib,
  output: typelib_name,
  depends: [lib, gir],
  install: true,
  install_dir: get_option('libdir') / 'girepository-1.0',
)

import('pkgconfig').generate(
  lib,
  name: name,
  filebase: name + '-' + api_version,
  version: version,
  subdirs: name,
  requires: deps,
  install_dir: get_option('libdir') / 'pkgconfig',
)
