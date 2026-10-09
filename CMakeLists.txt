cmake_minimum_required(VERSION 3.21)
project(typst_jianzi VERSION 0.1.0 LANGUAGES C CXX)

if(NOT EMSCRIPTEN)
  message(FATAL_ERROR "Use the wasm-release preset with the wasm32-emscripten vcpkg triplet.")
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(BUILD_TESTING OFF CACHE BOOL "Disable upstream tests" FORCE)
set(JIANZINOTE_BUILD_FONT_READER OFF CACHE BOOL "No FreeType in plugin" FORCE)
set(JIANZINOTE_BUILD_TOOLS OFF CACHE BOOL "No upstream tools" FORCE)
set(PROJECT_LIBRARIES_STATIC ON CACHE BOOL "Link core statically" FORCE)

find_program(WASI_STUB_EXECUTABLE NAMES wasi-stub HINTS ENV WASI_STUB REQUIRED)
find_program(NODE_EXECUTABLE NAMES node HINTS "$ENV{EMSDK}/node" REQUIRED)
find_program(TYPST_EXECUTABLE NAMES typst HINTS ENV TYPST)
if(NOT EXISTS "${WASI_STUB_EXECUTABLE}")
  message(FATAL_ERROR "Set WASI_STUB_EXECUTABLE to the wasi-stub executable.")
endif()
if(NOT EXISTS "${NODE_EXECUTABLE}")
  message(FATAL_ERROR "Set NODE_EXECUTABLE (or EMSDK_NODE) to a Node.js executable for import validation.")
endif()

add_subdirectory(JianziNote EXCLUDE_FROM_ALL)
add_subdirectory(wasm)

# Only a fixed directory of bundled libraries is exposed by the Typst API.
set(JIANZI_LIBRARY_DIR "${CMAKE_SOURCE_DIR}/assets/libraries" CACHE PATH "Bundled CBOR directory")
file(GLOB libraries CONFIGURE_DEPENDS "${JIANZI_LIBRARY_DIR}/*.cbor")
if(NOT EXISTS "${JIANZI_LIBRARY_DIR}/kai.cbor")
  message(FATAL_ERROR "kai.cbor is required in JIANZI_LIBRARY_DIR (${JIANZI_LIBRARY_DIR}).")
endif()
set(style_names "")
set(staged_libraries "")
foreach(library IN LISTS libraries)
  get_filename_component(style "${library}" NAME_WE)
  if(NOT style MATCHES "^[a-z][a-z0-9_-]*$")
    message(FATAL_ERROR "Invalid style filename: ${style}; use lowercase ASCII names.")
  endif()
  string(APPEND style_names "  \"${style}\",\n")
  set(destination "${CMAKE_SOURCE_DIR}/assets/libraries/${style}.cbor")
  if(NOT library STREQUAL destination)
    add_custom_command(OUTPUT "${destination}"
      COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_SOURCE_DIR}/assets/libraries"
      COMMAND ${CMAKE_COMMAND} -E copy_if_different "${library}" "${destination}"
      DEPENDS "${library}" VERBATIM)
    list(APPEND staged_libraries "${destination}")
  endif()
endforeach()
configure_file(cmake/styles.typ.in "${CMAKE_SOURCE_DIR}/assets/styles.typ" @ONLY)
add_custom_target(jianzi-assets ALL DEPENDS ${staged_libraries})

option(JIANZI_BUILD_TESTS "Enable Typst integration tests" ON)
if(JIANZI_BUILD_TESTS AND TYPST_EXECUTABLE)
  enable_testing()
  foreach(test IN ITEMS abi smoke nine-grid track)
    add_test(NAME ${test} COMMAND "${TYPST_EXECUTABLE}" compile --root "${CMAKE_SOURCE_DIR}"
      "${CMAKE_SOURCE_DIR}/tests/${test}.typ" "${CMAKE_BINARY_DIR}/${test}.pdf")
  endforeach()
  foreach(case IN ITEMS uninitialized invalid-cbor invalid-utf8 nul invalid-formula unknown-style invalid-fonts reinit
      track-five track-reference track-empty track-comma track-unclosed track-nesting track-placeholder track-old-braces)
    add_test(NAME error-${case} COMMAND ${CMAKE_COMMAND}
      "-DTYPST=${TYPST_EXECUTABLE}" "-DROOT=${CMAKE_SOURCE_DIR}" "-DBUILD=${CMAKE_BINARY_DIR}"
      "-DCASE=${case}" -P "${CMAKE_SOURCE_DIR}/cmake/expect-error.cmake")
  endforeach()
endif()

install(FILES jianzi.typ track.typ typst.toml README.md LICENSE DESTINATION .)
install(FILES assets/styles.typ assets/jianzinote.wasm DESTINATION assets)
foreach(library IN LISTS libraries)
  install(FILES "${library}" DESTINATION assets/libraries)
endforeach()
