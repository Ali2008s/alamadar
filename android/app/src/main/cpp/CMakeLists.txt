cmake_minimum_required(VERSION 3.22.1)

project("almadar_guard")

# Optimization flags to make reverse engineering harder
add_compile_options(
    -O3
    -fvisibility=hidden
    -fstack-protector-strong
    -ffunction-sections
    -fdata-sections
)

add_link_options(
    -Wl,--gc-sections
    -Wl,-z,relro
    -Wl,-z,now
)

add_library(
    almadar_guard
    SHARED
    security_guard.cpp
)

find_library(log-lib log)

target_link_libraries(
    almadar_guard
    ${log-lib}
)
