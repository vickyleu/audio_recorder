
cmake_minimum_required(VERSION 3.10.2)

if (${ANDROID_ABI} STREQUAL arm)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=vfp -mfloat-abi=softfp -fno-short-enums -Werror,-Wshift-negative-value -DANDROID")
endif ()
set(CMAKE_CPP_FLAGS "${CMAKE_CPP_FLAGS} -Werror,-Wshift-negative-value ")
SET(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,-s")


#指定头文件所在，可以多次调用，指定多个路径
include_directories(lamemp3)

#添加自自定义的so库时，有两种方式，一种添加一个目录，一种一个个文件添加

#设定一个目录
aux_source_directory(lamemp3 SRC_LIST)

#将前面目录下所有的文件都添加进去
add_library(lamemp3 SHARED MP3Recorder.cpp ${SRC_LIST})

find_library(log-lib log )
