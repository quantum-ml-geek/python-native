# Create a virtual environment with all tools installed
# ref: https://hub.docker.com/_/debian
FROM debian:unstable AS env

# Install system build dependencies
ENV PATH=/usr/local/bin:$PATH
RUN apt update -qq \
&& apt install -yq \
 git wget libssl-dev build-essential cmake \
&& apt clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install swig
RUN apt update -qq \
&& apt install -yq swig \
&& apt clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Python
RUN apt update -qq \
&& apt install -yq \
 python3-dev python3-pip python3-venv \
 python3-setuptools python3-wheel \
 python3-numpy python3-pandas \
&& apt clean \
&& rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN python3 -m pip install --break-system-package \
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
