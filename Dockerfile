# This image contains CUDA and dev utilities (smi, nvcc, etc)
FROM nvidia/cuda:11.4.0-devel-ubuntu18.04
LABEL maintainer="emeric.dynomant@atos.net"

# Update packages from base image
RUN echo "=== Update base image ===" && \
    apt-get update && \
    apt-get install -y \
    python2.7 python3 python3-pip \
    git swig sox software-properties-common \
    automake wget unzip build-essential libtool \
    zlib1g-dev locales libatlas-base-dev ca-certificates \
    gfortran subversion && \
    apt-get clean

# Install Azure correct Ubuntu headers
RUN echo "=== Install Azure Linux headers ===" && \
    apt-get install -y linux-headers-$(uname -r)

# Check that NVCC compiler is found
RUN command -v nvcc >/dev/null 2>&1 || { echo >&2 "Compiler nvcc not found in $PATH. Aborting."; exit 1; }

RUN echo "=== Build Kaldi with GPU ==="
RUN git clone --depth 1 https://github.com/kaldi-asr/kaldi.git /opt/kaldi
RUN cd /opt/kaldi/tools
# Install low-level math library (Intel is faster than OpenBLAS)
RUN ./extras/install_mkl.sh
RUN make -j $(nproc)
RUN cd /opt/kaldi/src
# Build the image with CUDA. The arch is specified for a Tesla M60
RUN ./configure --shared --use-cuda --cuda-arch=sm_50
RUN make depend -j $(nproc)
RUN make -j $(nproc)
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

RUN echo "=== Cleaning build reliquates ===" && \
    cd /opt/kaldi && rm -r src && mv src_ src && rm src/*/*.cc && rm src/*/*.o && rm src/*/*.so && \
    cd /opt/intel/mkl/lib && rm -f intel64/*.a intel64_lin/*.a && \
    cd /opt/kaldi/tools && mkdir openfst_ && mv openfst-*/lib openfst-*/include openfst-*/bin openfst_ && rm openfst_/lib/*.so* openfst_/lib/*.la && \
    rm -r openfst-*/* && mv openfst_/* openfst-*/ && rm -r openfst_

RUN echo "=== Install Python dependencies ===" && \
    apt install -y python python-pip && wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && ./llvm.sh 10 && \
    export LLVM_CONFIG=/usr/bin/llvm-config-10 && \
    python3 -m pip install -y --upgrade pip && \
    python3 -m pip install -y numpy websockets librosa webrtcvad scipy sklearn

RUN echo "=== Installing Vosk ==="
COPY vosk-api /opt/vosk-api
RUN cd /opt/vosk-api/python && \
    export KALDI_ROOT=/opt/kaldi && \
    export KALDI_MKL=1 && \
    python3 setup.py install --user --single-version-externally-managed --root=/

RUN echo "=== Installing pyBK ==="
WORKDIR /opt/linstt
COPY pyBK/diarizationFunctions.py pyBK/diarizationFunctions.py
COPY run.py .
COPY tools.py .

EXPOSE 2700

CMD python3 run.py
