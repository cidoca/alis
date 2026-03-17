cmake_minimum_required(VERSION 3.10)

project(alis LANGUAGES C)

find_package(SDL2 REQUIRED)

include_directories(${SDL2_INCLUDE_DIR})

set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -s")

set(SOURCE
    src/cpu.c
    src/ga.c
    src/io.c
    src/log.c
    src/main.c
    src/memory.c
    src/psg.c
    src/sdl.c
    src/vdp.c
)

add_executable(alis ${SOURCE})

target_link_libraries(alis ${SDL2_LIBRARIES})

