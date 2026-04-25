cmake_minimum_required(VERSION 3.20)
project(SentinelCoreEngine CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Enforce Mechanical Sympathy: Fast math, LTO, native architecture optimizations
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3 -march=native -flto -pthread")

include(FetchContent)

# Lightweight HTTP Library
FetchContent_Declare(
    cpp-httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG v0.14.1
)
FetchContent_MakeAvailable(cpp-httplib)

# JSON Parser
FetchContent_Declare(
    json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.3
)
FetchContent_MakeAvailable(json)

# GCP logic requires cURL
find_package(CURL REQUIRED)

# XGBoost C-API (dynamically linked from OS)
find_library(XGBOOST_LIB xgboost REQUIRED)

find_package(OpenMP REQUIRED)

include_directories(include)

file(GLOB SOURCES "src/*.cpp")

add_executable(sentinel_core ${SOURCES})

target_link_libraries(sentinel_core PRIVATE 
    httplib::httplib 
    nlohmann_json::nlohmann_json 
    CURL::libcurl
    ${XGBOOST_LIB}
    OpenMP::OpenMP_CXX
)
