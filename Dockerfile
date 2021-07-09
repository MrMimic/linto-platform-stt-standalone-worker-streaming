ARG PORT
ARG GPU_ARCH

# This image contains CUDA and dev utilities (smi, nvcc, etc)
FROM nvidia/cuda:11.4.0-devel-ubuntu18.04
LABEL maintainer="emeric.dynomant@atos.net"

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "=== Update base image ===" && \
    apt-get update && \
    apt-get install -y \
    python2.7 python3 python3-pip \
    git swig sox software-properties-common \
    automake wget unzip build-essential libtool \
    zlib1g-dev locales libatlas-base-dev ca-certificates \
    gfortran subversion apt-utils && \
    apt-get clean

RUN echo "=== Install Azure Linux headers ===" && \
    apt-get install -y linux-headers-$(uname -r)

# Check that NVCC compiler is found
RUN command -v nvcc >/dev/null 2>&1 || { echo >&2 "Compiler nvcc not found in $PATH. Aborting."; exit 1; }

RUN echo "=== Build Kaldi with GPU ==="
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi
WORKDIR /opt/kaldi/tools
RUN bash /opt/kaldi/tools/extras/install_mkl.sh && \
    make -j $(nproc)
# The architecture is specified for a Tesla M60
WORKDIR /opt/kaldi/src
RUN bash /opt/kaldi/src/configure --shared --use-cuda --cudatk-dir=/usr/local/cuda/ --cuda-arch=$GPU_ARCH && \
    make depend -j $(nproc)
RUN make -j $(nproc); exit 0
RUN mkdir -p /opt/kaldi/src_
RUN mv /opt/kaldi/src/base \
        /opt/kaldi/src/chain \
        /opt/kaldi/src/cudamatrix \
        /opt/kaldi/src/decoder \
        /opt/kaldi/src/feat \
        /opt/kaldi/src/fstext \
        /opt/kaldi/src/gmm \
        /opt/kaldi/src/hmm \
        /opt/kaldi/src/ivector \
        /opt/kaldi/src/kws \
        /opt/kaldi/src/lat \
        /opt/kaldi/src/lm \
        /opt/kaldi/src/matrix \
        /opt/kaldi/src/nnet \
        /opt/kaldi/src/nnet2 \
        /opt/kaldi/src/nnet3 \
        /opt/kaldi/src/online2 \
        /opt/kaldi/src/rnnlm \
        /opt/kaldi/src/sgmm2 \
        /opt/kaldi/src/transform \
        /opt/kaldi/src/tree \
        /opt/kaldi/src/util \
        /opt/kaldi/src/itf \
        /opt/kaldi/src/lib /opt/kaldi/src_

# Check that everything has been built with CUDA
RUN grep -e "CUDATKDIR = /usr/local/cuda" kaldi.mk || { echo >&2 "Kaldi does not seems to having been built with CUDA. Aborting."; exit 1; }

RUN echo "=== Cleaning build reliquates ==="
WORKDIR /opt/kaldi
RUN rm -r src && \
    mv src_ src && \
    rm src/*/*.cc && \
    rm src/*/*.o && \
    rm src/*/*.so
WORKDIR /opt/intel/mkl/lib
RUN rm -f intel64/*.a intel64_lin/*.a
WORKDIR /opt/kaldi/tools
RUN mkdir openfst_ && \
    mv openfst-*/lib openfst-*/include openfst-*/bin openfst_ && \
    rm openfst_/lib/*.so* && \
    rm openfst_/lib/*.la && \
    rm -r openfst-*/* && \
    mv openfst_/* openfst-*/ && \
    rm -r openfst_

RUN echo "=== Install Python dependencies ===" && \
    apt install -y python python-pip && wget https://apt.llvm.org/llvm.sh && \
    chmod +x llvm.sh && ./llvm.sh 10
ENV LLVM_CONFIG=/usr/bin/llvm-config-10
RUN /usr/bin/python3 -m pip install --upgrade pip && \
    /usr/bin/python3 -m pip install wheel setuptools numpy websockets librosa webrtcvad scipy sklearn vosk

RUN echo "=== Installing pyBK ==="
RUN git clone https://github.com/josepatino/pyBK /opt/pyBK
WORKDIR /opt/linstt
RUN mkdir pyBK && \
    cp /opt/pyBK/diarizationFunctions.py pyBK/diarizationFunctions.py

RUN echo "=== Copying API facilities and launch ==="
WORKDIR /opt/linstt
COPY run.py .
COPY tools.py .

EXPOSE $PORT

CMD python3 run.py --model /opt/model --port $PORT
