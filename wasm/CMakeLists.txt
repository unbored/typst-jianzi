add_executable(jianzi-wasm plugin.cpp svg-renderer.cpp)
target_link_libraries(jianzi-wasm PRIVATE JianziNote)
target_compile_options(jianzi-wasm PRIVATE -Wall -Wextra -fno-exceptions)
target_link_options(jianzi-wasm PRIVATE
  --no-entry
  -sSTANDALONE_WASM=1
  -sALLOW_MEMORY_GROWTH=1
  -sSTACK_SIZE=1048576
  -sFILESYSTEM=0
  -sDISABLE_EXCEPTION_CATCHING=1
  -sERROR_ON_UNDEFINED_SYMBOLS=0
  "-sEXPORTED_FUNCTIONS=['_init','_metrics','_render_natural']"
)
set_target_properties(jianzi-wasm PROPERTIES OUTPUT_NAME jianzinote.raw SUFFIX .wasm)
set(final_wasm "${CMAKE_BINARY_DIR}/jianzinote.wasm")
add_custom_command(OUTPUT "${final_wasm}"
  COMMAND "${WASI_STUB_EXECUTABLE}" --list "$<TARGET_FILE:jianzi-wasm>"
  COMMAND "${WASI_STUB_EXECUTABLE}" --output "${final_wasm}" "$<TARGET_FILE:jianzi-wasm>"
  COMMAND "${NODE_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/scripts/check-wasm.mjs" "${final_wasm}"
  DEPENDS jianzi-wasm "${WASI_STUB_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/scripts/check-wasm.mjs"
  VERBATIM)
set(package_wasm "${CMAKE_SOURCE_DIR}/assets/jianzinote.wasm")
add_custom_command(OUTPUT "${package_wasm}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_SOURCE_DIR}/assets"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${final_wasm}" "${package_wasm}"
  DEPENDS "${final_wasm}" VERBATIM)
add_custom_target(jianzi-plugin ALL DEPENDS "${package_wasm}")
