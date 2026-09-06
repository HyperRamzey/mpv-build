#!/bin/bash
# patch-libplacebo-glslang.sh — make libplacebo's glslang detection use the
# cmake package config from our deps prefix (static, C++-runtime-correct)
# instead of find_library probes that cannot link static C++ libs.
set -e
F=G:/mpv-build/libplacebo-src/src/glsl/meson.build
grep -q "deps-build glslang cmake patch" $F && { echo "already patched"; exit 0; }

python3 - <<'PYEOF'
p = "G:/mpv-build/libplacebo-src/src/glsl/meson.build"
s = open(p).read()

old = """  glslang_deps = [
    cxx.find_library('glslang-default-resource-limits', required: false)
  ]

  # meson doesn't respect generator expressions in INTERFACE_LINK_LIBRARIES
  # https://github.com/mesonbuild/meson/issues/8232
  # TODO: Use the following once it's fixed
  # glslang = dependency('glslang', method: 'cmake', modules: ['glslang::SPIRV'])

  vulkan_sdk = get_option('vulkan-sdk')
  vulkan_lib_dirs = []
  if vulkan_sdk != ''
    vulkan_lib_dirs += [vulkan_sdk / 'lib']
  endif
  prefer_static = get_option('prefer_static')
  found_lib = false
  foreach arg : [[prefer_static, false], [not prefer_static, glslang_req]]
    static   = arg[0]
    required = arg[1]

    spirv = cxx.find_library('SPIRV', required: required, static: static, dirs: vulkan_lib_dirs)

    if not spirv.found()
      continue
    endif

    glslang_deps += spirv

    # Glslang 15.0.0 moved some code around, add also linking to glslang, while
    # this is not needed for older versions, it will still work.
    glslang_deps += cxx.find_library('glslang', required: required, static: static)

    if static
      glslang_deps += [
        # Always required for static linking
        cxx.find_library('MachineIndependent', required: false, static: true, dirs: vulkan_lib_dirs),
        cxx.find_library('OSDependent',        required: false, static: true, dirs: vulkan_lib_dirs),
        cxx.find_library('OGLCompiler',        required: false, static: true, dirs: vulkan_lib_dirs),
        cxx.find_library('GenericCodeGen',     required: false, static: true, dirs: vulkan_lib_dirs),
        # SPIRV-Tools are required only if optimizer is enabled in glslang build
        cxx.find_library('SPIRV-Tools',        required: false, static: true, dirs: vulkan_lib_dirs),
        cxx.find_library('SPIRV-Tools-opt',    required: false, static: true, dirs: vulkan_lib_dirs),
      ]
    endif

    found_lib = true
    break
  endforeach

  if found_lib and cc.has_header('glslang/build_info.h')
    glslang = declare_dependency(dependencies: glslang_deps)
  endif
"""

new = """  glslang_deps = [
    cxx.find_library('glslang-default-resource-limits', required: false)
  ]

  # deps-build glslang cmake patch: use the static cmake package config from
  # the deps prefix (find_library probes cannot link static C++ libraries)
  glslang = dependency('glslang', method: 'cmake', required: false,
    modules: ['glslang::SPIRV', 'glslang::glslang-default-resource-limits'])

  if glslang.found() and cc.has_header('glslang/build_info.h')
    found_lib = true
  else
    glslang = disabler()
  endif
"""

assert old in s, "glsl meson block not found"
s = s.replace(old, new)
open(p, "w").write(s)
print("patched")
PYEOF

diff -u /g/deps-build/patches/libplacebo-glsl-meson.build.orig $F > /g/deps-build/patches/libplacebo-glslang-cmake.patch || true
echo "patch saved: $(grep -c '^[+-]' /g/deps-build/patches/libplacebo-glslang-cmake.patch) lines"