cmake_minimum_required(VERSION 3.10)

project(alis LANGUAGES C)

find_package(SDL2 REQUIRED)

set(SOURCE
    src/cpu.c
    src/ga.c
    src/io.c
    src/main.c
    src/memory.c
    src/psg.c
    src/sdl.c
    src/vdp.c
)

add_compile_options(-Wall)
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    add_link_options(-s)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
else()
    set(SOURCE ${SOURCE} src/log.c)
    add_compile_options(-DDEBUG -O2)
endif()

add_executable(alis ${SOURCE})

target_link_libraries(alis ${SDL2_LIBRARIES})
