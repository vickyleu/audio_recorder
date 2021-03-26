cmake_minimum_required(VERSION 3.10.2)

#define cpp source path
set(SRC_DIR src/main/cpp/lamemp3 src/main/cpp/lamemp3/vector)

#set *.h source path
include_directories(src/main/cpp/lamemp3)

#set cpp source path
aux_source_directory(src/main/cpp/lamemp3 SRC_LIST)

#set *.so files output path，please add this before add_library
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_SOURCE_DIR}/jniLibs/${ANDROID_ABI})

#add cpp files into library
add_library(lame SHARED
        src/main/cpp/MP3Recorder.cpp
        ${SRC_LIST})

find_library(log-lib log )

# Specifies libraries CMake should link to your target library. You
# can link multiple libraries, such as libraries you define in this
# build script, prebuilt third-party libraries, or system libraries.

target_link_libraries(lame ${log-lib} )
