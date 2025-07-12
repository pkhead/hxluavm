project('hxluavm', 'c')

sources = run_command(get_option('python'), 'globber.py', get_option('lua_include'), check: true).stdout().strip().split('\n')
sources += ['hlexport.c']

cc = meson.get_compiler('c')

deps = []

if get_option('hashlink_libs') != ''
    deps += cc.find_library('hl', dirs: [get_option('hashlink_libs')])
else
    deps += cc.find_library('hl')
endif

incdirs = []
incdirs += get_option('lua_include')

if get_option('hashlink_include') != ''
    incdirs += get_option('hashlink_include')
endif

message(sources)
message(get_option('lua_include'))

both_libraries(get_option('lib_name'), sources,
    include_directories : incdirs,
    dependencies: deps,

    install : true,
    install_dir : get_option('hashlink_libs')
)