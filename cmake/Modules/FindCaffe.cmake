# unset(Caffe_FOUND)

###Set the variable Caffe_DIR as the root of your caffe directory
set(Caffe_DIR ${CMAKE_SOURCE_DIR}/build/3rdparty/caffe)

find_path(Caffe_INCLUDE_DIRS 
  NAMES 
    caffe/caffe.hpp 
    caffe/common.hpp 
    caffe/net.hpp 
    caffe/proto/caffe.pb.h 
    caffe/util/io.hpp 
    caffe/vision_layers.hpp
  HINTS
    ${Caffe_DIR}/include)

find_library(Caffe_LIBS 
  NAMES
    caffe
  HINTS
    ${Caffe_DIR}/lib)

message("include_dirs:${Caffe_INCLUDE_DIRS}")
message("lib_dirs:${Caffe_LIBS}")

if (Caffe_LIBS AND Caffe_INCLUDE_DIRS)
  set(Caffe_FOUND true)
else ()
  set(Caffe_FOUND false)
endif ()
message("\${Caffe_FOUND} = ${Caffe_FOUND}")
