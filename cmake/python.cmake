# Will need swig
set(CMAKE_SWIG_FLAGS)
find_package(SWIG REQUIRED)
include(UseSWIG)

if(${SWIG_VERSION} VERSION_GREATER_EQUAL 4)
  list(APPEND CMAKE_SWIG_FLAGS "-doxygen")
endif()

if(UNIX AND NOT APPLE)
  list(APPEND CMAKE_SWIG_FLAGS "-DSWIGWORDSIZE64")
endif()

# Find Python
find_package(Python REQUIRED COMPONENTS Interpreter Development)

if(Python_VERSION VERSION_GREATER_EQUAL 3)
  list(APPEND CMAKE_SWIG_FLAGS "-py3;-DPY3")
endif()

# Needed by java/CMakeLists.txt
set(PYTHON_PROJECT pythonnative)

# Swig wrap all libraries
foreach(SUBPROJECT IN ITEMS Foo)
  add_subdirectory(${SUBPROJECT}/python)
endforeach()

#######################
## Python Packaging  ##
#######################
# Find if python module MODULE_NAME is available,
# if not install it to the Python user install directory.
function(search_python_module MODULE_NAME)
  execute_process(
    COMMAND ${Python_EXECUTABLE} -c "import ${MODULE_NAME}; print(${MODULE_NAME}.__version__)"
    RESULT_VARIABLE _RESULT
    OUTPUT_VARIABLE MODULE_VERSION
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
    )
  if(${_RESULT} STREQUAL "0")
    message(STATUS "Found python module: ${MODULE_NAME} (found version \"${MODULE_VERSION}\")")
  else()
    message(WARNING "Can't find python module \"${MODULE_NAME}\", user install it using pip...")
    execute_process(
      COMMAND ${Python_EXECUTABLE} -m pip install --upgrade --user ${MODULE_NAME}
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
  endif()
endfunction()

# Look for required python modules
search_python_module(setuptools)
search_python_module(wheel)

# setup.py.in contains cmake variable e.g. @PROJECT_NAME@ and
# generator expression e.g. $<TARGET_FILE_NAME:pyFoo>
configure_file(
  ${PROJECT_SOURCE_DIR}/python/setup.py.in
  ${PROJECT_BINARY_DIR}/python/setup.py.in
  @ONLY)
file(GENERATE
  OUTPUT ${PROJECT_BINARY_DIR}/python/$<CONFIG>/setup.py
  INPUT ${PROJECT_BINARY_DIR}/python/setup.py.in)

add_custom_command(
  OUTPUT python/setup.py
  DEPENDS ${PROJECT_BINARY_DIR}/python/$<CONFIG>/setup.py
  COMMAND ${CMAKE_COMMAND} -E copy ./$<CONFIG>/setup.py setup.py
  WORKING_DIRECTORY python)

add_custom_command(
  OUTPUT python/${PROJECT_NAME}/__init__.py
  DEPENDS ${PROJECT_SOURCE_DIR}/python/__init__.py.in
  COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/python/__init__.py.in ${PROJECT_NAME}/__init__.py
  WORKING_DIRECTORY python)

add_custom_command(
  OUTPUT python/${PROJECT_NAME}/Foo/__init__.py
  DEPENDS ${PROJECT_SOURCE_DIR}/python/__init__.py.in
  COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/python/__init__.py.in ${PROJECT_NAME}/Foo/__init__.py
  WORKING_DIRECTORY python)

add_custom_target(python_package ALL
  DEPENDS
    python/setup.py
    python/${PROJECT_NAME}/__init__.py
    python/${PROJECT_NAME}/Foo/__init__.py
  COMMAND ${CMAKE_COMMAND} -E remove_directory dist
  COMMAND ${CMAKE_COMMAND} -E make_directory ${PROJECT_NAME}/.libs
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:pyFoo> ${PROJECT_NAME}/Foo
  # Don't need to copy static lib on Windows
  COMMAND ${CMAKE_COMMAND} -E $<IF:$<BOOL:${UNIX}>,copy,true>
    $<TARGET_FILE:Foo> ${PROJECT_NAME}/.libs
  COMMAND ${Python_EXECUTABLE} setup.py bdist_wheel
  BYPRODUCTS
    python/${PROJECT_NAME}
    python/build
    python/dist
    python/${PROJECT_NAME}.egg-info
  WORKING_DIRECTORY python)

###################
##  Python Test  ##
###################
if(BUILD_TESTING)
  # Look for python module virtualenv
  search_python_module(virtualenv)
  # Testing using a vitual environment
  set(VENV_EXECUTABLE ${Python_EXECUTABLE} -m virtualenv)
  set(VENV_DIR ${CMAKE_CURRENT_BINARY_DIR}/venv)
  if(WIN32)
    set(VENV_Python_EXECUTABLE "${VENV_DIR}\\Scripts\\python.exe")
  else()
    set(VENV_Python_EXECUTABLE ${VENV_DIR}/bin/python)
  endif()
  # make a virtualenv to install our python package in it
  add_custom_command(TARGET python_package POST_BUILD
    COMMAND ${VENV_EXECUTABLE} -p ${Python_EXECUTABLE} ${VENV_DIR}
    # Must not call it in a folder containing the setup.py otherwise pip call it
    # (i.e. "python setup.py bdist") while we want to consume the wheel package
    COMMAND ${VENV_Python_EXECUTABLE} -m pip install --find-links=${CMAKE_CURRENT_BINARY_DIR}/python/dist ${PROJECT_NAME}
    BYPRODUCTS ${VENV_DIR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

  set(TEST_PATH ${PROJECT_BINARY_DIR}/python/test)
  file(COPY ${PROJECT_SOURCE_DIR}/python/test.py
    DESTINATION ${TEST_PATH})
  # run the tests within the virtualenv
  add_test(
    NAME python_test
    COMMAND ${VENV_Python_EXECUTABLE} test.py
    WORKING_DIR ${TEST_PATH})
endif()
