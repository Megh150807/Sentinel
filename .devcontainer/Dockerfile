FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install the C++ and Python Arsenal
RUN apt-get update && apt-get install -y \
    build-essential cmake gdb ninja-build git curl wget unzip tar sudo \
    python3 python3-pip pkg-config libcurl4-openssl-dev \
    apt-transport-https ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

# 1b. Install XGBoost — builds the shared library (libxgboost.so) needed by
#     CMake's find_library(xgboost REQUIRED) in the C++ core engine.
#     We install the Python wheel (which ships the .so) then symlink it into
#     the standard lib search path so CMake can locate it.
RUN pip3 install --no-cache-dir xgboost==2.0.3 \
    && XGBOOST_SO=$(python3 -c "import xgboost, os; print(os.path.join(os.path.dirname(xgboost.__file__), 'lib', 'libxgboost.so'))") \
    && cp "$XGBOOST_SO" /usr/local/lib/libxgboost.so \
    && ldconfig \
    && XGBOOST_INC=$(python3 -c "import xgboost, os; print(os.path.join(os.path.dirname(xgboost.__file__), 'include'))") \
    && cp -r "$XGBOOST_INC" /usr/local/include/xgboost


# 2. Install Google Cloud SDK (For deploying to Cloud Run)
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Flutter dependencies
RUN apt-get update && apt-get install -y \
    clang xz-utils libgtk-3-dev \
    && rm -rf /var/lib/apt/lists/*

# 4. Setup Non-Root User
ARG USERNAME=sentinel
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /workspace

# 5. Install Flutter SDK (For the UI Agent)
RUN git clone https://github.com/flutter/flutter.git -b stable /home/$USERNAME/flutter
ENV PATH="$PATH:/home/$USERNAME/flutter/bin"
RUN flutter precache && flutter config --enable-web

CMD [ "sleep", "infinity" ]