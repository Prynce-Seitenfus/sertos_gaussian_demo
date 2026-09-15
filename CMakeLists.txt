cmake_minimum_required(VERSION 3.10)
project(sertos_gaussian_demo C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Configurable paths to SertOS headers and pre-compiled static library
set(SERTOS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../sertos" CACHE PATH "Path to SertOS root directory")

# Configure target library based on host platform
if(WIN32)
    set(SERTOS_LIB_NAME "libsertos_windows.a")
    set(SERTOS_SUBDIR "windows")
elseif(UNIX)
    set(SERTOS_LIB_NAME "libsertos_posix.a")
    set(SERTOS_SUBDIR "posix")
else()
    set(SERTOS_LIB_NAME "libsertos_cortex_m4.a")
    set(SERTOS_SUBDIR "arm")
endif()

if(EXISTS "${SERTOS_DIR}/lib/${SERTOS_SUBDIR}/${SERTOS_LIB_NAME}")
    set(DEFAULT_LIB_PATH "${SERTOS_DIR}/lib/${SERTOS_SUBDIR}/${SERTOS_LIB_NAME}")
elseif(EXISTS "${SERTOS_DIR}/build_win/${SERTOS_LIB_NAME}")
    set(DEFAULT_LIB_PATH "${SERTOS_DIR}/build_win/${SERTOS_LIB_NAME}")
else()
    set(DEFAULT_LIB_PATH "${SERTOS_DIR}/lib/${SERTOS_SUBDIR}/${SERTOS_LIB_NAME}")
endif()

set(SERTOS_LIB_PATH "${DEFAULT_LIB_PATH}" CACHE FILEPATH "Path to pre-compiled SertOS library file")

set(DEMO_SOURCES
    src/main.c
    src/gaussian_math.c
    src/gaussian_state.c
    src/gaussian_tasks.c
    src/terminal_ui.c
)

# Select board/platform support package console driver
if(WIN32)
    list(APPEND DEMO_SOURCES src/bsp/bsp_console_windows.c)
elseif(UNIX)
    list(APPEND DEMO_SOURCES src/bsp/bsp_console_posix.c)
else()
    list(APPEND DEMO_SOURCES src/bsp/bsp_console_uart_stub.c)
endif()

add_executable(sertos_gaussian_demo ${DEMO_SOURCES})

target_include_directories(sertos_gaussian_demo PRIVATE
    inc
    ${SERTOS_DIR}/inc
    ${SERTOS_DIR}/port
    ${SERTOS_DIR}/modules/ring_buffer
    ${SERTOS_DIR}/modules/linked_list
    ${SERTOS_DIR}/modules/bitmap
    ${SERTOS_DIR}/modules/atomic
)

# Find or link against pre-compiled SertOS architecture library
if(EXISTS "${SERTOS_LIB_PATH}")
    target_link_libraries(sertos_gaussian_demo PRIVATE
        "${SERTOS_LIB_PATH}"
    )
else()
    message(FATAL_ERROR "Pre-compiled SertOS library not found at '${SERTOS_LIB_PATH}'. Run build_host.bat in sertos first.")
endif()

# Link platform math and multimedia timer libraries
if(WIN32)
    target_link_libraries(sertos_gaussian_demo PRIVATE winmm)
else()
    target_link_libraries(sertos_gaussian_demo PRIVATE m)
endif()

target_compile_options(sertos_gaussian_demo PRIVATE
    -Wall
    -Wextra
    -pedantic
    -Werror
)
