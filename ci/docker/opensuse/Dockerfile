# Create a virtual environment with all tools installed
# ref: https://hub.docker.com/r/opensuse/tumbleweed
FROM opensuse/tumbleweed AS env

# Install system build dependencies
ENV PATH=/usr/local/bin:$PATH
RUN zypper update -y \
&& zypper install -y git patch gcc gcc-c++ cmake \
&& zypper clean -a
ENV CC=gcc CXX=g++

# Install swig
RUN zypper update -y \
&& zypper install -y swig \
&& zypper clean -a

# Install Python
RUN zypper update -y \
&& zypper install -y \
 python311 python311-devel python311-pip \
 python311-wheel python311-setuptools \
 python3-numpy python3-pandas \
&& zypper clean -a
RUN python3.11 -m pip install --break-system-packages \
 mypy

# Add the library src to our build env
FROM env AS devel
WORKDIR /home/project
COPY . .

FROM devel AS build
RUN cmake --version
RUN cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build --target all -v
RUN cmake --build build --target install -v

FROM build AS test
RUN CTEST_OUTPUT_ON_FAILURE=1 cmake --build build --target test -v

# Test install rules
FROM env AS install_env
COPY --from=build /home/project/build/python/dist/*.whl ./
RUN python3 -m pip install --break-system-packages \
 --find-links=. \
 pythonnative*.whl

FROM install_env AS install_devel
WORKDIR /home/samples
COPY ci/samples .

FROM install_devel AS install_build
RUN python3 -m compileall .

FROM install_build AS install_test
RUN python3 sample.py
